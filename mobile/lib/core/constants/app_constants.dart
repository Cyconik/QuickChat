class AppConstants {
  // BLE GATT UUIDs
  static const String bleServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String bleRxCharUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'; // Write characteristic
  static const String bleTxCharUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'; // Notify characteristic
  static const String bleMeshManufacturerId = '0xFFFF';

  // Mesh Protocol Limits
  static const int defaultTtl = 8;
  static const int maxHops = 12;
  static const int maxBlePacketChunkSize = 180; // MTU friendly payload chunk
  static const int deduplicationCacheCapacity = 2000;
  static const Duration peerExpiryDuration = Duration(minutes: 5);
  static const Duration storeAndForwardTtl = Duration(hours: 72);

  // Endpoints
  static const String defaultApiUrl = 'http://10.0.2.2:3000';
  static const String defaultWsUrl = 'ws://10.0.2.2:3000/ws';

  // Local Storage Keys
  static const String keyUserIdentity = 'qc_user_identity';
  static const String keyPrivateKey = 'qc_private_key';
  static const String keyPublicKey = 'qc_public_key';
  static const String keyMeshRelayEnabled = 'qc_mesh_relay_enabled';
  static const String keyOnboardingCompleted = 'qc_onboarding_completed';
}
