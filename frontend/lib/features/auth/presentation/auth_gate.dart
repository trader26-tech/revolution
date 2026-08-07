import 'dart:async';

import 'package:flutter/material.dart';

import '../../shell/app_shell.dart';
import '../data/auth_store.dart';
import '../data/phone_auth_service.dart';
import 'otp_verify_page.dart';
import 'phone_login_page.dart';

/// Decides the first screen based on sign-in state:
///   • logged in  → the app ([AppShell])
///   • logged out → the phone login page → OTP verify → app
///
/// The number screen now hands off to Firebase phone verification: entering a
/// number sends an OTP, the OTP screen confirms it, and only a *verified*
/// number reaches [AuthStore.login]. Logging in remembers the number, so future
/// launches skip straight to the app until sign-out.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.store, this.phoneAuth});

  final AuthStore? store;
  final PhoneAuthService? phoneAuth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthStore _auth = widget.store ?? AuthStore.instance;
  late final PhoneAuthService _phoneAuth =
      widget.phoneAuth ?? PhoneAuthService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        if (_auth.isLoggedIn) return const AppShell();
        return PhoneLoginPage(onSubmit: _startVerification);
      },
    );
  }

  /// Guards so the many ways verification can resolve on a REAL phone never
  /// collide: Firebase may fire codeSent more than once, auto-retrieval can land
  /// while the user is already typing, and a slow tap could double-fire. These
  /// latches make "open the OTP screen" and "finish sign-in" each happen at most
  /// once per attempt.
  bool _otpScreenOpen = false;
  bool _signingIn = false;

  /// Kick off verification for [phoneE164]: send the OTP, then push the OTP
  /// screen. If Android auto-retrieves the code, we sign in straight away.
  Future<void> _startVerification(String phoneE164) async {
    // Fresh attempt — reset the per-attempt latches.
    _otpScreenOpen = false;
    _signingIn = false;
    final completer = _CodeSentGate();

    await _phoneAuth.sendCode(
      phoneE164: phoneE164,
      onCodeSent: (verificationId) {
        completer.complete();
        _openOtpScreen(phoneE164, verificationId);
      },
      onAutoVerified: (credential) async {
        completer.complete();
        // Android read the SMS itself — sign in and dismiss the OTP screen if
        // it's already showing. If this fails, the OTP screen still lets the
        // user type the code by hand.
        await _finishSignIn(() => _phoneAuth.signInWithCredential(credential));
      },
      onFailed: (message) {
        completer.complete();
        if (mounted) _showError(message);
      },
    );

    // Let PhoneLoginPage's spinner keep turning until the SMS is actually on
    // its way (or it failed) — but never forever. If nothing resolves within
    // the window (e.g. the SDK is silently waiting on reCAPTCHA/SMS that will
    // never arrive on this device), stop the spinner and say so, instead of
    // hanging indefinitely.
    try {
      await completer.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      if (mounted && !_otpScreenOpen) {
        _showError(
          'Verification is taking too long. Check your signal and try again.',
        );
      }
    }
  }

  void _openOtpScreen(String phoneE164, String verificationId) {
    if (!mounted || _otpScreenOpen) return; // never push twice
    _otpScreenOpen = true;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => _OtpFlow(
          phoneE164: phoneE164,
          verificationId: verificationId,
          phoneAuth: _phoneAuth,
          onVerified: (signIn) => _finishSignIn(signIn),
        ),
      ),
    )
        .then((_) {
      // The OTP route was popped (verified, or the user backed out) — allow a
      // future attempt to open it again.
      _otpScreenOpen = false;
    });
  }

  /// The single choke point for completing sign-in, shared by the manual-code
  /// and auto-retrieval paths. Runs the given sign-in, persists the session,
  /// and closes the OTP screen — guaranteed to run its effect at most once per
  /// attempt so we never double-login or pop the wrong route.
  Future<void> _finishSignIn(Future<String> Function() signIn) async {
    if (_signingIn || _auth.isLoggedIn) return;
    _signingIn = true;
    try {
      final verifiedNumber = await signIn();
      await _auth.login(verifiedNumber);
      // Dismiss the OTP screen if it's open; the gate rebuilds into AppShell.
      if (mounted && _otpScreenOpen) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        _otpScreenOpen = false;
      }
    } catch (e) {
      _signingIn = false; // let them retry
      rethrow; // surfaced by the caller (OTP screen shows it; auto-path ignores)
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Owns the OTP screen's mutable state (current verificationId, error text) and
/// bridges its callbacks to [PhoneAuthService]. Kept private to the gate so the
/// OTP page itself stays a pure, testable widget.
class _OtpFlow extends StatefulWidget {
  const _OtpFlow({
    required this.phoneE164,
    required this.verificationId,
    required this.phoneAuth,
    required this.onVerified,
  });

  final String phoneE164;
  final String verificationId;
  final PhoneAuthService phoneAuth;

  /// Complete sign-in by running the given sign-in call through the gate's
  /// single choke point. Throws on failure so this screen can show it.
  final Future<void> Function(Future<String> Function() signIn) onVerified;

  @override
  State<_OtpFlow> createState() => _OtpFlowState();
}

class _OtpFlowState extends State<_OtpFlow> {
  late String _verificationId = widget.verificationId;
  String? _error;
  bool _busy = false; // block double-submits of the same code

  Future<void> _confirm(String code) async {
    if (_busy) return;
    _busy = true;
    setState(() => _error = null);
    try {
      await widget.onVerified(
        () => widget.phoneAuth.confirmCode(
          verificationId: _verificationId,
          smsCode: code,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _busy = false;
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    await widget.phoneAuth.sendCode(
      phoneE164: widget.phoneE164,
      onCodeSent: (id) => setState(() => _verificationId = id),
      onAutoVerified: (credential) async {
        try {
          await widget.onVerified(
            () => widget.phoneAuth.signInWithCredential(credential),
          );
        } catch (_) {}
      },
      onFailed: (message) {
        if (mounted) setState(() => _error = message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OtpVerifyPage(
      phoneE164: widget.phoneE164,
      errorText: _error,
      onConfirm: _confirm,
      onResend: _resend,
    );
  }
}

/// A one-shot latch so [_startVerification] can await "the SMS attempt has
/// resolved" (sent, auto-verified, or failed) exactly once, ignoring extra
/// callback fires.
class _CodeSentGate {
  final _c = Completer<void>();
  Future<void> get future => _c.future;
  void complete() {
    if (!_c.isCompleted) _c.complete();
  }
}
