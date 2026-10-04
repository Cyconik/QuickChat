class UserPrivacySettings {
  final String discoverableBy; // 'everyone' | 'nearby_only' | 'connections_only' | 'nobody'
  final String messageableBy; // 'everyone' | 'connections_only' | 'nobody'
  final bool showOnlineStatus;
  final bool showNearbyPresence;
  final bool allowRelay;

  const UserPrivacySettings({
    this.discoverableBy = 'everyone',
    this.messageableBy = 'everyone',
    this.showOnlineStatus = true,
    this.showNearbyPresence = true,
    this.allowRelay = true,
  });

  Map<String, dynamic> toJson() => {
    'discoverableBy': discoverableBy,
    'messageableBy': messageableBy,
    'showOnlineStatus': showOnlineStatus,
    'showNearbyPresence': showNearbyPresence,
    'allowRelay': allowRelay,
  };

  factory UserPrivacySettings.fromJson(Map<String, dynamic> json) => UserPrivacySettings(
    discoverableBy: json['discoverableBy'] as String? ?? 'everyone',
    messageableBy: json['messageableBy'] as String? ?? 'everyone',
    showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
    showNearbyPresence: json['showNearbyPresence'] as bool? ?? true,
    allowRelay: json['allowRelay'] as bool? ?? true,
  );
}

class UserModel {
  final String id; // usr_XXXXXX
  final String username;
  final String displayName;
  final String publicKey;
  final String privateKey;
  final String bio;
  final String? avatarUrl;
  final int createdAt;
  final UserPrivacySettings privacy;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.publicKey,
    required this.privateKey,
    this.bio = 'Participating in QuickChat mesh.',
    this.avatarUrl,
    required this.createdAt,
    this.privacy = const UserPrivacySettings(),
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'publicKey': publicKey,
    'privateKey': privateKey,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt,
    'privacy': privacy.toJson(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    username: json['username'] as String,
    displayName: json['displayName'] as String,
    publicKey: json['publicKey'] as String,
    privateKey: (json['privateKey'] as String?) ?? '',
    bio: json['bio'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    privacy: json['privacy'] != null
        ? UserPrivacySettings.fromJson(json['privacy'] as Map<String, dynamic>)
        : const UserPrivacySettings(),
  );

  UserModel copyWith({
    String? id,
    String? username,
    String? displayName,
    String? publicKey,
    String? privateKey,
    String? bio,
    String? avatarUrl,
    int? createdAt,
    UserPrivacySettings? privacy,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      privacy: privacy ?? this.privacy,
    );
  }
}
