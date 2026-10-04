class Peer {
  final String peerId; // Unique device / user cryptographic identifier
  final String? username;
  final String? displayName;
  final String publicKey;
  final int lastSeen; // Epoch timestamp (ms)
  final int signalStrength; // RSSI in dBm (e.g. -65)
  final List<String> capabilities;
  final int protocolVersion;
  final bool isConnected;

  const Peer({
    required this.peerId,
    this.username,
    this.displayName,
    required this.publicKey,
    required this.lastSeen,
    this.signalStrength = -70,
    this.capabilities = const ['mesh_relay', 'direct_chat', 'group_fanout'],
    this.protocolVersion = 1,
    this.isConnected = false,
  });

  String get proximityLabel {
    if (signalStrength >= -60) return 'Immediate proximity';
    if (signalStrength >= -75) return 'Approx. nearby (< 10m)';
    if (signalStrength >= -90) return 'Mesh range (< 30m)';
    return 'Distant relay';
  }

  Map<String, dynamic> toJson() {
    return {
      'peerId': peerId,
      'username': username,
      'displayName': displayName,
      'publicKey': publicKey,
      'lastSeen': lastSeen,
      'signalStrength': signalStrength,
      'capabilities': capabilities,
      'protocolVersion': protocolVersion,
      'isConnected': isConnected,
    };
  }

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      peerId: json['peerId'] as String,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      publicKey: (json['publicKey'] as String?) ?? '',
      lastSeen: (json['lastSeen'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      signalStrength: (json['signalStrength'] as num?)?.toInt() ?? -70,
      capabilities: (json['capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['mesh_relay'],
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 1,
      isConnected: json['isConnected'] as bool? ?? false,
    );
  }

  Peer copyWith({
    String? peerId,
    String? username,
    String? displayName,
    String? publicKey,
    int? lastSeen,
    int? signalStrength,
    List<String>? capabilities,
    int? protocolVersion,
    bool? isConnected,
  }) {
    return Peer(
      peerId: peerId ?? this.peerId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      publicKey: publicKey ?? this.publicKey,
      lastSeen: lastSeen ?? this.lastSeen,
      signalStrength: signalStrength ?? this.signalStrength,
      capabilities: capabilities ?? this.capabilities,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
