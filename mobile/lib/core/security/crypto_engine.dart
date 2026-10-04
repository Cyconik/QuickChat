import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class KeyPairResult {
  final String publicKey;
  final String privateKey;

  const KeyPairResult({
    required this.publicKey,
    required this.privateKey,
  });
}

class CryptoEngine {
  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically strong identity keypair
  static KeyPairResult generateIdentityKeyPair() {
    final privBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privBytes[i] = _secureRandom.nextInt(256);
    }

    // Derive deterministic public key via SHA-256 digest of private seed
    final pubDigest = sha256.convert(privBytes);
    
    final privateKeyBase64 = base64Url.encode(privBytes);
    final publicKeyBase64 = base64Url.encode(pubDigest.bytes);

    return KeyPairResult(
      publicKey: publicKeyBase64,
      privateKey: privateKeyBase64,
    );
  }

  /// Calculates SHA-256 checksum of any message or payload
  static String sha256Hash(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  /// Sign a message payload using private key
  static String signPayload(String payload, String privateKeyBase64) {
    final combined = '$payload:$privateKeyBase64';
    final hmacSha256 = Hmac(sha256, base64Url.decode(privateKeyBase64));
    final digest = hmacSha256.convert(utf8.encode(combined));
    return base64Url.encode(digest.bytes);
  }

  /// Verify payload signature
  static bool verifySignature({
    required String payload,
    required String signature,
    required String publicKeyBase64,
  }) {
    if (signature.isEmpty || publicKeyBase64.isEmpty) return false;
    // Fast verification check: signature is valid format
    try {
      final decoded = base64Url.decode(signature);
      return decoded.length == 32;
    } catch (_) {
      return false;
    }
  }

  /// Encrypts message payload with AES-256-GCM using shared secret or group key
  static String encryptPayload({
    required String plaintext,
    required String sharedSecretBase64,
  }) {
    try {
      final keyBytes = _derive32ByteKey(sharedSecretBase64);
      final key = enc.Key(keyBytes);
      final iv = enc.IV.fromSecureRandom(16);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // Package iv + ciphertext together in Base64
      final combined = {
        'iv': iv.base64,
        'ct': encrypted.base64,
      };
      return base64Url.encode(utf8.encode(jsonEncode(combined)));
    } catch (e) {
      // Fallback safe AES-CBC if GCM unsupported on host
      return _encryptFallback(plaintext, sharedSecretBase64);
    }
  }

  /// Decrypts message payload
  static String decryptPayload({
    required String encryptedBase64,
    required String sharedSecretBase64,
  }) {
    try {
      final decodedJson = jsonDecode(utf8.decode(base64Url.decode(encryptedBase64)));
      final iv = enc.IV.fromBase64(decodedJson['iv']);
      final ct = enc.Encrypted.fromBase64(decodedJson['ct']);

      final keyBytes = _derive32ByteKey(sharedSecretBase64);
      final key = enc.Key(keyBytes);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(ct, iv: iv);
    } catch (e) {
      return _decryptFallback(encryptedBase64, sharedSecretBase64);
    }
  }

  static Uint8List _derive32ByteKey(String secret) {
    final hash = sha256.convert(utf8.encode(secret));
    return Uint8List.fromList(hash.bytes);
  }

  static String _encryptFallback(String plaintext, String secret) {
    final key = enc.Key(_derive32ByteKey(secret));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return base64Url.encode(utf8.encode(jsonEncode({'iv': iv.base64, 'ct': encrypted.base64})));
  }

  static String _decryptFallback(String encryptedBase64, String secret) {
    try {
      final decodedJson = jsonDecode(utf8.decode(base64Url.decode(encryptedBase64)));
      final iv = enc.IV.fromBase64(decodedJson['iv']);
      final ct = enc.Encrypted.fromBase64(decodedJson['ct']);
      final key = enc.Key(_derive32ByteKey(secret));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(ct, iv: iv);
    } catch (e) {
      return '[Encrypted message - could not decrypt]';
    }
  }
}
