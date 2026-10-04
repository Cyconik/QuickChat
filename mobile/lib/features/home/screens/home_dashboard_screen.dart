import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/local_storage_service.dart';
import '../../../services/ble/ble_mesh_service.dart';
import '../../../services/mesh/mesh_network_engine.dart';
import '../../../services/websocket/websocket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chats/screens/chat_room_screen.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;
  const HomeDashboardScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.accent, blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 8),
            Text(user?.displayName ?? 'QuickChat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Cryptographic Identity Card
            _buildIdentityBanner(user?.username ?? 'anonymous', user?.id ?? 'usr_000000'),
            const SizedBox(height: 20),

            // Live Mesh Network Status Card
            _buildMeshStatusCard(),
            const SizedBox(height: 20),

            // Quick Actions: Direct Message, Groups, Radar
            _buildQuickActionGrid(),
            const SizedBox(height: 24),

            // Section Header: Active Nearby Peers
            Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                const Text('Nearby Mesh Peers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(2), // Navigate to Nearby Radar tab
                  child: const Text('View Radar', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildNearbyPeersList(),
            const SizedBox(height: 24),

            // Recent Communities / Groups
            Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                const Text('Featured Communities', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(3), // Navigate to Groups tab
                  child: const Text('Browse All', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFeaturedGroupsList(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityBanner(String username, String userId) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryGlow,
            child: const Icon(LucideIcons.user, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 4),
                Text('ID: $userId', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'monospace')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.lock, size: 12, color: AppColors.accent),
                SizedBox(width: 4),
                Text('E2E Encrypted', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshStatusCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: BleMeshService.instance.peersStream.map((p) => {'count': p.length}),
      builder: (context, snapshot) {
        final peerCount = snapshot.data?['count'] ?? BleMeshService.instance.discoveredPeers.length;
        final isMeshActive = MeshNetworkEngine.instance.isRelayEnabled;
        final isWsConnected = WebSocketService.instance.isConnected;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isMeshActive ? AppColors.primary.withOpacity(0.3) : AppColors.surfaceLight),
            boxShadow: [
              if (isMeshActive)
                BoxShadow(color: AppColors.primaryGlow.withOpacity(0.1), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.radio, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Nearby Mesh Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMeshActive ? AppColors.accent.withOpacity(0.15) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isMeshActive ? AppColors.accent : AppColors.textMuted),
                    ),
                    child: Text(
                      isMeshActive ? 'MESH ACTIVE' : 'RELAY PAUSED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isMeshActive ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusMiniStat(
                      icon: LucideIcons.users,
                      label: 'Nearby Peers',
                      value: '$peerCount nodes',
                      color: AppColors.primary,
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.surfaceLight),
                  Expanded(
                    child: _buildStatusMiniStat(
                      icon: LucideIcons.bluetooth,
                      label: 'Bluetooth',
                      value: BleMeshService.instance.isBluetoothAvailable ? 'READY' : 'OFF',
                      color: AppColors.accent,
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.surfaceLight),
                  Expanded(
                    child: _buildStatusMiniStat(
                      icon: LucideIcons.cloud,
                      label: 'Internet',
                      value: isWsConnected ? 'ONLINE' : 'MESH-ONLY',
                      color: isWsConnected ? AppColors.accent : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildQuickActionGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.messageSquare,
            label: 'New Chat',
            color: AppColors.primary,
            onTap: () => widget.onNavigateTab?.call(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.radar,
            label: 'Scan Radar',
            color: AppColors.accent,
            onTap: () => widget.onNavigateTab?.call(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.users,
            label: 'Groups',
            color: AppColors.secondary,
            onTap: () => widget.onNavigateTab?.call(3),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyPeersList() {
    final samplePeers = [
      {'name': 'Rahul Sharma', 'handle': 'rahul_dev', 'rssi': '-62 dBm', 'status': 'Approx. nearby (< 10m)'},
      {'name': 'Priya Patel', 'handle': 'priya', 'rssi': '-74 dBm', 'status': 'Mesh relay (< 25m)'},
      {'name': 'Nikhil V.', 'handle': 'nikhil_v', 'rssi': '-81 dBm', 'status': 'Multi-hop relay'},
    ];

    return Column(
      children: samplePeers.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('@${p['handle']} • ${p['status']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        targetId: 'usr_${p['handle']}',
                        targetName: p['name']!,
                        targetHandle: p['handle']!,
                        isGroup: false,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: const Text('Message'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeaturedGroupsList() {
    final groups = [
      {'name': 'Delhi Tech Community', 'desc': 'Decentralized peer-to-peer discussions.', 'members': 142},
      {'name': 'Mesh Network Builders', 'desc': 'Ad-hoc BLE forwarding protocol experiments.', 'members': 88},
    ];

    return Column(
      children: groups.map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.hash, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(g['desc'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${g['members']} members • Multi-hop Mesh sync', style: const TextStyle(color: AppColors.accent, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.arrowRight, size: 18, color: AppColors.textSecondary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        targetId: 'group_${(g['name'] as String).toLowerCase().replaceAll(' ', '_')}',
                        targetName: g['name'] as String,
                        targetHandle: 'group',
                        isGroup: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
