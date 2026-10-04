import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/local_storage_service.dart';
import '../../../services/mesh/mesh_network_engine.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _participateInMesh = true;
  double _maxTtl = 8;
  String _discoverableBy = 'everyone';
  String _messageableBy = 'everyone';
  bool _showOnline = true;

  @override
  void initState() {
    super.initState();
    _participateInMesh = LocalStorageService.isMeshRelayEnabled();
    _maxTtl = LocalStorageService.getMaxRelayTtl().toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Mesh Relay Settings
          _buildSectionHeader('Mesh Networking & Relay Engine'),
          _buildMeshSettingsCard(),
          const SizedBox(height: 24),

          // Section: Privacy Controls
          _buildSectionHeader('Privacy & Discovery'),
          _buildPrivacySettingsCard(),
          const SizedBox(height: 24),

          // Section: Battery & Platform Guidance
          _buildSectionHeader('Battery & Background Execution'),
          _buildBatteryGuidanceCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildMeshSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Participate in Mesh Relay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text(
              'Allow your device to securely help deliver encrypted messages between nearby users.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            value: _participateInMesh,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _participateInMesh = val);
              MeshNetworkEngine.instance.setRelayParticipation(val);
            },
          ),
          const Divider(color: AppColors.surfaceLight, height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  const Text('Maximum Relay TTL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${_maxTtl.toInt()} hops', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Controls maximum network hop horizon to prevent excessive flooding.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              Slider(
                value: _maxTtl,
                min: 2,
                max: 12,
                divisions: 10,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _maxTtl = v);
                  LocalStorageService.setMaxRelayTtl(v.toInt());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          _buildDropdownTile(
            title: 'Who can discover me nearby?',
            value: _discoverableBy,
            options: {'everyone': 'Everyone', 'connections_only': 'Connections Only', 'nobody': 'Nobody (Stealth)'},
            onChanged: (v) => setState(() => _discoverableBy = v!),
          ),
          const Divider(color: AppColors.surfaceLight, height: 20),
          _buildDropdownTile(
            title: 'Who can send me messages?',
            value: _messageableBy,
            options: {'everyone': 'Everyone', 'connections_only': 'Connections Only'},
            onChanged: (v) => setState(() => _messageableBy = v!),
          ),
          const Divider(color: AppColors.surfaceLight, height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Presence Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            value: _showOnline,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _showOnline = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.between,
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surfaceHighlight,
          underline: const SizedBox(),
          style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
          items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildBatteryGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.batteryCharging, size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text('Battery Optimization Guidance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'QuickChat BLE duty-cycling scans and advertises with adaptive low-power interval scheduling (< 2% battery drain per day on modern Bluetooth 5.0+ chipsets).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
