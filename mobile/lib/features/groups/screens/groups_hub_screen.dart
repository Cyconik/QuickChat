import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../chats/screens/chat_room_screen.dart';

class GroupsHubScreen extends ConsumerStatefulWidget {
  const GroupsHubScreen({super.key});

  @override
  ConsumerState<GroupsHubScreen> createState() => _GroupsHubScreenState();
}

class _GroupsHubScreenState extends ConsumerState<GroupsHubScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Technology', 'College', 'Events', 'Local', 'Gaming', 'General'];

  final List<GroupModel> _groups = [
    const GroupModel(
      id: 'group_delhi_tech',
      name: 'Delhi Tech Community',
      description: 'Decentralized peer-to-peer discussions for developers and creators in Delhi.',
      category: 'Technology',
      creatorId: 'usr_rahul',
      createdAt: 1712000000000,
      memberCount: 142,
      isMember: true,
    ),
    const GroupModel(
      id: 'group_mesh_builders',
      name: 'Mesh Network Engineers',
      description: 'Ad-hoc multi-hop forwarding protocol experiments and testing.',
      category: 'Technology',
      creatorId: 'usr_nikhil',
      createdAt: 1711900000000,
      memberCount: 88,
      isMember: true,
    ),
    const GroupModel(
      id: 'group_local_events',
      name: 'Nearby Events & Meetups',
      description: 'Live alerts for local events, hackathons, and gatherings.',
      category: 'Events',
      creatorId: 'usr_priya',
      createdAt: 1712100000000,
      memberCount: 65,
      isMember: false,
    ),
    const GroupModel(
      id: 'group_campus_mesh',
      name: 'Campus Mesh Hub',
      description: 'Student offline network for lectures, notes, and study groups.',
      category: 'College',
      creatorId: 'usr_campus',
      createdAt: 1712050000000,
      memberCount: 210,
      isMember: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _selectedCategory == 'All'
        ? _groups
        : _groups.where((g) => g.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Communities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plusCircle, size: 22, color: AppColors.primary),
            onPressed: () => _showCreateGroupModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.surfaceLight),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Groups List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredGroups.length,
              itemBuilder: (context, index) {
                final group = filteredGroups[index];
                return _buildGroupCard(group);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(GroupModel group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.users, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('${group.category} • ${group.memberCount} members', style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        targetId: group.id,
                        targetName: group.name,
                        targetHandle: group.category.toLowerCase(),
                        isGroup: true,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: group.isMember ? AppColors.surfaceLight : AppColors.primary,
                  foregroundColor: group.isMember ? AppColors.textPrimary : AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: Text(group.isMember ? 'Open' : 'Join'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(group.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
        ],
      ),
    );
  }

  void _showCreateGroupModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Technology';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create New Community', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Create a decentralized group that syncs across nearby mesh devices.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Community Name (e.g. Bangalore Coders)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Description & guidelines...'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    final newG = GroupModel(
                      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: category,
                      creatorId: 'self',
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                      memberCount: 1,
                      isMember: true,
                    );
                    setState(() => _groups.insert(0, newG));
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Create Community'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
