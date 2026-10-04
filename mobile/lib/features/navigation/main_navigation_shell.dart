import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../home/screens/home_dashboard_screen.dart';
import '../chats/screens/chats_list_screen.dart';
import '../nearby/screens/nearby_radar_screen.dart';
import '../groups/screens/groups_hub_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../simulator/screens/mesh_simulator_screen.dart';
import '../debug/screens/debug_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeDashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
    const ChatsListScreen(),
    const NearbyRadarScreen(),
    const GroupsHubScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.surfaceHighlight,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        icon: const Icon(LucideIcons.network, size: 16, color: AppColors.primary),
        label: const Text('Simulator', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MeshSimulatorScreen()),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.surfaceLight, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.home, size: 20),
              activeIcon: Icon(LucideIcons.home, size: 20, color: AppColors.primary),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.messageSquare, size: 20),
              activeIcon: Icon(LucideIcons.messageSquare, size: 20, color: AppColors.primary),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.radar, size: 20),
              activeIcon: Icon(LucideIcons.radar, size: 20, color: AppColors.primary),
              label: 'Nearby',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.users, size: 20),
              activeIcon: Icon(LucideIcons.users, size: 20, color: AppColors.primary),
              label: 'Groups',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.user, size: 20),
              activeIcon: Icon(LucideIcons.user, size: 20, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
