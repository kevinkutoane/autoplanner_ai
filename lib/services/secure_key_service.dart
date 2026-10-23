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
      aOptions: AndroidOptions(resetOnError: true),
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

  // ── Gemini API key ──────────────────────────────────────────────────

  static Future<String?> getGeminiApiKey() async {
    try {
      return await _storage.read(key: _kGeminiKey);
    } catch (_) {
      return null;
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
  /// Generates and stores one on first call.
  static Future<List<int>> getOrCreateHiveEncryptionKey() async {
    final stored = await _storage.read(key: _kHiveKey);
    if (stored != null) return base64Decode(stored);

    final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    await _storage.write(key: _kHiveKey, value: base64Encode(key));
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
