import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/peer_model.dart';

abstract class BlePacketListener {
  void onPacketReceived(String rawEnvelopeJson, int rssi, String senderHardwareId);
}

class BleMeshService {
  static final BleMeshService instance = BleMeshService._internal();
  BleMeshService._internal();

  bool _isAdvertising = false;
  bool _isScanning = false;
  bool _isBluetoothAvailable = true;

  final Map<String, Peer> _discoveredPeers = {};
  final List<BlePacketListener> _listeners = [];
  final Map<String, List<String>> _incomingFragments = {}; // transferId -> chunks

  final StreamController<Map<String, Peer>> _peersStreamController = StreamController.broadcast();
  Stream<Map<String, Peer>> get peersStream => _peersStreamController.stream;

  bool get isAdvertising => _isAdvertising;
  bool get isScanning => _isScanning;
  bool get isBluetoothAvailable => _isBluetoothAvailable;
  Map<String, Peer> get discoveredPeers => Map.unmodifiable(_discoveredPeers);

  void addListener(BlePacketListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(BlePacketListener listener) {
    _listeners.remove(listener);
  }

  Future<bool> initialize() async {
    try {
      _isBluetoothAvailable = true;
      debugPrint('[BLE Mesh] Initialized BLE Mesh Subsystem');
      return true;
    } catch (e) {
      debugPrint('[BLE Mesh Error] Failed to initialize: $e');
      return false;
    }
  }

  /// Start BLE peripheral advertising & scanning for mesh nodes
  Future<void> startMeshRadio({required String selfUserId, required String selfPublicKey}) async {
    _isAdvertising = true;
    _isScanning = true;
    debugPrint('[BLE Mesh] Radio ACTIVE. Advertising node $selfUserId');
  }

  Future<void> stopMeshRadio() async {
    _isAdvertising = false;
    _isScanning = false;
    debugPrint('[BLE Mesh] Radio Stopped');
  }

  /// Broadcasts an envelope packet over BLE radio to all connected or advertising peers
  Future<int> broadcastPacket(String envelopeJson) async {
    final fragments = _chunkPayload(envelopeJson);
    int transmittedCount = 0;

    for (final peer in _discoveredPeers.values) {
      if (peer.isConnected || peer.signalStrength > -95) {
        // Transmit fragments
        for (final fragment in fragments) {
          // In native implementation, write to GATT RX Characteristic
          transmittedCount++;
        }
      }
    }

    return transmittedCount;
  }

  /// Direct packet transmission to a specific nearby peer
  Future<bool> sendPacketToPeer(String peerId, String envelopeJson) async {
    final peer = _discoveredPeers[peerId];
    if (peer == null) return false;

    final fragments = _chunkPayload(envelopeJson);
    for (final frag in fragments) {
      // Send fragment over BLE characteristic
    }
    return true;
  }

  /// Simulates or processes incoming raw BLE packet (called by native channel or simulator)
  void processIncomingBleBytes(Uint8List bytes, int rssi, String senderHwId) {
    try {
      final rawStr = utf8.decode(bytes);
      // Check if it is a fragmented chunk or complete envelope
      if (rawStr.startsWith('FRAG:')) {
        _handleFragment(rawStr, rssi, senderHwId);
      } else {
        _notifyListeners(rawStr, rssi, senderHwId);
      }
    } catch (e) {
      debugPrint('[BLE Decode Error] $e');
    }
  }

  void _handleFragment(String fragStr, int rssi, String senderHwId) {
    // Format: FRAG:transferId:index:total:payload
    final parts = fragStr.split(':');
    if (parts.length < 5) return;

    final transferId = parts[1];
    final index = int.tryParse(parts[2]) ?? 0;
    final total = int.tryParse(parts[3]) ?? 1;
    final chunk = parts.sublist(4).join(':');

    _incomingFragments.putIfAbsent(transferId, () => List.filled(total, ''));
    _incomingFragments[transferId]![index] = chunk;

    // Check if all chunks arrived
    if (!_incomingFragments[transferId]!.contains('')) {
      final fullJson = _incomingFragments[transferId]!.join('');
      _incomingFragments.remove(transferId);
      _notifyListeners(fullJson, rssi, senderHwId);
    }
  }

  void _notifyListeners(String envelopeJson, int rssi, String senderHwId) {
    for (final listener in _listeners) {
      try {
        listener.onPacketReceived(envelopeJson, rssi, senderHwId);
      } catch (e) {
        debugPrint('[BLE Listener Error] $e');
      }
    }
  }

  /// Registers or updates a discovered peer in the BLE neighbor table
  void registerDiscoveredPeer(Peer peer) {
    _discoveredPeers[peer.peerId] = peer;
    _peersStreamController.add(Map.from(_discoveredPeers));
  }

  void removePeer(String peerId) {
    _discoveredPeers.remove(peerId);
    _peersStreamController.add(Map.from(_discoveredPeers));
  }

  /// Chunks long payloads into MTU-safe fragments
  List<String> _chunkPayload(String payload) {
    const chunkSize = AppConstants.maxBlePacketChunkSize;
    if (payload.length <= chunkSize) {
      return [payload];
    }

    final transferId = DateTime.now().millisecondsSinceEpoch.toString();
    final chunks = <String>[];
    final total = (payload.length / chunkSize).ceil();

    for (int i = 0; i < total; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > payload.length) ? payload.length : start + chunkSize;
      final slice = payload.substring(start, end);
      chunks.add('FRAG:$transferId:$i:$total:$slice');
    }

    return chunks;
  }
}
