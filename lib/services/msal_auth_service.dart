import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:msal_flutter/msal_flutter.dart';
import 'secure_key_service.dart';

/// Manages Microsoft (Outlook / Office 365) sign-in via MSAL (msal_flutter v2).
///
/// Scopes requested:
///   • Calendars.ReadWrite   — full calendar access
///   • offline_access        — refresh tokens
///
/// msal_flutter v2 returns access tokens directly; the account UPN is not
/// exposed by the plugin. [connectedEmail] uses 'microsoft_account' as a
/// sentinel to signal the connected state.
class MsalAuthService {
  final String _clientId;
  static const _authority = 'https://login.microsoftonline.com/common';
  static const _scopes = ['Calendars.ReadWrite', 'offline_access'];

  MsalAuthService({required String clientId}) : _clientId = clientId;

  PublicClientApplication? _pca;

  /// Non-null when a Microsoft account is connected.
  final ValueNotifier<String?> connectedEmail = ValueNotifier(null);

  bool get isConnected => connectedEmail.value != null;

  Future<PublicClientApplication> _getPca() async {
    return _pca ??= await PublicClientApplication.createPublicClientApplication(
      _clientId,
      authority: _authority,
    );
  }

  /// Restores connectivity by attempting a silent token refresh on app start.
  Future<void> tryRestoreSession() async {
    try {
      final stored = await SecureKeyService.getMsalTokens();
      if (stored == null) return;
      final pca = await _getPca();
      final token = await pca.acquireTokenSilent(_scopes);
      if (token.isNotEmpty) {
        connectedEmail.value = stored['label'] ?? 'microsoft_account';
        await _persist(token, stored['label']);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MsalAuth: silent restore failed — $e');
    }
  }

  /// Launches the interactive Microsoft sign-in browser flow.
  /// Returns 'microsoft_account' on success, or null if cancelled.
  Future<String?> signIn() async {
    try {
      final pca = await _getPca();
      final token = await pca.acquireToken(_scopes);
      if (token.isEmpty) return null;
      const label = 'microsoft_account';
      connectedEmail.value = label;
      await _persist(token, label);
      return label;
    } on MsalUserCancelledException {
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('MsalAuth: signIn failed — $e');
      return null;
    }
  }

  /// Signs out and clears all persisted tokens.
  Future<void> signOut() async {
    try {
      final pca = await _getPca();
      await pca.logout();
    } catch (_) {}
    connectedEmail.value = null;
    await SecureKeyService.deleteMsalTokens();
  }

  /// Returns a valid Bearer access token, refreshing silently if near expiry.
  Future<String?> getAccessToken() async {
    try {
      final stored = await SecureKeyService.getMsalTokens();
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
      final pca = await _getPca();
      final token = await pca.acquireTokenSilent(_scopes);
      if (token.isEmpty) return null;
      await _persist(token, stored?['label']);
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('MsalAuth: getAccessToken failed — $e');
      return null;
    }
  }

  Future<void> _persist(String token, String? label) =>
      SecureKeyService.saveMsalTokens({
        'accessToken': token,
        'label': label ?? 'microsoft_account',
        'expiry': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
}
