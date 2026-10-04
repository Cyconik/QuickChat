import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/security/crypto_engine.dart';
import '../../../data/local/local_storage_service.dart';
import '../../../data/models/user_model.dart';
import '../../../services/ble/ble_mesh_service.dart';
import '../../../services/encryption/e2e_encryption_service.dart';
import '../../../services/mesh/mesh_network_engine.dart';
import '../../../services/routing/hybrid_router.dart';
import '../../../services/websocket/websocket_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    checkSavedIdentity();
  }

  Future<void> checkSavedIdentity() async {
    try {
      await LocalStorageService.init();
      final user = LocalStorageService.getUserIdentity();
      if (user != null) {
        _initializeSubsystems(user);
        state = AsyncValue.data(user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<UserModel> registerAnonymous({
    required String username,
    required String displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      // 1. Generate cryptographic keypair locally on device
      final keypair = CryptoEngine.generateIdentityKeyPair();

      // 2. Derive unique user ID: usr_XXXXXX
      final randomHex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).substring(4).toUpperCase();
      final userId = 'usr_$randomHex';

      final newUser = UserModel(
        id: userId,
        username: username.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), ''),
        displayName: displayName.trim(),
        publicKey: keypair.publicKey,
        privateKey: keypair.privateKey,
        bio: bio ?? 'Participating in QuickChat mesh.',
        avatarUrl: avatarUrl,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        privacy: const UserPrivacySettings(),
      );

      // 3. Save locally to encrypted storage
      await LocalStorageService.saveUserIdentity(newUser);

      // 4. Register with Cloud Gateway (if internet is available)
      _tryCloudRegistration(newUser);

      // 5. Initialize all offline mesh & crypto subsystems
      _initializeSubsystems(newUser);

      state = AsyncValue.data(newUser);
      return newUser;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void _initializeSubsystems(UserModel user) {
    E2EEncryptionService.instance.initialize(user);
    MeshNetworkEngine.instance.initialize(user: user);
    BleMeshService.instance.startMeshRadio(selfUserId: user.id, selfPublicKey: user.publicKey);
    HybridRouter.instance.initialize();
  }

  Future<void> _tryCloudRegistration(UserModel user) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.defaultApiUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': user.username,
          'displayName': user.displayName,
          'publicKey': user.publicKey,
          'bio': user.bio,
          'avatarUrl': user.avatarUrl,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final token = data['token'] as String?;
        if (token != null) {
          WebSocketService.instance.connect(token: token);
        }
      }
    } catch (e) {
      debugPrint('[Cloud Gateway] Offline during registration. Continuing with full local mesh operation.');
    }
  }

  Future<void> updatePrivacy(UserPrivacySettings privacy) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(privacy: privacy);
    await LocalStorageService.saveUserIdentity(updated);
    MeshNetworkEngine.instance.setRelayParticipation(privacy.allowRelay);
    state = AsyncValue.data(updated);
  }

  Future<void> logout() async {
    await LocalStorageService.clearUserIdentity();
    BleMeshService.instance.stopMeshRadio();
    WebSocketService.instance.disconnect();
    state = const AsyncValue.data(null);
  }
}
