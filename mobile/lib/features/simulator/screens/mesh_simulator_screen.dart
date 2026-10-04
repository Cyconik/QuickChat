import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/simulator/mesh_simulator_engine.dart';

class MeshSimulatorScreen extends StatefulWidget {
  const MeshSimulatorScreen({super.key});

  @override
  State<MeshSimulatorScreen> createState() => _MeshSimulatorScreenState();
}

class _MeshSimulatorScreenState extends State<MeshSimulatorScreen> {
  final MeshSimulatorEngine _engine = MeshSimulatorEngine.instance;
  final List<SimHopEvent> _eventLogs = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _engine.hopEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _eventLogs.insert(0, event);
          if (_eventLogs.length > 50) _eventLogs.removeLast();
        });
      }
    });
  }

  Future<void> _runScenario1_AToE() async {
    setState(() => _isSending = true);
    await _engine.sendSimulatedMessage(
      fromNodeId: 'A',
      toNodeId: 'E',
      text: 'Hello Node E across 4 hops!',
      initialTtl: 8,
    );
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _runScenario2_DirectChat() async {
    setState(() => _isSending = true);
    await _engine.sendSimulatedMessage(
      fromNodeId: 'A',
      toNodeId: 'B',
      text: 'Direct private message A -> B',
      initialTtl: 8,
    );
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _runScenario3_GroupBroadcast() async {
    setState(() => _isSending = true);
    await _engine.sendSimulatedGroupMessage(
      fromNodeId: 'A',
      text: 'Delhi Community meetup happening now!',
      initialTtl: 8,
    );
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mesh Network Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw, size: 18),
            tooltip: 'Reset Topology',
            onPressed: () {
              _engine.resetTopology();
              setState(() => _eventLogs.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Visual Topology Graph
          _buildTopologyGraph(),

          // Scenario Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.arrowRight, size: 14),
                  label: const Text('Test A → E (4 Hops)'),
                  onPressed: _isSending ? null : _runScenario1_AToE,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.send, size: 14),
                  label: const Text('Test A → B (Direct)'),
                  onPressed: _isSending ? null : _runScenario2_DirectChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.users, size: 14),
                  label: const Text('Test Group Fanout'),
                  onPressed: _isSending ? null : _runScenario3_GroupBroadcast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.surfaceLight, height: 1),

          // Real-time Hop Event Log Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.terminal, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('Live Packet Hop Trace', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('${_eventLogs.length} events', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),

          // Event Logs List
          Expanded(
            child: _eventLogs.isEmpty
                ? const Center(
                    child: Text('Tap a test scenario above to visualize multi-hop routing', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _eventLogs.length,
                    itemBuilder: (context, index) {
                      final event = _eventLogs[index];
                      return _buildEventLogCard(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopologyGraph() {
    final nodes = _engine.nodes.values.toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mesh Nodes (Tap node to toggle Online/Offline)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: nodes.map((node) {
              return _buildNodeWidget(node);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(SimulatedNode node) {
    final isOnline = node.isOnline;

    return InkWell(
      onTap: () {
        setState(() {
          _engine.toggleNodeOnline(node.id);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppColors.surfaceHighlight : AppColors.surfaceLight,
              border: Border.all(
                color: isOnline ? (node.id == 'A' || node.id == 'E' ? AppColors.primary : AppColors.accent) : AppColors.error,
                width: 2,
              ),
              boxShadow: isOnline
                  ? [BoxShadow(color: AppColors.primaryGlow.withOpacity(0.3), blurRadius: 10)]
                  : [],
            ),
            child: Center(
              child: Text(
                node.id,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isOnline ? AppColors.textPrimary : AppColors.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOnline ? 'Online' : 'Broken',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isOnline ? AppColors.accent : AppColors.error,
            ),
          ),
          if (node.storeForwardQueue.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(4)),
              child: Text('${node.storeForwardQueue.length} Q', style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventLogCard(SimHopEvent event) {
    Color statusColor = AppColors.primary;
    IconData icon = LucideIcons.radio;

    if (event.status == 'delivered') {
      statusColor = AppColors.accent;
      icon = LucideIcons.checkCheck;
    } else if (event.status == 'dropped_offline' || event.status == 'dropped_loop') {
      statusColor = AppColors.warning;
      icon = LucideIcons.alertTriangle;
    } else if (event.status == 'stored_flushed') {
      statusColor = AppColors.secondary;
      icon = LucideIcons.uploadCloud;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Text('Hop ${event.hopIndex} • TTL: ${event.remainingTtl}', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('${event.fromNodeId} → ${event.toNodeId}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(height: 2),
                Text(event.info, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
