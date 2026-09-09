import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around [FlutterSecureStorage] for secrets that must never
/// live in plain-text on disk (Gemini API key, Hive encryption key,
/// Google OAuth tokens).
class SecureKeyService {
  static const _storage = FlutterSecureStorage();

  static const _kGeminiKey = 'gemini_api_key';
  static const _kHiveKey = 'hive_encryption_key';
  static const _kGoogleTokens = 'google_oauth_tokens';

  // ── Gemini API key ──────────────────────────────────────────────────

  static Future<String?> getGeminiApiKey() => _storage.read(key: _kGeminiKey);

  static Future<void> saveGeminiApiKey(String key) =>
      _storage.write(key: _kGeminiKey, value: key);

  static Future<void> deleteGeminiApiKey() => _storage.delete(key: _kGeminiKey);

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
