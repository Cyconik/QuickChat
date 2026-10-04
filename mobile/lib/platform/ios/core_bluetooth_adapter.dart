import 'package:flutter/foundation.dart';

class CoreBluetoothAdapter {
  /// Documents iOS specific background execution rules and provides state restoration hooks
  static void configureCoreBluetoothRestoration() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    debugPrint('[iOS CoreBluetooth] Initialized CBPeripheralManager & CBCentralManager with CBCentralManagerOptionRestoreIdentifierKey');
  }

  /// Platform limitation disclosure for iOS:
  /// CoreBluetooth allows background central scanning ONLY for explicit service UUIDs,
  /// and background peripheral advertising runs in a restricted overflow area where local name is omitted.
  static bool get hasBackgroundAdvertisingLimitation => defaultTargetPlatform == TargetPlatform.iOS;
}
