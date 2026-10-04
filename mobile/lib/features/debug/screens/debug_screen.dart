import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/ble/ble_mesh_service.dart';
import '../../../services/mesh/mesh_network_engine.dart';
import '../../../services/websocket/websocket_service.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Developer Mesh Diagnostics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Radio Subsystems Card
          _buildCard(
            title: 'Radio & Network Subsystems',
            icon: LucideIcons.cpu,
            children: [
              _buildDebugRow('BLE Peripheral Advertiser', BleMeshService.instance.isAdvertising ? 'ACTIVE' : 'IDLE', AppColors.accent),
              _buildDebugRow('BLE Central Scanner', BleMeshService.instance.isScanning ? 'SCANNING' : 'IDLE', AppColors.accent),
              _buildDebugRow('Cloud WebSocket Gateway', WebSocketService.instance.isConnected ? 'CONNECTED' : 'DISCONNECTED', WebSocketService.instance.isConnected ? AppColors.accent : AppColors.warning),
              _buildDebugRow('Mesh Relay Forwarding', MeshNetworkEngine.instance.isRelayEnabled ? 'ENABLED' : 'DISABLED', AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),

          // Routing Engine Statistics Card
          StreamBuilder<MeshStatistics>(
            stream: MeshNetworkEngine.instance.statsStream,
            initialData: MeshNetworkEngine.instance.stats,
            builder: (context, snapshot) {
              final stats = snapshot.data ?? MeshNetworkEngine.instance.stats;
              return _buildCard(
                title: 'Mesh Engine Packet Statistics',
                icon: LucideIcons.barChart2,
                children: [
                  _buildDebugRow('Packets Originated (Sent)', '${stats.packetsSent}', AppColors.primary),
                  _buildDebugRow('Packets Received (Total)', '${stats.packetsReceived}', AppColors.accent),
                  _buildDebugRow('Packets Relayed (Multi-Hop)', '${stats.packetsRelayed}', AppColors.primary),
                  _buildDebugRow('Duplicate Loops Prevented', '${stats.packetsDroppedLoops}', AppColors.secondary),
                  _buildDebugRow('Packets Dropped (TTL Expiry)', '${stats.packetsDroppedTtl}', AppColors.warning),
                  _buildDebugRow('Store-and-Forward Flushed', '${stats.storeForwardFlushed}', AppColors.accent),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Neighbor Table & RSSI
          _buildCard(
            title: 'Discovered BLE Neighbor Table',
            icon: LucideIcons.radio,
            children: [
              if (BleMeshService.instance.discoveredPeers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No external BLE nodes in immediate radio range.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              else
                ...BleMeshService.instance.discoveredPeers.values.map((p) => _buildDebugRow(
                  '@${p.username ?? p.peerId}',
                  '${p.signalStrength} dBm (${p.proximityLabel})',
                  AppColors.primary,
                )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.between,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
