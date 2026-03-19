import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'secure_key_service.dart';

/// Manages Google Sign-In and persists OAuth tokens to the secure keychain.
///
/// Scopes requested:
///   • email / profile — basic identity
///   • Google Calendar — full read+write calendar access
class GoogleAuthService {
  static const _calendarScope = 'https://www.googleapis.com/auth/calendar';

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', _calendarScope],
  );

  /// Emits the connected account email (or null when signed out).
  final ValueNotifier<String?> connectedEmail = ValueNotifier(null);

  /// True when an access token is available and not expired.
  bool get isConnected => connectedEmail.value != null;

  /// Attempts a silent sign-in from cached credentials on app start.
  Future<void> tryRestoreSession() async {
    try {
      final stored = await SecureKeyService.getGoogleTokens();
      if (stored == null) return;
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        connectedEmail.value = account.email;
        await _persistTokens(account);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleAuth: silent restore failed — $e');
    }
  }

  /// Launches the Google sign-in flow. Returns the signed-in email or null
  /// if the user cancels.
  Future<String?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      connectedEmail.value = account.email;
      await _persistTokens(account);
      return account.email;
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleAuth: signIn failed — $e');
      rethrow;
    }
  }

  /// Signs out and clears all persisted tokens.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleAuth: signOut failed — $e');
    }
    connectedEmail.value = null;
    await SecureKeyService.deleteGoogleTokens();
  }

  /// Returns a valid Bearer access token, using cached token if not expired.
  Future<String?> getAccessToken() async {
    try {
      // Check cached token expiry before triggering a network call.
      final stored = await SecureKeyService.getGoogleTokens();
      if (stored != null) {
        final expiry = DateTime.tryParse(stored['expiry'] ?? '');
        final token = stored['accessToken'];
        if (expiry != null &&
            token != null &&
            token.isNotEmpty &&
            expiry.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
          return token;
        }
      }
      // Token missing or near expiry — refresh silently.
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token != null) {
        await _persistTokens(account);
      }
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleAuth: getAccessToken failed — $e');
      return null;
    }
  }

  Future<void> _persistTokens(GoogleSignInAccount account) async {
    try {
      final auth = await account.authentication;
      final expiry = DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String();
      await SecureKeyService.saveGoogleTokens({
        'accessToken': auth.accessToken ?? '',
        'idToken': auth.idToken ?? '',
        'email': account.email,
        'displayName': account.displayName ?? '',
        'expiry': expiry,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleAuth: _persistTokens failed — $e');
    }
  }
}
