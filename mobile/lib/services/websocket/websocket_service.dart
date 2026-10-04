import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/message_model.dart';

enum InternetConnectionState {
  connected,
  connecting,
  disconnected,
}

class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  WebSocketService._internal();

  WebSocketChannel? _channel;
  InternetConnectionState _connectionState = InternetConnectionState.disconnected;
  String? _authToken;
  String _wsUrl = AppConstants.defaultWsUrl;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  final StreamController<InternetConnectionState> _stateStreamController = StreamController.broadcast();
  final StreamController<MessageEnvelope> _incomingMessageStreamController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _receiptStreamController = StreamController.broadcast();
  final StreamController<String> _peerOnlineStreamController = StreamController.broadcast();

  Stream<InternetConnectionState> get stateStream => _stateStreamController.stream;
  Stream<MessageEnvelope> get incomingMessageStream => _incomingMessageStreamController.stream;
  Stream<Map<String, dynamic>> get receiptStream => _receiptStreamController.stream;
  Stream<String> get peerOnlineStream => _peerOnlineStreamController.stream;

  InternetConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == InternetConnectionState.connected;

  void connect({required String token, String? customWsUrl}) {
    _authToken = token;
    if (customWsUrl != null) _wsUrl = customWsUrl;

    _reconnectTimer?.cancel();
    _setState(InternetConnectionState.connecting);

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) => _handleIncomingData(data),
        onDone: () => _handleDisconnect(),
        onError: (err) => _handleDisconnect(),
      );

      // Send auth frame
      _sendRaw({
        'event': 'auth',
        'data': {'token': _authToken}
      });

      _setState(InternetConnectionState.connected);
      _startHeartbeat();
      debugPrint('[WebSocket] Connected to $_wsUrl');
    } catch (e) {
      debugPrint('[WebSocket Error] Failed to connect: $e');
      _handleDisconnect();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(InternetConnectionState.disconnected);
  }

  /// Sends a message envelope over WebSocket to cloud gateway
  bool sendMessage(MessageEnvelope envelope) {
    if (!isConnected) return false;

    _sendRaw({
      'event': 'message.send',
      'data': envelope.toJson(),
    });
    return true;
  }

  /// Sends delivery / read receipt
  void sendReceipt(String messageId, String status) {
    if (!isConnected) return;
    _sendRaw({
      'event': 'message.$status',
      'data': {
        'messageId': messageId,
        'status': status,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    });
  }

  /// Request offline sync
  void requestOfflineSync() {
    if (!isConnected) return;
    _sendRaw({
      'event': 'sync.request',
      'data': {}
    });
  }

  void _handleIncomingData(dynamic data) {
    try {
      final json = jsonDecode(data.toString()) as Map<String, dynamic>;
      final event = json['event'] as String?;
      final payload = json['data'];

      switch (event) {
        case 'auth':
          debugPrint('[WebSocket] Authenticated with Cloud Gateway');
          break;
        case 'message.received':
        case 'group.message':
          final envelope = MessageEnvelope.fromJson(payload as Map<String, dynamic>);
          _incomingMessageStreamController.add(envelope);
          break;
        case 'message.delivered':
        case 'message.relayed':
        case 'message.read':
          _receiptStreamController.add(payload as Map<String, dynamic>);
          break;
        case 'peer.online':
          if (payload != null && payload['userId'] != null) {
            _peerOnlineStreamController.add(payload['userId'] as String);
          }
          break;
        case 'sync.response':
          final list = payload['pendingMessages'] as List<dynamic>? ?? [];
          for (final item in list) {
            final envelope = MessageEnvelope.fromJson(item as Map<String, dynamic>);
            _incomingMessageStreamController.add(envelope);
          }
          break;
        case 'pong':
          // Heartbeat ok
          break;
      }
    } catch (e) {
      debugPrint('[WebSocket] Error parsing data: $e');
    }
  }

  void _sendRaw(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _sendRaw({'event': 'ping', 'data': {}});
    });
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _setState(InternetConnectionState.disconnected);
    // Auto reconnect in 5s
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_authToken != null) {
        debugPrint('[WebSocket] Attempting auto-reconnect...');
        connect(token: _authToken!, customWsUrl: _wsUrl);
      }
    });
  }

  void _setState(InternetConnectionState state) {
    _connectionState = state;
    _stateStreamController.add(state);
  }
}
