import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/peer_model.dart';
import '../models/group_model.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Identity & Auth
  static Future<void> saveUserIdentity(UserModel user) async {
    await _prefs?.setString(AppConstants.keyUserIdentity, jsonEncode(user.toJson()));
    await _prefs?.setString(AppConstants.keyPrivateKey, user.privateKey);
    await _prefs?.setString(AppConstants.keyPublicKey, user.publicKey);
  }

  static UserModel? getUserIdentity() {
    final raw = _prefs?.getString(AppConstants.keyUserIdentity);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUserIdentity() async {
    await _prefs?.remove(AppConstants.keyUserIdentity);
    await _prefs?.remove(AppConstants.keyPrivateKey);
    await _prefs?.remove(AppConstants.keyPublicKey);
  }

  // Deduplication seen cache
  static Set<String> getSeenMessageIds() {
    final list = _prefs?.getStringList('qc_seen_message_ids') ?? [];
    return list.toSet();
  }

  static Future<void> markMessageSeen(String messageId) async {
    final set = getSeenMessageIds();
    set.add(messageId);
    if (set.length > AppConstants.deduplicationCacheCapacity) {
      final trimmed = set.skip(set.length - AppConstants.deduplicationCacheCapacity).toList();
      await _prefs?.setStringList('qc_seen_message_ids', trimmed);
    } else {
      await _prefs?.setStringList('qc_seen_message_ids', set.toList());
    }
  }

  // Messages per conversation
  static List<MessageEnvelope> getMessagesForConversation(String conversationId) {
    final raw = _prefs?.getString('qc_conv_msgs_$conversationId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => MessageEnvelope.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMessage(MessageEnvelope message) async {
    final convId = message.conversationId;
    final current = getMessagesForConversation(convId);
    final idx = current.indexWhere((m) => m.messageId == message.messageId);

    if (idx >= 0) {
      current[idx] = message;
    } else {
      current.add(message);
    }

    // Keep last 500 messages per conversation
    final bounded = current.length > 500 ? current.sublist(current.length - 500) : current;
    final jsonList = bounded.map((m) => m.toJson()).toList();
    await _prefs?.setString('qc_conv_msgs_$convId', jsonEncode(jsonList));

    // Update conversation index
    await _updateConversationIndex(convId, message);
  }

  static List<String> getConversationIds() {
    return _prefs?.getStringList('qc_all_conversations') ?? [];
  }

  static Future<void> _updateConversationIndex(String conversationId, MessageEnvelope lastMessage) async {
    final list = getConversationIds().toSet();
    list.add(conversationId);
    await _prefs?.setStringList('qc_all_conversations', list.toList());
    await _prefs?.setString('qc_conv_last_$conversationId', jsonEncode(lastMessage.toJson()));
  }

  static MessageEnvelope? getLastMessageForConversation(String conversationId) {
    final raw = _prefs?.getString('qc_conv_last_$conversationId');
    if (raw == null) return null;
    try {
      return MessageEnvelope.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // Store-and-Forward pending queue (offline delivery queue)
  static List<MessageEnvelope> getPendingStoreForwardQueue() {
    final raw = _prefs?.getString('qc_store_forward_queue');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => MessageEnvelope.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addToStoreForwardQueue(MessageEnvelope message) async {
    final queue = getPendingStoreForwardQueue();
    if (!queue.any((m) => m.messageId == message.messageId)) {
      queue.add(message);
      await _prefs?.setString('qc_store_forward_queue', jsonEncode(queue.map((m) => m.toJson()).toList()));
    }
  }

  static Future<void> removeFromStoreForwardQueue(String messageId) async {
    final queue = getPendingStoreForwardQueue();
    queue.removeWhere((m) => m.messageId == messageId);
    await _prefs?.setString('qc_store_forward_queue', jsonEncode(queue.map((m) => m.toJson()).toList()));
  }

  // Mesh Settings
  static bool isMeshRelayEnabled() {
    return _prefs?.getBool(AppConstants.keyMeshRelayEnabled) ?? true;
  }

  static Future<void> setMeshRelayEnabled(bool enabled) async {
    await _prefs?.setBool(AppConstants.keyMeshRelayEnabled, enabled);
  }

  static int getMaxRelayTtl() {
    return _prefs?.getInt('qc_max_relay_ttl') ?? AppConstants.defaultTtl;
  }

  static Future<void> setMaxRelayTtl(int ttl) async {
    await _prefs?.setInt('qc_max_relay_ttl', ttl);
  }
}
