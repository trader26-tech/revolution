import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper over local_auth for the App Lock. Prompts the OS's native
/// biometric dialog (fingerprint / face) and, when no biometric is enrolled,
/// falls back to the device credential (PIN / pattern / passcode) — so every
/// device can unlock.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// True if the device can authenticate by biometric OR device credential.
  /// Either is acceptable for the lock (biometricOnly: false below), so we gate
  /// on device support, not only enrolled biometrics.
  Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Show the native unlock prompt. Returns true only on a successful auth.
  /// [reason] is the OS dialog subtitle. `biometricOnly: false` lets the OS fall
  /// back to the device PIN/pattern/passcode when no biometric is enrolled (or a
  /// biometric attempt fails), matching the "fall back to device PIN" choice.
  Future<bool> authenticate({String reason = 'Unlock to continue'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true, // survive the app being briefly backgrounded
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      // No hardware, not enrolled, locked out, or the user cancelled — treat as
      // "not authenticated". The gate stays locked and offers a retry.
      return false;
    }
  }
}
