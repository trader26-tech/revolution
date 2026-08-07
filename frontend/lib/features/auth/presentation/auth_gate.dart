import 'dart:async';

import 'package:flutter/material.dart';

import '../../shell/app_shell.dart';
import '../data/auth_store.dart';
import '../data/phone_auth_service.dart';
import 'otp_verify_page.dart';
import 'phone_login_page.dart';
import 'verified_success_page.dart';

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

  /// Bridges the code arriving to whichever OTP screen is currently mounted.
  /// Set the instant we open the OTP screen; the screen registers its handler so
  /// that when Firebase's [onCodeSent] lands (a beat later, after Play
  /// Integrity/reCAPTCHA), the screen flips from "sending…" to ready.
  void Function(String verificationId)? _onCodeArrived;

  /// Kick off verification for [phoneE164]. We open the OTP screen IMMEDIATELY
  /// (in a "sending…" state) so the tap feels instant, then let Firebase resolve
  /// in the background — its callbacks flow to the already-open screen. If
  /// Android auto-retrieves the SMS, we sign in without any typing.
  Future<void> _startVerification(String phoneE164) async {
    // Fresh attempt — reset the per-attempt latches.
    _otpScreenOpen = false;
    _signingIn = false;
    _onCodeArrived = null;

    // Show the OTP screen right away — no waiting on a spinner on the number
    // screen. It starts in "sending…" mode until the real code id arrives.
    _openOtpScreen(phoneE164);

    _phoneAuth.sendCode(
      phoneE164: phoneE164,
      onCodeSent: (verificationId) => _onCodeArrived?.call(verificationId),
      onAutoVerified: (credential) =>
          _finishSignIn(() => _phoneAuth.signInWithCredential(credential)),
      onFailed: (message) {
        // Verification couldn't even start — back out of the OTP screen and
        // tell the user on the number screen.
        if (mounted && _otpScreenOpen) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          _otpScreenOpen = false;
        }
        if (mounted) _showError(message);
      },
    );
  }

  void _openOtpScreen(String phoneE164) {
    if (!mounted || _otpScreenOpen) return; // never push twice
    _otpScreenOpen = true;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => _OtpFlow(
          phoneE164: phoneE164,
          phoneAuth: _phoneAuth,
          onVerified: (signIn) => _finishSignIn(signIn),
          // Hand the screen a way to receive the verificationId once it lands.
          registerCodeSink: (sink) => _onCodeArrived = sink,
        ),
      ),
    )
        .then((_) {
      // The OTP route was popped (verified, or the user backed out) — allow a
      // future attempt to open it again.
      _otpScreenOpen = false;
      _onCodeArrived = null;
    });
  }

  /// The single choke point for completing sign-in, shared by the manual-code
  /// and auto-retrieval paths. Runs the given sign-in, plays the celebration,
  /// then persists the session — guaranteed to run its effect at most once per
  /// attempt so we never double-login or pop the wrong route.
  Future<void> _finishSignIn(Future<String> Function() signIn) async {
    if (_signingIn || _auth.isLoggedIn) return;
    _signingIn = true;
    try {
      final verifiedNumber = await signIn();
      // Swap whatever's on top (OTP screen, or nothing on the auto path) for the
      // celebration. It calls back when its animation settles, and only THEN do
      // we flip AuthStore to logged-in — so the app appears exactly as the
      // "You're in." beat finishes, with no flash of the login screen between.
      if (!mounted) {
        await _auth.login(verifiedNumber); // no UI to animate; just persist
        return;
      }
      _otpScreenOpen = false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifiedSuccessPage(
            phoneE164: verifiedNumber,
            onDone: () => _auth.login(verifiedNumber),
          ),
        ),
      );
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
    required this.phoneAuth,
    required this.onVerified,
    required this.registerCodeSink,
  });

  final String phoneE164;
  final PhoneAuthService phoneAuth;

  /// Complete sign-in by running the given sign-in call through the gate's
  /// single choke point. Throws on failure so this screen can show it.
  final Future<void> Function(Future<String> Function() signIn) onVerified;

  /// Give the gate a callback to push the verificationId here once Firebase's
  /// codeSent lands — this is how the screen leaves "sending…" and becomes ready.
  final void Function(void Function(String verificationId) sink)
      registerCodeSink;

  @override
  State<_OtpFlow> createState() => _OtpFlowState();
}

class _OtpFlowState extends State<_OtpFlow> {
  /// Null until Firebase's codeSent arrives — while null, the screen shows a
  /// "sending the code…" state so nothing ever feels frozen.
  String? _verificationId;
  String? _error;
  bool _busy = false; // block double-submits of the same code

  @override
  void initState() {
    super.initState();
    // Route the gate's codeSent into our state.
    widget.registerCodeSink((id) {
      if (mounted) setState(() => _verificationId = id);
    });
  }

  Future<void> _confirm(String code) async {
    final id = _verificationId;
    if (_busy || id == null) return; // not ready yet — ignore
    _busy = true;
    setState(() => _error = null);
    try {
      await widget.onVerified(
        () => widget.phoneAuth.confirmCode(verificationId: id, smsCode: code),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _busy = false;
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _verificationId = null; // back to "sending…" until the new code lands
    });
    await widget.phoneAuth.sendCode(
      phoneE164: widget.phoneE164,
      onCodeSent: (id) {
        if (mounted) setState(() => _verificationId = id);
      },
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
      sending: _verificationId == null,
      onConfirm: _confirm,
      onResend: _resend,
    );
  }
}

