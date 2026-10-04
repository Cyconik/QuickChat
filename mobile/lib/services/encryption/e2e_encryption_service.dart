import 'dart:convert';
import '../../core/security/crypto_engine.dart';
import '../../data/models/message_model.dart';
import '../../data/models/user_model.dart';

class E2EEncryptionService {
  static final E2EEncryptionService instance = E2EEncryptionService._internal();
  E2EEncryptionService._internal();

  UserModel? _currentUser;
  final Map<String, String> _groupSharedKeys = {}; // groupId -> symmetricKeyBase64

  void initialize(UserModel user) {
    _currentUser = user;
  }

  void registerGroupKey(String groupId, String sharedKeyBase64) {
    _groupSharedKeys[groupId] = sharedKeyBase64;
  }

  /// Encrypts and digitally signs an outgoing message
  MessageEnvelope prepareDirectMessage({
    required String conversationId,
    required String targetUserId,
    required String targetPublicKeyBase64,
    required String plaintext,
  }) {
    if (_currentUser == null) {
      throw Exception('E2EEncryptionService not initialized with user identity');
    }

    // Derive shared symmetric secret between sender private key and recipient public key
    final sharedSecret = '${_currentUser!.privateKey}:$targetPublicKeyBase64';
    final encryptedBase64 = CryptoEngine.encryptPayload(
      plaintext: plaintext,
      sharedSecretBase64: sharedSecret,
    );

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${_currentUser!.id.substring(4, 8)}';
    final signature = CryptoEngine.signPayload(encryptedBase64, _currentUser!.privateKey);

    return MessageEnvelope(
      messageId: messageId,
      senderId: _currentUser!.id,
      senderUsername: _currentUser!.username,
      conversationId: conversationId,
      messageType: 'text',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      destinationType: 'user',
      destinationId: targetUserId,
      encryptedPayload: encryptedBase64,
      signature: signature,
      decryptedContent: plaintext,
      status: MessageDeliveryStatus.pending,
    );
  }

  /// Encrypts a message destined for a group
  MessageEnvelope prepareGroupMessage({
    required String groupId,
    required String plaintext,
  }) {
    if (_currentUser == null) {
      throw Exception('E2EEncryptionService not initialized with user identity');
    }

    final groupKey = _groupSharedKeys[groupId] ?? 'group_default_secret_key_$groupId';
    final encryptedBase64 = CryptoEngine.encryptPayload(
      plaintext: plaintext,
      sharedSecretBase64: groupKey,
    );

    final messageId = 'grp_msg_${DateTime.now().millisecondsSinceEpoch}_${_currentUser!.id.substring(4, 8)}';
    final signature = CryptoEngine.signPayload(encryptedBase64, _currentUser!.privateKey);

    return MessageEnvelope(
      messageId: messageId,
      senderId: _currentUser!.id,
      senderUsername: _currentUser!.username,
      conversationId: groupId,
      messageType: 'text',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      destinationType: 'group',
      destinationId: groupId,
      encryptedPayload: encryptedBase64,
      signature: signature,
      decryptedContent: plaintext,
      status: MessageDeliveryStatus.pending,
    );
  }

  /// Decrypts an incoming message envelope
  String decryptIncomingMessage(MessageEnvelope envelope, {String? senderPublicKey}) {
    if (_currentUser == null) return '[Encrypted payload]';

    // If it's our own sent message
    if (envelope.senderId == _currentUser!.id && envelope.decryptedContent != null) {
      return envelope.decryptedContent!;
    }

    if (envelope.destinationType == 'user') {
      // Direct message: decrypt using sender public key + our private key
      final key = senderPublicKey ?? envelope.senderId;
      final sharedSecret = '${_currentUser!.privateKey}:$key';
      try {
        final decrypted = CryptoEngine.decryptPayload(
          encryptedBase64: envelope.encryptedPayload,
          sharedSecretBase64: sharedSecret,
        );
        envelope.decryptedContent = decrypted;
        return decrypted;
      } catch (e) {
        return '[Encrypted Direct Message]';
      }
    } else {
      // Group message
      final groupKey = _groupSharedKeys[envelope.destinationId] ?? 'group_default_secret_key_${envelope.destinationId}';
      try {
        final decrypted = CryptoEngine.decryptPayload(
          encryptedBase64: envelope.encryptedPayload,
          sharedSecretBase64: groupKey,
        );
        envelope.decryptedContent = decrypted;
        return decrypted;
      } catch (e) {
        return '[Encrypted Group Message]';
      }
    }
  }
}
