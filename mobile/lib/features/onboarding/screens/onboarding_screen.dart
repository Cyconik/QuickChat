import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _usernameController = TextEditingController(text: 'anonymous_fox');
  final TextEditingController _displayNameController = TextEditingController(text: 'Anonymous Fox');
  final TextEditingController _bioController = TextEditingController(text: 'Ready for peer-to-peer mesh messaging.');
  bool _meshRelayConsent = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeRegistration();
    }
  }

  Future<void> _completeRegistration() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).registerAnonymous(
        username: _usernameController.text,
        displayName: _displayNameController.text,
        bio: _bioController.text,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(4, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isActive
                            ? [const BoxShadow(color: AppColors.primaryGlow, blurRadius: 8)]
                            : [],
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildWelcomeStep(),
                  _buildProfileStep(),
                  _buildMeshExplanationStep(),
                  _buildPermissionsStep(),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Back', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                          )
                        : Text(_currentStep == 3 ? 'Generate Cryptographic ID' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.primaryGlow, blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: const Icon(LucideIcons.radio, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          const Text(
            'QuickChat Mesh',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chat nearby. Connect privately. Stay connected even when the internet doesn\'t.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.accent),
                SizedBox(width: 10),
                Text('Anonymous-first • End-to-End Encrypted', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Your Identity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'No phone number or email required. A cryptographic keypair will secure your messages.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          const Text('Username (@handle)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              prefixText: '@ ',
              prefixStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              hintText: 'e.g. rahul_dev',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Display Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Rahul Sharma',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Bio / Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Participating in QuickChat mesh.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshExplanationStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.share2, size: 48, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text('Multi-Hop Mesh Networking', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Your phone can help deliver encrypted messages between nearby users without revealing message contents.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              children: [
                _buildMeshDiagramRow('Phone A', 'Sender (No Internet)'),
                const Icon(LucideIcons.arrowDown, size: 18, color: AppColors.primary),
                _buildMeshDiagramRow('Phone B (Your Phone)', 'Encrypted Relay (Zero-Knowledge)'),
                const Icon(LucideIcons.arrowDown, size: 18, color: AppColors.primary),
                _buildMeshDiagramRow('Phone C', 'Destination (Message Delivered)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshDiagramRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Permissions & Relay Consent', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'QuickChat requests only necessary Bluetooth Low Energy permissions to discover nearby peers.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildPermissionTile(
            icon: LucideIcons.bluetooth,
            title: 'Bluetooth Low Energy',
            subtitle: 'Required to broadcast and receive multi-hop mesh packets.',
          ),
          const SizedBox(height: 12),
          _buildPermissionTile(
            icon: LucideIcons.mapPin,
            title: 'Nearby Devices (Android/iOS)',
            subtitle: 'Required by the operating system for BLE peer discovery. Exact GPS is NEVER collected.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGlow),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.radio, color: AppColors.primary),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Participate in Mesh Relay', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Help securely route nearby messages', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _meshRelayConsent,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _meshRelayConsent = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
