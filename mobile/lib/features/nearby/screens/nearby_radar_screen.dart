import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/peer_model.dart';
import '../../../services/ble/ble_mesh_service.dart';
import '../../chats/screens/chat_room_screen.dart';

class NearbyRadarScreen extends ConsumerStatefulWidget {
  const NearbyRadarScreen({super.key});

  @override
  ConsumerState<NearbyRadarScreen> createState() => _NearbyRadarScreenState();
}

class _NearbyRadarScreenState extends ConsumerState<NearbyRadarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarAnimController;

  final List<Peer> _samplePeers = [
    const Peer(
      peerId: 'usr_rahul',
      username: 'rahul_dev',
      displayName: 'Rahul Sharma',
      publicKey: 'pub_rahul_key',
      lastSeen: 1712200000000,
      signalStrength: -62,
      isConnected: true,
    ),
    const Peer(
      peerId: 'usr_priya',
      username: 'priya',
      displayName: 'Priya Patel',
      publicKey: 'pub_priya_key',
      lastSeen: 1712200000000,
      signalStrength: -74,
      isConnected: true,
    ),
    const Peer(
      peerId: 'usr_nikhil',
      username: 'nikhil_v',
      displayName: 'Nikhil Verma',
      publicKey: 'pub_nikhil_key',
      lastSeen: 1712200000000,
      signalStrength: -85,
      isConnected: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nearby Radar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () {
              // Trigger fresh scan
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Radar Animation Canvas
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _radarAnimController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RadarPainter(progress: _radarAnimController.value),
                      size: const Size(220, 220),
                    );
                  },
                ),
                // Center node (You)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: AppColors.primaryGlow, blurRadius: 16, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(LucideIcons.radio, size: 16, color: AppColors.textOnPrimary),
                ),
              ],
            ),
          ),

          // Nearby Peers Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                const Text('Discovered Mesh Peers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '${_samplePeers.length} Active Nodes',
                  style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Peers List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _samplePeers.length,
              itemBuilder: (context, index) {
                final peer = _samplePeers[index];
                return _buildPeerTile(peer);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerTile(Peer peer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.accent, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(peer.displayName ?? peer.peerId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '@${peer.username ?? peer.peerId} • ${peer.proximityLabel}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.signal, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('${peer.signalStrength} dBm', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatRoomScreen(
                    targetId: peer.peerId,
                    targetName: peer.displayName ?? peer.peerId,
                    targetHandle: peer.username ?? peer.peerId,
                    isGroup: false,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            child: const Text('Message'),
          ),
        ],
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;

  RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Background concentric rings
    final ringPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), ringPaint);
    }

    // Expanding sweep wave
    final wavePaint = Paint()
      ..color = AppColors.primary.withOpacity((1 - progress) * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, maxRadius * progress, wavePaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = AppColors.surfaceLight.withOpacity(0.5)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) => oldDelegate.progress != progress;
}
