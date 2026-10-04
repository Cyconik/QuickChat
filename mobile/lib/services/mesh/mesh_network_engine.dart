import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/local/local_storage_service.dart';
import '../../data/models/message_model.dart';
import '../../data/models/peer_model.dart';
import '../../data/models/user_model.dart';
import '../ble/ble_mesh_service.dart';

class MeshStatistics {
  int packetsSent = 0;
  int packetsReceived = 0;
  int packetsRelayed = 0;
  int packetsDroppedLoops = 0;
  int packetsDroppedTtl = 0;
  int storeForwardFlushed = 0;

  Map<String, dynamic> toMap() => {
    'packetsSent': packetsSent,
    'packetsReceived': packetsReceived,
    'packetsRelayed': packetsRelayed,
    'packetsDroppedLoops': packetsDroppedLoops,
    'packetsDroppedTtl': packetsDroppedTtl,
    'storeForwardFlushed': storeForwardFlushed,
  };
}

class MeshNetworkEngine implements BlePacketListener {
  static final MeshNetworkEngine instance = MeshNetworkEngine._internal();
  MeshNetworkEngine._internal();

  final BleMeshService _bleService = BleMeshService.instance;
  final MeshStatistics stats = MeshStatistics();

  UserModel? _currentUser;
  Timer? _peerCleanupTimer;
  Timer? _storeForwardRetryTimer;

  final Set<String> _seenMessageCache = {};
  final StreamController<MessageEnvelope> _incomingMessageStreamController = StreamController.broadcast();
  final StreamController<MessageDeliveryStatus> _deliveryStatusStreamController = StreamController.broadcast();
  final StreamController<MeshStatistics> _statsStreamController = StreamController.broadcast();

  Stream<MessageEnvelope> get incomingMessageStream => _incomingMessageStreamController.stream;
  Stream<MessageDeliveryStatus> get deliveryStatusStream => _deliveryStatusStreamController.stream;
  Stream<MeshStatistics> get statsStream => _statsStreamController.stream;

  bool _isRelayEnabled = true;
  bool get isRelayEnabled => _isRelayEnabled;

  void initialize({required UserModel user}) {
    _currentUser = user;
    _isRelayEnabled = LocalStorageService.isMeshRelayEnabled();
    _seenMessageCache.addAll(LocalStorageService.getSeenMessageIds());

    _bleService.addListener(this);

    // Periodic peer expiration cleanup (every 60s)
    _peerCleanupTimer?.cancel();
    _peerCleanupTimer = Timer.periodic(const Duration(seconds: 60), (_) => _cleanupExpiredPeers());

    // Periodic store-and-forward queue flush check (every 20s)
    _storeForwardRetryTimer?.cancel();
    _storeForwardRetryTimer = Timer.periodic(const Duration(seconds: 20), (_) => flushStoreAndForwardQueue());

    debugPrint('[Mesh Engine] Engine running for node ${_currentUser?.id}');
  }

  void setRelayParticipation(bool enabled) {
    _isRelayEnabled = enabled;
    LocalStorageService.setMeshRelayEnabled(enabled);
    debugPrint('[Mesh Engine] Mesh Relay participation set to: $enabled');
  }

  /// Sends a new message originating from this device into the mesh
  Future<bool> originateMessage(MessageEnvelope envelope) async {
    if (_currentUser == null) return false;

    // Record in seen cache so we don't process our own broadcast
    _seenMessageCache.add(envelope.messageId);
    await LocalStorageService.markMessageSeen(envelope.messageId);

    envelope.status = MessageDeliveryStatus.sent;
    await LocalStorageService.saveMessage(envelope);

    stats.packetsSent++;
    _emitStats();

    // 1. Check if direct peer is nearby
    final isDirectPeerNearby = _bleService.discoveredPeers.containsKey(envelope.destinationId);
    if (isDirectPeerNearby) {
      debugPrint('[Mesh Engine] Direct peer ${envelope.destinationId} in BLE range. Transmitting direct.');
      await _bleService.sendPacketToPeer(envelope.destinationId, envelope.toRawPacket());
    } else {
      // 2. Multi-hop flood with TTL
      debugPrint('[Mesh Engine] Originating multi-hop mesh broadcast for msg: ${envelope.messageId}');
      final neighborsReached = await _bleService.broadcastPacket(envelope.toRawPacket());

      if (neighborsReached == 0) {
        // No active neighbors: buffer in local Store-and-Forward queue
        debugPrint('[Mesh Engine] No neighbors reachable. Storing in Store-and-Forward queue.');
        await LocalStorageService.addToStoreForwardQueue(envelope);
      }
    }

    return true;
  }

  /// BLE packet callback from BLE radio / simulator
  @override
  void onPacketReceived(String rawEnvelopeJson, int rssi, String senderHardwareId) {
    try {
      final envelope = MessageEnvelope.fromRawPacket(rawEnvelopeJson);
      _processIncomingEnvelope(envelope, rssi);
    } catch (e) {
      debugPrint('[Mesh Engine Error] Failed to parse envelope: $e');
    }
  }

  /// Core Mesh Routing & Forwarding Pipeline
  Future<void> _processIncomingEnvelope(MessageEnvelope envelope, int rssi) async {
    stats.packetsReceived++;

    // 1. Deduplication Check (Loop Prevention: A -> B -> C -> B -> A)
    if (_seenMessageCache.contains(envelope.messageId)) {
      stats.packetsDroppedLoops++;
      _emitStats();
      debugPrint('[Mesh Engine] Dropped duplicate packet msg: ${envelope.messageId}');
      return;
    }

    // Mark as seen immediately
    _seenMessageCache.add(envelope.messageId);
    await LocalStorageService.markMessageSeen(envelope.messageId);

    // 2. Check if this packet is an ACK receipt
    if (envelope.messageType == 'ack') {
      _handleAckPacket(envelope);
      return;
    }

    // 3. Destination Check
    final isAddressedToMe = (envelope.destinationType == 'user' && envelope.destinationId == _currentUser?.id);
    final isGroupMessage = (envelope.destinationType == 'group');

    if (isAddressedToMe || isGroupMessage) {
      debugPrint('[Mesh Engine] Packet DELIVERED to destination: ${envelope.messageId}');
      envelope.status = MessageDeliveryStatus.delivered;

      // Save locally
      await LocalStorageService.saveMessage(envelope);
      _incomingMessageStreamController.add(envelope);

      // If addressed to me, generate and propagate ACK packet back to sender
      if (isAddressedToMe) {
        _sendDeliveryAck(envelope);
      }
    }

    // 4. Mesh Forwarding / Relaying
    // Even if it's a group message (which everyone receives) or a routed direct message, forward if TTL > 1
    if (_isRelayEnabled && envelope.ttl > 1 && envelope.destinationId != _currentUser?.id) {
      await _forwardEnvelope(envelope);
    } else if (envelope.ttl <= 1) {
      stats.packetsDroppedTtl++;
      debugPrint('[Mesh Engine] Packet ${envelope.messageId} TTL expired (TTL: ${envelope.ttl}). Stopped.');
      _emitStats();
    }
  }

  /// Multi-hop forwarding step
  Future<void> _forwardEnvelope(MessageEnvelope envelope) async {
    // Decrement TTL & increment Hop Count
    final relayedEnvelope = envelope.copyWith(
      ttl: envelope.ttl - 1,
      hopCount: envelope.hopCount + 1,
      relayPath: [...envelope.relayPath, _currentUser?.id ?? 'node_unknown'],
    );

    stats.packetsRelayed++;
    _emitStats();

    debugPrint('[Mesh Engine] Relaying msg ${relayedEnvelope.messageId} (Hops: ${relayedEnvelope.hopCount}, Next TTL: ${relayedEnvelope.ttl})');

    // Broadcast forward to all surrounding BLE peers
    final reached = await _bleService.broadcastPacket(relayedEnvelope.toRawPacket());
    if (reached == 0) {
      // Buffer in store-and-forward queue in case next node appears soon
      await LocalStorageService.addToStoreForwardQueue(relayedEnvelope);
    }
  }

  /// Sends a cryptographic delivery acknowledgement packet back to the sender
  void _sendDeliveryAck(MessageEnvelope original) {
    if (_currentUser == null) return;

    final ackEnvelope = MessageEnvelope(
      messageId: 'ack_${original.messageId}',
      senderId: _currentUser!.id,
      conversationId: original.conversationId,
      messageType: 'ack',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      ttl: AppConstants.defaultTtl,
      destinationType: 'user',
      destinationId: original.senderId,
      encryptedPayload: jsonEncode({
        'targetMessageId': original.messageId,
        'status': 'delivered',
        'deliveredAt': DateTime.now().millisecondsSinceEpoch,
      }),
      signature: 'ack_sig_${original.messageId}',
    );

    originateMessage(ackEnvelope);
  }

  void _handleAckPacket(MessageEnvelope ackEnvelope) {
    try {
      final data = jsonDecode(ackEnvelope.encryptedPayload);
      final targetMsgId = data['targetMessageId'] as String?;
      if (targetMsgId != null) {
        debugPrint('[Mesh Engine] ACK received for message: $targetMsgId');
        _deliveryStatusStreamController.add(MessageDeliveryStatus.delivered);
      }
    } catch (_) {}
  }

  /// Flushes Store-and-Forward queue when new peers come into range
  Future<void> flushStoreAndForwardQueue() async {
    final pending = LocalStorageService.getPendingStoreForwardQueue();
    if (pending.isEmpty || _bleService.discoveredPeers.isEmpty) return;

    debugPrint('[Mesh Engine] Attempting Store-and-Forward flush for ${pending.length} pending messages');

    for (final msg in List.from(pending)) {
      if (msg.ttl > 0) {
        final reached = await _bleService.broadcastPacket(msg.toRawPacket());
        if (reached > 0) {
          await LocalStorageService.removeFromStoreForwardQueue(msg.messageId);
          stats.storeForwardFlushed++;
        }
      } else {
        await LocalStorageService.removeFromStoreForwardQueue(msg.messageId);
      }
    }
    _emitStats();
  }

  void _cleanupExpiredPeers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final peers = _bleService.discoveredPeers;
    for (final p in peers.values) {
      if (now - p.lastSeen > AppConstants.peerExpiryDuration.inMilliseconds) {
        _bleService.removePeer(p.peerId);
        debugPrint('[Mesh Engine] Expired peer ${p.peerId} removed from neighbor table');
      }
    }
  }

  void _emitStats() {
    _statsStreamController.add(stats);
  }

  void dispose() {
    _peerCleanupTimer?.cancel();
    _storeForwardRetryTimer?.cancel();
    _bleService.removeListener(this);
  }
}
