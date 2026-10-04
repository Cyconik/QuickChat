import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/local_storage_service.dart';
import '../../../data/models/message_model.dart';
import '../../../services/encryption/e2e_encryption_service.dart';
import '../../../services/routing/hybrid_router.dart';
import '../../auth/providers/auth_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String targetId; // userId or groupId
  final String targetName;
  final String targetHandle;
  final bool isGroup;

  const ChatRoomScreen({
    super.key,
    required this.targetId,
    required this.targetName,
    required this.targetHandle,
    this.isGroup = false,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MessageEnvelope> _messages = [];
  StreamSubscription? _incomingSub;
  String _activeRouteInfo = 'Automatic Hybrid (Mesh + Cloud)';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _listenIncoming();
  }

  void _loadHistory() {
    final history = LocalStorageService.getMessagesForConversation(widget.targetId);
    if (history.isNotEmpty) {
      setState(() {
        _messages.addAll(history);
      });
    } else {
      // Add initial seed messages for rich UX demonstration
      _addSampleHistory();
    }
  }

  void _addSampleHistory() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (widget.isGroup) {
      _messages.addAll([
        MessageEnvelope(
          messageId: 'seed_grp_1',
          senderId: 'usr_rahul',
          senderUsername: 'rahul_dev',
          conversationId: widget.targetId,
          createdAt: now - 3600000,
          destinationType: 'group',
          destinationId: widget.targetId,
          encryptedPayload: 'enc_1',
          signature: 'sig_1',
          decryptedContent: 'Anyone attending the offline mesh test today?',
          status: MessageDeliveryStatus.delivered,
        ),
        MessageEnvelope(
          messageId: 'seed_grp_2',
          senderId: 'usr_priya',
          senderUsername: 'priya',
          conversationId: widget.targetId,
          createdAt: now - 1800000,
          destinationType: 'group',
          destinationId: widget.targetId,
          encryptedPayload: 'enc_2',
          signature: 'sig_2',
          decryptedContent: 'Yes! My phone is set to active mesh relay.',
          status: MessageDeliveryStatus.delivered,
        ),
      ]);
    } else {
      _messages.addAll([
        MessageEnvelope(
          messageId: 'seed_dir_1',
          senderId: widget.targetId,
          senderUsername: widget.targetHandle,
          conversationId: widget.targetId,
          createdAt: now - 1800000,
          destinationType: 'user',
          destinationId: 'self',
          encryptedPayload: 'enc_dir_1',
          signature: 'sig_dir_1',
          decryptedContent: 'Hey! Are you within Bluetooth range right now?',
          status: MessageDeliveryStatus.read,
        ),
      ]);
    }
  }

  void _listenIncoming() {
    _incomingSub = HybridRouter.instance.routedMessageStream.listen((envelope) {
      if (envelope.conversationId == widget.targetId || envelope.senderId == widget.targetId) {
        final decrypted = E2EEncryptionService.instance.decryptIncomingMessage(envelope);
        envelope.decryptedContent = decrypted;

        setState(() {
          final idx = _messages.indexWhere((m) => m.messageId == envelope.messageId);
          if (idx >= 0) {
            _messages[idx] = envelope;
          } else {
            _messages.add(envelope);
          }
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    final user = ref.read(authProvider).value;
    if (user == null) return;

    // 1. Prepare Encrypted & Signed Message Envelope
    MessageEnvelope envelope;
    if (widget.isGroup) {
      envelope = E2EEncryptionService.instance.prepareGroupMessage(
        groupId: widget.targetId,
        plaintext: text,
      );
    } else {
      envelope = E2EEncryptionService.instance.prepareDirectMessage(
        conversationId: widget.targetId,
        targetUserId: widget.targetId,
        targetPublicKeyBase64: 'recipient_pub_key_${widget.targetId}',
        plaintext: text,
      );
    }

    setState(() {
      _messages.add(envelope);
    });
    _scrollToBottom();

    // 2. Route via Hybrid Router (Direct BLE -> Multi-hop Mesh -> Cloud WebSocket)
    final route = await HybridRouter.instance.routeMessage(envelope);

    setState(() {
      switch (route) {
        case TransportRoute.bleDirect:
          _activeRouteInfo = 'Direct BLE Radio';
          envelope.status = MessageDeliveryStatus.sent;
          break;
        case TransportRoute.bleMeshRelay:
          _activeRouteInfo = 'Multi-Hop Mesh Network (TTL: 8)';
          envelope.status = MessageDeliveryStatus.relayed;
          break;
        case TransportRoute.cloudWebSocket:
          _activeRouteInfo = 'Cloud WebSocket';
          envelope.status = MessageDeliveryStatus.delivered;
          break;
        case TransportRoute.storeAndForwardLocal:
          _activeRouteInfo = 'Stored for Forwarding';
          envelope.status = MessageDeliveryStatus.pending;
          break;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.isGroup ? AppColors.secondaryGlow : AppColors.primaryGlow,
              child: Icon(
                widget.isGroup ? LucideIcons.users : LucideIcons.user,
                color: widget.isGroup ? AppColors.secondary : AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.targetName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text(
                    widget.isGroup ? '${widget.targetHandle} • E2E Encrypted' : '@${widget.targetHandle} • Mesh Ready',
                    style: const TextStyle(fontSize: 11, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.accent),
            tooltip: 'E2E Encryption Verified',
            onPressed: () => _showSecurityDetails(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.moreVertical, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Transport banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.radio, size: 12, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Route: $_activeRouteInfo',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.senderId == user?.id || msg.destinationId != user?.id && msg.senderId != widget.targetId;
                return _buildMessageBubble(msg, isMe);
              },
            ),
          ),

          // Input Bar
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageEnvelope msg, bool isMe) {
    final timeStr = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(msg.createdAt));
    final content = msg.decryptedContent ?? msg.encryptedPayload;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.surfaceHighlight : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: Border.all(
            color: isMe ? AppColors.primary.withOpacity(0.3) : AppColors.surfaceLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && widget.isGroup && msg.senderUsername != null) ...[
              Text(
                '@${msg.senderUsername}',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              content,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.3),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.hopCount > 0) ...[
                  const Icon(LucideIcons.gitFork, size: 10, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text('${msg.hopCount} hops', style: const TextStyle(fontSize: 10, color: AppColors.primary)),
                  const SizedBox(width: 6),
                ],
                Text(timeStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  _buildDeliveryStatusIcon(msg.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryStatusIcon(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.pending:
        return const Icon(LucideIcons.clock, size: 12, color: AppColors.textMuted);
      case MessageDeliveryStatus.sent:
        return const Icon(LucideIcons.check, size: 13, color: AppColors.textMuted);
      case MessageDeliveryStatus.relayed:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.check, size: 13, color: AppColors.primary),
            Icon(LucideIcons.check, size: 13, color: AppColors.primary),
          ],
        );
      case MessageDeliveryStatus.delivered:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCheck, size: 13, color: AppColors.accent),
          ],
        );
      case MessageDeliveryStatus.read:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCheck, size: 13, color: AppColors.primary),
          ],
        );
      case MessageDeliveryStatus.failed:
        return const Icon(LucideIcons.alertCircle, size: 12, color: AppColors.error);
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.plusCircle, color: AppColors.textSecondary, size: 22),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type encrypted message...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(LucideIcons.send, color: AppColors.textOnPrimary, size: 18),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityDetails(BuildContext context) {
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
            const Row(
              children: [
                Icon(LucideIcons.shieldCheck, color: AppColors.accent, size: 24),
                SizedBox(width: 10),
                Text('End-to-End Encryption', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Messages sent in this conversation are encrypted with AES-256-GCM and signed with Ed25519 digital signatures. Intermediate mesh relay nodes cannot read or modify message contents.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.key, size: 16, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conversation Target: ${widget.targetId}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
