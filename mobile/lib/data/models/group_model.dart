class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? avatarUrl;
  final String privacy; // 'public' | 'private' | 'invite_only'
  final String category;
  final String creatorId;
  final int createdAt;
  final int memberCount;
  final bool isMember;
  final String? groupSharedKey; // Symmetric encryption key for group messages

  const GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl,
    this.privacy = 'public',
    this.category = 'general',
    required this.creatorId,
    required this.createdAt,
    this.memberCount = 1,
    this.isMember = false,
    this.groupSharedKey,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'avatarUrl': avatarUrl,
    'privacy': privacy,
    'category': category,
    'creatorId': creatorId,
    'createdAt': createdAt,
    'memberCount': memberCount,
    'isMember': isMember,
    'groupSharedKey': groupSharedKey,
  };

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    privacy: json['privacy'] as String? ?? 'public',
    category: json['category'] as String? ?? 'general',
    creatorId: json['creatorId'] as String? ?? '',
    createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
    isMember: json['isMember'] as bool? ?? false,
    groupSharedKey: json['groupSharedKey'] as String?,
  );

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarUrl,
    String? privacy,
    String? category,
    String? creatorId,
    int? createdAt,
    int? memberCount,
    bool? isMember,
    String? groupSharedKey,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      privacy: privacy ?? this.privacy,
      category: category ?? this.category,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      groupSharedKey: groupSharedKey ?? this.groupSharedKey,
    );
  }
}

class ConnectionModel {
  final String id;
  final String targetUserId;
  final String targetUsername;
  final String targetDisplayName;
  final String? targetAvatarUrl;
  final String status; // 'requested' | 'accepted' | 'rejected' | 'blocked'
  final int updatedAt;

  const ConnectionModel({
    required this.id,
    required this.targetUserId,
    required this.targetUsername,
    required this.targetDisplayName,
    this.targetAvatarUrl,
    required this.status,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'targetUserId': targetUserId,
    'targetUsername': targetUsername,
    'targetDisplayName': targetDisplayName,
    'targetAvatarUrl': targetAvatarUrl,
    'status': status,
    'updatedAt': updatedAt,
  };

  factory ConnectionModel.fromJson(Map<String, dynamic> json) => ConnectionModel(
    id: json['id'] as String,
    targetUserId: json['targetUserId'] as String,
    targetUsername: json['targetUsername'] as String? ?? '',
    targetDisplayName: json['targetDisplayName'] as String? ?? '',
    targetAvatarUrl: json['targetAvatarUrl'] as String?,
    status: json['status'] as String? ?? 'requested',
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
  );
}
