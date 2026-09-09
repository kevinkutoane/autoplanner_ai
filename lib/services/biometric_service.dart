import 'package:local_auth/local_auth.dart';

/// Wraps [LocalAuthentication] for biometric / device-credential unlock.
class BiometricService {
  final _auth = LocalAuthentication();

  /// Returns true if the device has biometric hardware or a PIN/pattern set.
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns the list of enrolled biometric types.
  Future<List<BiometricType>> enrolledBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Prompts the user to authenticate.
  ///
  /// Falls back to device PIN/pattern/password when biometrics are
  /// unavailable. Returns true on success.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock AutoPlanner AI',
        biometricOnly: false, // allow PIN/pattern as fallback
        persistAcrossBackgrounding:
            true, // keep dialog open if user switches apps
      );
    } catch (_) {
      return false;
    }
  }

  /// Cancels any in-progress authentication prompt.
  Future<void> stopAuthentication() => _auth.stopAuthentication();
}
