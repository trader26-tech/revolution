import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase phone (OTP) verification behind a tiny, UI-friendly API.
///
/// The flow Firebase models is two-legged:
///   1. [sendCode] — Firebase texts a 6-digit OTP to the number and hands back
///      a [verificationId] (plus, on some Androids, an auto-retrieved code that
///      signs the user in with no typing at all).
///   2. [confirmCode] — the user's typed code + that verificationId are turned
///      into a credential and exchanged for a signed-in Firebase user.
///
/// On success the caller gets the verified E.164 number back, which it then
/// feeds to [AuthStore.login] — so Firebase does the *proving*, and the app's
/// existing "phone IS the account" model does the rest, unchanged.
class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Start verification for [phoneE164] (e.g. '+919876543210').
  ///
  /// Callbacks (exactly one of the first three fires per attempt):
  ///   • [onCodeSent]   — the SMS is on its way; move the UI to the OTP screen.
  ///                      You get a [verificationId] to pass back to [confirmCode].
  ///   • [onAutoVerified] — Android auto-read the SMS (or instant-validated a
  ///                      test number); the user is effectively verified with no
  ///                      code entry. The credential is ready to sign in.
  ///   • [onFailed]     — bad number, quota, network, etc. Show the message.
  ///
  /// [timeout] is how long to wait for auto-retrieval before falling back to
  /// manual entry.
  Future<void> sendCode({
    required String phoneE164,
    required void Function(String verificationId) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(String message) onFailed,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: timeout,
      verificationCompleted: onAutoVerified,
      verificationFailed: (FirebaseAuthException e) =>
          onFailed(_messageFor(e)),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      // Fired when auto-retrieval times out; we already surfaced the manual
      // OTP screen via codeSent, so nothing more to do here.
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Confirm the 6-digit [smsCode] the user typed against the [verificationId]
  /// from [sendCode]. Returns the verified E.164 number on success.
  Future<String> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _signIn(credential);
  }

  /// Sign in with an already-built credential (the auto-verified path).
  Future<String> signInWithCredential(PhoneAuthCredential credential) =>
      _signIn(credential);

  Future<String> _signIn(PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final phone = result.user?.phoneNumber;
      if (phone == null || phone.isEmpty) {
        throw const _AuthError('Could not read the verified number.');
      }
      return phone;
    } on FirebaseAuthException catch (e) {
      throw _AuthError(_messageFor(e));
    }
  }

  /// Human-readable messages for the errors users actually hit.
  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number looks invalid.';
      case 'invalid-verification-code':
        return 'That code isn’t right. Check and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'The code expired. Tap resend to get a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and try again.';
      case 'quota-exceeded':
        return 'Verification is busy right now — try again shortly.';
      case 'network-request-failed':
        return 'Network error. Check your connection and retry.';
      default:
        return e.message ?? 'Verification failed. Please try again.';
    }
  }
}

/// A plain exception carrying a user-facing message (so the UI can `catch` and
/// show `e.message` without depending on Firebase types).
class _AuthError implements Exception {
  const _AuthError(this.message);
  final String message;
  @override
  String toString() => message;
}
