import 'dart:async';
import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/security/crypto_engine.dart';
import '../../data/models/message_model.dart';
import '../../data/models/peer_model.dart';

class SimulatedNode {
  final String id; // e.g. 'Node A', 'Node B', etc.
  final String name;
  final String userId; // e.g. 'usr_node_A'
  final String publicKey;
  final String privateKey;
  bool isOnline;
  bool isRelayEnabled;
  final Set<String> seenMessageIds = {};
  final List<MessageEnvelope> messageInbox = [];
  final List<MessageEnvelope> storeForwardQueue = [];

  SimulatedNode({
    required this.id,
    required this.name,
    required this.userId,
    required this.publicKey,
    required this.privateKey,
    this.isOnline = true,
    this.isRelayEnabled = true,
  });
}

class SimHopEvent {
  final String fromNodeId;
  final String toNodeId;
  final String messageId;
  final int hopIndex;
  final int remainingTtl;
  final String status; // 'relaying' | 'delivered' | 'dropped_loop' | 'dropped_offline' | 'stored'
  final int timestamp;
  final String info;

  SimHopEvent({
    required this.fromNodeId,
    required this.toNodeId,
    required this.messageId,
    required this.hopIndex,
    required this.remainingTtl,
    required this.status,
    required this.timestamp,
    required this.info,
  });
}

class MeshSimulatorEngine {
  static final MeshSimulatorEngine instance = MeshSimulatorEngine._internal();
  MeshSimulatorEngine._internal() {
    _initDefaultTopology();
  }

  final Map<String, SimulatedNode> _nodes = {};
  // Adjacency graph: nodeId -> Set<neighborNodeId>
  final Map<String, Set<String>> _topology = {};

  final StreamController<SimHopEvent> _hopEventStreamController = StreamController.broadcast();
  final StreamController<List<SimulatedNode>> _nodesStreamController = StreamController.broadcast();

  Stream<SimHopEvent> get hopEventStream => _hopEventStreamController.stream;
  Stream<List<SimulatedNode>> get nodesStream => _nodesStreamController.stream;

  Map<String, SimulatedNode> get nodes => Map.unmodifiable(_nodes);
  Map<String, Set<String>> get topology => Map.unmodifiable(_topology);

  void _initDefaultTopology() {
    final nodeDefs = [
      {'id': 'A', 'name': 'Node A (Sender)', 'user': 'usr_A'},
      {'id': 'B', 'name': 'Node B (Relay 1)', 'user': 'usr_B'},
      {'id': 'C', 'name': 'Node C (Relay 2)', 'user': 'usr_C'},
      {'id': 'D', 'name': 'Node D (Relay 3)', 'user': 'usr_D'},
      {'id': 'E', 'name': 'Node E (Destination)', 'user': 'usr_E'},
    ];

    for (final def in nodeDefs) {
      final kp = CryptoEngine.generateIdentityKeyPair();
      final node = SimulatedNode(
        id: def['id']!,
        name: def['name']!,
        userId: def['user']!,
        publicKey: kp.publicKey,
        privateKey: kp.privateKey,
        isOnline: true,
        isRelayEnabled: true,
      );
      _nodes[node.id] = node;
      _topology[node.id] = {};
    }

    // Default Linear Multi-Hop Mesh: A <-> B <-> C <-> D <-> E
    connectNodes('A', 'B');
    connectNodes('B', 'C');
    connectNodes('C', 'D');
    connectNodes('D', 'E');
  }

  void connectNodes(String id1, String id2) {
    if (_topology.containsKey(id1) && _topology.containsKey(id2)) {
      _topology[id1]!.add(id2);
      _topology[id2]!.add(id1);
      _emitNodes();
    }
  }

  void disconnectNodes(String id1, String id2) {
    if (_topology.containsKey(id1) && _topology.containsKey(id2)) {
      _topology[id1]!.remove(id2);
      _topology[id2]!.remove(id1);
      _emitNodes();
    }
  }

  void toggleNodeOnline(String nodeId) {
    final node = _nodes[nodeId];
    if (node != null) {
      node.isOnline = !node.isOnline;
      _emitNodes();

      if (node.isOnline) {
        // Node reconnected! Flush any store-and-forward messages buffered on adjacent nodes
        _flushStoreForwardForNode(nodeId);
      }
    }
  }

  void toggleNodeRelay(String nodeId) {
    final node = _nodes[nodeId];
    if (node != null) {
      node.isRelayEnabled = !node.isRelayEnabled;
      _emitNodes();
    }
  }

  /// Initiates a multi-hop mesh simulation packet from a source node
  Future<void> sendSimulatedMessage({
    required String fromNodeId,
    required String toNodeId,
    required String text,
    int initialTtl = 8,
  }) async {
    final sender = _nodes[fromNodeId];
    final recipient = _nodes[toNodeId];
    if (sender == null || recipient == null) return;

    final messageId = 'sim_msg_${DateTime.now().millisecondsSinceEpoch}';
    final envelope = MessageEnvelope(
      messageId: messageId,
      senderId: sender.userId,
      senderUsername: sender.name,
      conversationId: 'sim_conv',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      ttl: initialTtl,
      hopCount: 0,
      destinationType: 'user',
      destinationId: recipient.userId,
      encryptedPayload: CryptoEngine.encryptPayload(
        plaintext: text,
        sharedSecretBase64: '${sender.privateKey}:${recipient.publicKey}',
      ),
      signature: 'sim_sig_$messageId',
      decryptedContent: text,
    );

    // Sender marks seen
    sender.seenMessageIds.add(messageId);

    _hopEventStreamController.add(SimHopEvent(
      fromNodeId: fromNodeId,
      toNodeId: fromNodeId,
      messageId: messageId,
      hopIndex: 0,
      remainingTtl: initialTtl,
      status: 'originated',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      info: 'Node $fromNodeId originated message: "$text"',
    ));

    // Propagate into adjacent neighbors
    await _propagatePacket(fromNodeId, envelope, 0);
  }

  /// Sends a simulated group broadcast to all 5 nodes
  Future<void> sendSimulatedGroupMessage({
    required String fromNodeId,
    required String text,
    int initialTtl = 8,
  }) async {
    final sender = _nodes[fromNodeId];
    if (sender == null) return;

    final messageId = 'sim_grp_${DateTime.now().millisecondsSinceEpoch}';
    final envelope = MessageEnvelope(
      messageId: messageId,
      senderId: sender.userId,
      senderUsername: sender.name,
      conversationId: 'group_delhi_tech',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      ttl: initialTtl,
      hopCount: 0,
      destinationType: 'group',
      destinationId: 'group_delhi_tech',
      encryptedPayload: CryptoEngine.encryptPayload(
        plaintext: text,
        sharedSecretBase64: 'simulated_delhi_group_key',
      ),
      signature: 'sim_sig_grp_$messageId',
      decryptedContent: text,
    );

    sender.seenMessageIds.add(messageId);

    _hopEventStreamController.add(SimHopEvent(
      fromNodeId: fromNodeId,
      toNodeId: 'GROUP',
      messageId: messageId,
      hopIndex: 0,
      remainingTtl: initialTtl,
      status: 'group_broadcast',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      info: 'Node $fromNodeId broadcasted to "Delhi Community": "$text"',
    ));

    await _propagatePacket(fromNodeId, envelope, 0);
  }

  Future<void> _propagatePacket(String currentNodeId, MessageEnvelope envelope, int currentHop) async {
    final neighbors = _topology[currentNodeId] ?? {};

    for (final neighborId in neighbors) {
      // Simulate realistic over-the-air radio delay (350ms per hop)
      await Future.delayed(const Duration(milliseconds: 350));

      final targetNode = _nodes[neighborId];
      if (targetNode == null) continue;

      // 1. Check if neighbor is offline
      if (!targetNode.isOnline) {
        _hopEventStreamController.add(SimHopEvent(
          fromNodeId: currentNodeId,
          toNodeId: neighborId,
          messageId: envelope.messageId,
          hopIndex: currentHop + 1,
          remainingTtl: envelope.ttl,
          status: 'dropped_offline',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          info: 'Node $neighborId is OFFLINE. Buffered at Node $currentNodeId for Store-and-Forward.',
        ));

        // Buffer on current node
        _nodes[currentNodeId]?.storeForwardQueue.add(envelope);
        continue;
      }

      // 2. Loop Prevention / Deduplication check
      if (targetNode.seenMessageIds.contains(envelope.messageId)) {
        _hopEventStreamController.add(SimHopEvent(
          fromNodeId: currentNodeId,
          toNodeId: neighborId,
          messageId: envelope.messageId,
          hopIndex: currentHop + 1,
          remainingTtl: envelope.ttl,
          status: 'dropped_loop',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          info: 'Loop prevented! Node $neighborId already processed msg ${envelope.messageId}. Dropped.',
        ));
        continue;
      }

      // Mark seen
      targetNode.seenMessageIds.add(envelope.messageId);

      // 3. Check if target is destination or group member
      final isDest = (envelope.destinationType == 'user' && envelope.destinationId == targetNode.userId);
      final isGroup = (envelope.destinationType == 'group');

      if (isDest || isGroup) {
        targetNode.messageInbox.add(envelope);
        _hopEventStreamController.add(SimHopEvent(
          fromNodeId: currentNodeId,
          toNodeId: neighborId,
          messageId: envelope.messageId,
          hopIndex: currentHop + 1,
          remainingTtl: envelope.ttl,
          status: 'delivered',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          info: 'SUCCESS: Node $neighborId received and decrypted payload (Hops: ${currentHop + 1})',
        ));
      }

      // 4. Relay Forwarding (if TTL > 1 and relay enabled)
      if (targetNode.isRelayEnabled && envelope.ttl > 1 && !isDest) {
        final forwardEnvelope = envelope.copyWith(
          ttl: envelope.ttl - 1,
          hopCount: envelope.hopCount + 1,
        );

        _hopEventStreamController.add(SimHopEvent(
          fromNodeId: currentNodeId,
          toNodeId: neighborId,
          messageId: envelope.messageId,
          hopIndex: currentHop + 1,
          remainingTtl: forwardEnvelope.ttl,
          status: 'relaying',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          info: 'Node $neighborId relaying forward... (Next TTL: ${forwardEnvelope.ttl})',
        ));

        // Asynchronously forward to next hops
        _propagatePacket(neighborId, forwardEnvelope, currentHop + 1);
      }
    }
  }

  void _flushStoreForwardForNode(String reconnectedNodeId) {
    for (final node in _nodes.values) {
      if (node.id != reconnectedNodeId && node.storeForwardQueue.isNotEmpty) {
        final list = List<MessageEnvelope>.from(node.storeForwardQueue);
        node.storeForwardQueue.clear();
        for (final msg in list) {
          _hopEventStreamController.add(SimHopEvent(
            fromNodeId: node.id,
            toNodeId: reconnectedNodeId,
            messageId: msg.messageId,
            hopIndex: msg.hopCount + 1,
            remainingTtl: msg.ttl,
            status: 'stored_flushed',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            info: 'Flushing Store-and-Forward queue from Node ${node.id} to reconnected Node $reconnectedNodeId',
          ));
          _propagatePacket(node.id, msg, msg.hopCount);
        }
      }
    }
  }

  void _emitNodes() {
    _nodesStreamController.add(_nodes.values.toList());
  }

  void resetTopology() {
    _nodes.clear();
    _topology.clear();
    _initDefaultTopology();
    _emitNodes();
  }
}
