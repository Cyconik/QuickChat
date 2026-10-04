import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/local_storage_service.dart';
import 'chat_room_screen.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _directChats = [
    {
      'id': 'usr_rahul',
      'name': 'Rahul Sharma',
      'handle': 'rahul_dev',
      'lastMsg': 'Are you attending the mesh meetup today?',
      'time': '2m ago',
      'unread': 2,
      'isOnline': true,
      'route': 'BLE Mesh (2 hops)',
    },
    {
      'id': 'usr_priya',
      'name': 'Priya Patel',
      'handle': 'priya',
      'lastMsg': 'Encrypted payload confirmed. Received.',
      'time': '14m ago',
      'unread': 0,
      'isOnline': true,
      'route': 'Direct BLE',
    },
    {
      'id': 'usr_nikhil',
      'name': 'Nikhil Verma',
      'handle': 'nikhil_v',
      'lastMsg': 'Testing store-and-forward offline queue.',
      'time': '1h ago',
      'unread': 0,
      'isOnline': false,
      'route': 'Mesh (Store & Forward)',
    },
  ];

  final List<Map<String, dynamic>> _groupChats = [
    {
      'id': 'group_delhi_tech',
      'name': 'Delhi Tech Community',
      'handle': 'delhi_tech',
      'lastSender': 'Rahul',
      'lastMsg': 'Anyone attending the meetup?',
      'time': '10m ago',
      'unread': 5,
      'members': 142,
    },
    {
      'id': 'group_mesh_builders',
      'name': 'Mesh Network Engineers',
      'handle': 'mesh_engineers',
      'lastSender': 'Nikhil',
      'lastMsg': 'Multi-hop TTL test successful!',
      'time': '35m ago',
      'unread': 0,
      'members': 88,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Conversations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.edit3, size: 20),
            onPressed: () => _showNewChatDialog(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Direct Chats'),
              Tab(text: 'Groups'),
              Tab(text: 'Pinned'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats, peers or groups...',
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                fillColor: AppColors.surface,
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDirectList(),
                _buildGroupList(),
                _buildPinnedList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectList() {
    return ListView.builder(
      itemCount: _directChats.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final chat = _directChats[index];
        return _buildChatCard(
          name: chat['name'],
          handle: chat['handle'],
          lastMsg: chat['lastMsg'],
          time: chat['time'],
          unread: chat['unread'],
          isOnline: chat['isOnline'],
          routeInfo: chat['route'],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  targetId: chat['id'],
                  targetName: chat['name'],
                  targetHandle: chat['handle'],
                  isGroup: false,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupList() {
    return ListView.builder(
      itemCount: _groupChats.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final g = _groupChats[index];
        return _buildChatCard(
          name: g['name'],
          handle: '${g['members']} members',
          lastMsg: '${g['lastSender']}: ${g['lastMsg']}',
          time: g['time'],
          unread: g['unread'],
          isGroup: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  targetId: g['id'],
                  targetName: g['name'],
                  targetHandle: g['handle'],
                  isGroup: true,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPinnedList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.pin, size: 40, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('No Pinned Conversations', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Long press any chat to pin it here.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildChatCard({
    required String name,
    required String handle,
    required String lastMsg,
    required String time,
    required int unread,
    bool isOnline = false,
    bool isGroup = false,
    String? routeInfo,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isGroup ? AppColors.secondaryGlow : AppColors.primaryGlow,
              child: Icon(
                isGroup ? LucideIcons.users : LucideIcons.user,
                color: isGroup ? AppColors.secondary : AppColors.primary,
                size: 22,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.between,
          children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
            ),
            Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(lastMsg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (routeInfo != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.gitFork, size: 11, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(routeInfo, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
        trailing: unread > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: AppColors.textOnPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start Direct Conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enter user @handle or cryptographic ID:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '@username or usr_XXXXXX',
                prefixIcon: Icon(LucideIcons.user, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomScreen(
                          targetId: text.startsWith('usr_') ? text : 'usr_$text',
                          targetName: text.replaceAll('@', ''),
                          targetHandle: text.replaceAll('@', ''),
                          isGroup: false,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Open Direct Chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
