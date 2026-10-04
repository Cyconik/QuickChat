import 'dart:convert';

enum MessageDeliveryStatus {
  pending,   // ✓ Clock / Pending local send
  sent,      // ✓ Sent from device
  relayed,   // ✓✓ Relayed through mesh node or cloud queue
  delivered, // ✓✓✓ Delivered to recipient device
  read,      // ✓✓✓✓ Read by recipient
  failed,    // ✕ Failed
}

class MessageEnvelope {
  final String messageId;
  final String senderId;
  final String? senderUsername;
  final String conversationId;
  final String messageType; // 'text' | 'image' | 'file' | 'system' | 'ack'
  final int createdAt;
  int ttl;
  int hopCount;
  final String destinationType; // 'user' | 'group'
  final String destinationId;
  final String encryptedPayload;
  final String signature;
  final List<String> relayPath;
  MessageDeliveryStatus status;

  // Local decrypted cache for UI rendering
  String? decryptedContent;

  MessageEnvelope({
    required this.messageId,
    required this.senderId,
    this.senderUsername,
    required this.conversationId,
    this.messageType = 'text',
    required this.createdAt,
    this.ttl = 8,
    this.hopCount = 0,
    required this.destinationType,
    required this.destinationId,
    required this.encryptedPayload,
    required this.signature,
    List<String>? relayPath,
    this.status = MessageDeliveryStatus.pending,
    this.decryptedContent,
  }) : relayPath = relayPath ?? [];

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      if (senderUsername != null) 'senderUsername': senderUsername,
      'conversationId': conversationId,
      'messageType': messageType,
      'createdAt': createdAt,
      'ttl': ttl,
      'hopCount': hopCount,
      'destinationType': destinationType,
      'destinationId': destinationId,
      'encryptedPayload': encryptedPayload,
      'signature': signature,
      'relayPath': relayPath,
      'status': status.name,
    };
  }

  factory MessageEnvelope.fromJson(Map<String, dynamic> json) {
    return MessageEnvelope(
      messageId: json['messageId'] as String,
      senderId: json['senderId'] as String,
      senderUsername: json['senderUsername'] as String?,
      conversationId: json['conversationId'] as String,
      messageType: (json['messageType'] as String?) ?? 'text',
      createdAt: (json['createdAt'] as num).toInt(),
      ttl: (json['ttl'] as num?)?.toInt() ?? 8,
      hopCount: (json['hopCount'] as num?)?.toInt() ?? 0,
      destinationType: json['destinationType'] as String,
      destinationId: json['destinationId'] as String,
      encryptedPayload: json['encryptedPayload'] as String,
      signature: json['signature'] as String,
      relayPath: (json['relayPath'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      status: MessageDeliveryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageDeliveryStatus.sent,
      ),
    );
  }

  String toRawPacket() => jsonEncode(toJson());

  factory MessageEnvelope.fromRawPacket(String raw) {
    return MessageEnvelope.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  MessageEnvelope copyWith({
    String? messageId,
    String? senderId,
    String? senderUsername,
    String? conversationId,
    String? messageType,
    int? createdAt,
    int? ttl,
    int? hopCount,
    String? destinationType,
    String? destinationId,
    String? encryptedPayload,
    String? signature,
    List<String>? relayPath,
    MessageDeliveryStatus? status,
    String? decryptedContent,
  }) {
    return MessageEnvelope(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      conversationId: conversationId ?? this.conversationId,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt ?? this.createdAt,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      destinationType: destinationType ?? this.destinationType,
      destinationId: destinationId ?? this.destinationId,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      signature: signature ?? this.signature,
      relayPath: relayPath ?? List.from(this.relayPath),
      status: status ?? this.status,
      decryptedContent: decryptedContent ?? this.decryptedContent,
    );
  }
}
