import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Exception thrown when secure credential storage operations fail.
/// Messages and exceptions are sanitized to ensure sensitive credential values are never exposed.
class SecureStorageException implements Exception {
  final String message;
  final Object? cause;

  const SecureStorageException(this.message, {this.cause});

  @override
  String toString() => 'SecureStorageException: $message';
}

/// Abstract contract for secure key storage operations.
/// Allows injecting test doubles for deterministic failure testing.
abstract class SecureStorageClient {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String? value});
  Future<void> delete({required String key});
}

/// Default implementation backed by [FlutterSecureStorage].
class DefaultSecureStorageClient implements SecureStorageClient {
  final FlutterSecureStorage _storage;

  const DefaultSecureStorageClient([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    ),
  ]);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// Wrapper around [FlutterSecureStorage] for secrets that must never
/// live in plain-text on disk (Gemini API key, Hive encryption key,
/// Google OAuth tokens).
class SecureKeyService {
  static SecureStorageClient _storage = const DefaultSecureStorageClient();

  @visibleForTesting
  static void setStorageForTesting(SecureStorageClient storage) {
    _storage = storage;
  }

  @visibleForTesting
  static void resetStorageForTesting() {
    _storage = const DefaultSecureStorageClient();
  }

  static const _kGeminiKey = 'gemini_api_key';
  static const _kHiveKey = 'hive_encryption_key';
  static const _kGoogleTokens = 'google_oauth_tokens';

  /// Returns the stored Gemini API key, or null if no key is configured.
  /// Throws [SecureStorageException] if reading from secure storage fails.
  static Future<String?> getGeminiApiKey() async {
    try {
      return await _storage.read(key: _kGeminiKey);
    } catch (e) {
      if (e is SecureStorageException) rethrow;
      throw SecureStorageException(
        'Failed to read Gemini API key from secure storage',
        cause: e,
      );
    }
  }

  /// Persists [key] into secure storage and verifies persistence by reading it back.
  /// Throws [SecureStorageException] if writing, reading, or verification fails.
  /// Never exposes [key] in error messages.
  static Future<void> saveGeminiApiKey(String key) async {
    try {
      await _storage.write(key: _kGeminiKey, value: key);
    } catch (e) {
      throw SecureStorageException(
        'Failed to write Gemini API key to secure storage',
        cause: e,
      );
    }

    // Read-back verification
    String? readBack;
    try {
      readBack = await _storage.read(key: _kGeminiKey);
    } catch (e) {
      throw SecureStorageException(
        'Failed to read back Gemini API key from secure storage for verification',
        cause: e,
      );
    }

    if (readBack != key) {
      throw const SecureStorageException(
        'Verification failed: secure storage did not return the expected Gemini API key',
      );
    }
  }

  /// Deletes the Gemini API key from secure storage and verifies deletion.
  /// Throws [SecureStorageException] if deletion or read-back verification fails.
  static Future<void> deleteGeminiApiKey() async {
    try {
      await _storage.delete(key: _kGeminiKey);
    } catch (e) {
      throw SecureStorageException(
        'Failed to delete Gemini API key from secure storage',
        cause: e,
      );
    }

    // Verify deletion succeeded
    String? readBack;
    try {
      readBack = await _storage.read(key: _kGeminiKey);
    } catch (e) {
      throw SecureStorageException(
        'Failed to verify Gemini API key deletion from secure storage',
        cause: e,
      );
    }

    if (readBack != null && readBack.isNotEmpty) {
      throw const SecureStorageException(
        'Verification failed: Gemini API key still present in secure storage after deletion',
      );
    }
  }

  // ── Hive AES encryption key ─────────────────────────────────────────

  /// Returns a persisted 32-byte key for [HiveAesCipher].
  /// Generates and stores one on first call if no existing key is found.
  ///
  /// Invariant: If secure storage read fails or returns null while existing
  /// encrypted data is detected (via [hasExistingData]), this method NEVER
  /// overwrites or generates a new key, preventing catastrophic data loss.
  ///
  /// Throws [SecureStorageException] if:
  /// - reading from secure storage fails,
  /// - stored key format is invalid or byte length is not 32,
  /// - key is absent but existing data was detected,
  /// - writing the newly generated key fails, or
  /// - read-back verification fails.
  static Future<List<int>> getOrCreateHiveEncryptionKey({
    FutureOr<bool> Function()? hasExistingData,
  }) async {
    String? stored;
    try {
      stored = await _storage.read(key: _kHiveKey);
    } catch (e) {
      throw SecureStorageException(
        'Failed to read Hive encryption key from secure storage',
        cause: e,
      );
    }

    if (stored != null && stored.isNotEmpty) {
      try {
        final key = base64Decode(stored);
        if (key.length != 32) {
          throw SecureStorageException(
            'Invalid encryption key in secure storage: expected 32 bytes, got ${key.length}',
          );
        }
        return key;
      } on FormatException catch (e) {
        throw SecureStorageException(
          'Corrupted Hive encryption key format in secure storage',
          cause: e,
        );
      }
    }

    // Key is absent in secure storage. A replacement may only be generated
    // when it has been positively established that no existing data needs
    // the old key. Unknown state is treated as "data may exist".
    if (hasExistingData == null) {
      throw const SecureStorageException(
        'Refusing to generate new Hive encryption key: no existing-data check '
        'was supplied, so a fresh installation cannot be established.',
      );
    }
    final bool existing;
    try {
      existing = await hasExistingData();
    } catch (e) {
      throw SecureStorageException(
        'Refusing to generate new Hive encryption key: existing app data '
        'state could not be established.',
        cause: e,
      );
    }
    if (existing) {
      throw const SecureStorageException(
        'Refusing to generate new Hive encryption key: secure storage returned no key '
        'but existing encrypted database files were detected on disk. '
        'Preserving existing data from irreversible overwrite.',
      );
    }

    // Fresh install: generate, persist, and verify a new 32-byte encryption key.
    final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final encoded = base64Encode(key);

    try {
      await _storage.write(key: _kHiveKey, value: encoded);
    } catch (e) {
      throw SecureStorageException(
        'Failed to write new Hive encryption key to secure storage',
        cause: e,
      );
    }

    // Read-back verification
    String? readBack;
    try {
      readBack = await _storage.read(key: _kHiveKey);
    } catch (e) {
      throw SecureStorageException(
        'Failed to read back new Hive encryption key for verification',
        cause: e,
      );
    }

    if (readBack != encoded) {
      throw const SecureStorageException(
        'Verification failed: secure storage did not persist the expected Hive encryption key',
      );
    }

    return key;
  }

  // ── Google OAuth tokens ─────────────────────────────────────────────

  /// Saves Google OAuth token bundle as JSON.
  /// [tokens] must contain: accessToken, refreshToken (optional), expiry (ISO-8601).
  static Future<void> saveGoogleTokens(Map<String, String> tokens) =>
      _storage.write(key: _kGoogleTokens, value: jsonEncode(tokens));

  /// Returns persisted Google tokens, or null if none saved.
  static Future<Map<String, String>?> getGoogleTokens() async {
    final raw = await _storage.read(key: _kGoogleTokens);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteGoogleTokens() =>
      _storage.delete(key: _kGoogleTokens);
}
