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

  /// Kick off verification for [phoneE164]: send the OTP, then push the OTP
  /// screen. If Android auto-retrieves the code, we sign in straight away.
  Future<void> _startVerification(String phoneE164) async {
    final completer = _CodeSentGate();

    await _phoneAuth.sendCode(
      phoneE164: phoneE164,
      onCodeSent: (verificationId) {
        completer.complete();
        _openOtpScreen(phoneE164, verificationId);
      },
      onAutoVerified: (credential) async {
        completer.complete();
        try {
          final verified =
              await _phoneAuth.signInWithCredential(credential);
          await _auth.login(verified);
        } catch (_) {
          // If auto sign-in fails, the OTP screen (if open) still lets them
          // type the code manually.
        }
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
      await completer.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (mounted) {
        _showError(
          'Verification is taking too long. On an emulator, use a registered '
          'test number; on a real phone, check your signal and try again.',
        );
      }
    }
  }

  void _openOtpScreen(String phoneE164, String verificationId) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => _OtpFlow(
          phoneE164: phoneE164,
          verificationId: verificationId,
          phoneAuth: _phoneAuth,
          onVerified: (verifiedNumber) async {
            await _auth.login(verifiedNumber);
            // AuthStore now reports logged-in; pop back so the gate rebuilds
            // into AppShell.
            if (navigator.canPop()) navigator.pop();
          },
        ),
      ),
    );
  }

  void _showError(String message) {
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
  final Future<void> Function(String verifiedNumber) onVerified;

  @override
  State<_OtpFlow> createState() => _OtpFlowState();
}

class _OtpFlowState extends State<_OtpFlow> {
  late String _verificationId = widget.verificationId;
  String? _error;

  Future<void> _confirm(String code) async {
    setState(() => _error = null);
    try {
      final verified = await widget.phoneAuth.confirmCode(
        verificationId: _verificationId,
        smsCode: code,
      );
      await widget.onVerified(verified);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    await widget.phoneAuth.sendCode(
      phoneE164: widget.phoneE164,
      onCodeSent: (id) => setState(() => _verificationId = id),
      onAutoVerified: (credential) async {
        try {
          final verified =
              await widget.phoneAuth.signInWithCredential(credential);
          await widget.onVerified(verified);
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
