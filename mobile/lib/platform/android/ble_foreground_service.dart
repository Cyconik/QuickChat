import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BleForegroundService {
  static const MethodChannel _channel = MethodChannel('com.quickchat.mesh/foreground_service');

  /// Starts Android Foreground Service to maintain BLE mesh peripheral & scanner in background
  static Future<bool> startService({required String notificationTitle, required String notificationBody}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startForegroundService', {
        'title': notificationTitle,
        'body': notificationBody,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('[Android Service] Foreground service fallback: $e');
      return false;
    }
  }

  static Future<void> stopService() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }
}
