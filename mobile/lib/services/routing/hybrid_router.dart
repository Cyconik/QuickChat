import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/local/local_storage_service.dart';
import '../../data/models/message_model.dart';
import '../ble/ble_mesh_service.dart';
import '../mesh/mesh_network_engine.dart';
import '../websocket/websocket_service.dart';

enum TransportRoute {
  bleDirect,
  bleMeshRelay,
  cloudWebSocket,
  storeAndForwardLocal,
}

class HybridRouter {
  static final HybridRouter instance = HybridRouter._internal();
  HybridRouter._internal();

  final BleMeshService _bleService = BleMeshService.instance;
  final MeshNetworkEngine _meshEngine = MeshNetworkEngine.instance;
  final WebSocketService _wsService = WebSocketService.instance;

  final StreamController<MessageEnvelope> _routedMessageStreamController = StreamController.broadcast();
  Stream<MessageEnvelope> get routedMessageStream => _routedMessageStreamController.stream;

  void initialize() {
    // Merge streams from Mesh engine and WebSocket
    _meshEngine.incomingMessageStream.listen((msg) {
      _routedMessageStreamController.add(msg);
    });

    _wsService.incomingMessageStream.listen((msg) async {
      // Deduplicate before processing
      final seen = LocalStorageService.getSeenMessageIds();
      if (!seen.contains(msg.messageId)) {
        await LocalStorageService.markMessageSeen(msg.messageId);
        await LocalStorageService.saveMessage(msg);
        _routedMessageStreamController.add(msg);
      }
    });
  }

  /// Sends a message choosing the optimal route automatically
  Future<TransportRoute> routeMessage(MessageEnvelope envelope) async {
    final destId = envelope.destinationId;
    final isGroup = envelope.destinationType == 'group';

    // 1. Check if recipient is directly in BLE radio range
    final isNearbyPeer = _bleService.discoveredPeers.containsKey(destId);

    if (isNearbyPeer && !isGroup) {
      debugPrint('[HybridRouter] Routing via Direct BLE to $destId');
      await _meshEngine.originateMessage(envelope);
      return TransportRoute.bleDirect;
    }

    // 2. If Internet WebSocket is active, use Cloud Gateway for instant remote delivery
    if (_wsService.isConnected) {
      debugPrint('[HybridRouter] Routing via Cloud WebSocket for destination: $destId');
      final sentWs = _wsService.sendMessage(envelope);
      if (sentWs) {
        envelope.status = MessageDeliveryStatus.sent;
        await LocalStorageService.saveMessage(envelope);
        return TransportRoute.cloudWebSocket;
      }
    }

    // 3. Internet is offline or unreachable: fall back to Multi-hop BLE Mesh
    debugPrint('[HybridRouter] Internet offline. Routing via Multi-hop BLE Mesh Network...');
    final sentMesh = await _meshEngine.originateMessage(envelope);

    if (sentMesh) {
      return TransportRoute.bleMeshRelay;
    } else {
      // 4. Stored locally in Store-and-Forward queue
      await LocalStorageService.addToStoreForwardQueue(envelope);
      return TransportRoute.storeAndForwardLocal;
    }
  }
}
