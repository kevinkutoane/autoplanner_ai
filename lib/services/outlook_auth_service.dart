import 'package:flutter/foundation.dart';
import 'package:msal_flutter/msal_flutter.dart';
import 'secure_key_service.dart';

/// Manages Microsoft (Outlook / Azure AD) authentication via MSAL.
///
/// Set [_clientId] to your Azure AD application (client) ID before use.
/// Replace [_authority] with `https://login.microsoftonline.com/<tenantId>`
/// if you target a specific tenant.
class OutlookAuthService {
  // TODO: Replace with your Azure AD application (client) ID.
  static const _clientId = '';
  static const _authority = 'https://login.microsoftonline.com/common';
  static const _scopes = <String>[
    'User.Read',
    'Calendars.ReadWrite',
    'offline_access',
  ];

  PublicClientApplication? _pca;

  /// Notifier updated on sign-in / sign-out.
  final ValueNotifier<String?> connectedAccount = ValueNotifier(null);

  bool get isConnected => connectedAccount.value != null;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Attempts to restore a previous MSAL session from secure storage.
  Future<void> tryRestoreSession() async {
    if (_clientId.isEmpty) return;
    try {
      _pca = await PublicClientApplication.createPublicClientApplication(
        _clientId,
        authority: _authority,
      );
      final stored = await SecureKeyService.getOutlookTokens();
      if (stored != null && stored['account'] != null) {
        connectedAccount.value = stored['account'];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OutlookAuthService.tryRestoreSession: $e');
    }
  }

  // ── Sign-in ───────────────────────────────────────────────────────────────

  /// Launches the interactive MSAL sign-in flow.
  ///
  /// Returns the signed-in account display name on success, or `null` on
  /// cancellation or error.
  Future<String?> signIn() async {
    if (_clientId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'OutlookAuthService: _clientId is not set. '
          'Update _clientId with your Azure AD app (client) ID.',
        );
      }
      return null;
    }
    try {
      _pca ??= await PublicClientApplication.createPublicClientApplication(
        _clientId,
        authority: _authority,
      );
      final token = await _pca!.acquireToken(_scopes);
      return _persistAndNotify(token);
    } on MsalUserCancelledException {
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('OutlookAuthService.signIn: $e');
      return null;
    }
  }

  // ── Token retrieval ───────────────────────────────────────────────────────

  /// Returns a valid access token, refreshing silently if possible.
  Future<String?> getAccessToken() async {
    if (_pca == null) return null;
    try {
      final token = await _pca!.acquireTokenSilent(_scopes);
      return token.isNotEmpty ? token : null;
    } on MsalNoAccountException {
      // No cached account — interactive sign-in required.
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('OutlookAuthService.getAccessToken: $e');
      return null;
    }
  }

  // ── Sign-out ──────────────────────────────────────────────────────────────

  /// Removes the MSAL account and clears persisted tokens.
  Future<void> signOut() async {
    try {
      await _pca?.logout();
    } catch (e) {
      if (kDebugMode) debugPrint('OutlookAuthService.signOut: $e');
    }
    connectedAccount.value = null;
    await SecureKeyService.deleteOutlookTokens();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _persistAndNotify(String token) {
    // Without a separate Graph API call we have no display name available
    // from MSAL directly; use a placeholder that the caller can update.
    const accountLabel = 'Outlook Account';
    connectedAccount.value = accountLabel;
    SecureKeyService.saveOutlookTokens({
      'access_token': token,
      'account': accountLabel,
    });
    return accountLabel;
  }
}
