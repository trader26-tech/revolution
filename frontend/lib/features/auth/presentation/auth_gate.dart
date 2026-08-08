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
  const AuthGate({super.key, this.store, this.phoneAuth, this.child});

  final AuthStore? store;
  final PhoneAuthService? phoneAuth;

  /// The logged-OUT screen to show. Defaults to the plain [PhoneLoginPage]. The
  /// onboarding finish screen passes its own richer screen here (the completed
  /// summary + a name/number sheet) but reuses this gate's verification flow via
  /// [AuthGateController], so there's ONE OTP/sign-in pipeline for both entries.
  final Widget? child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthStore _auth = widget.store ?? AuthStore.instance;
  late final PhoneAuthService _phoneAuth =
      widget.phoneAuth ?? PhoneAuthService();

  /// The display name to attach to the session, set by whoever kicks off
  /// verification (the onboarding finish sheet). Read at [_safeLogin] time so it
  /// lands on the verified account. Null on the plain login path.
  String? _pendingName;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        if (_auth.isLoggedIn) return const AppShell();
        // Expose the verification trigger to the logged-out subtree, so a custom
        // [child] (the onboarding finish sheet) can start OTP with a name via
        // AuthGateController.of(context).verify(...).
        return AuthGateController(
          verify: _startVerification,
          child: widget.child ??
              PhoneLoginPage(onSubmit: (e164) => _startVerification(e164)),
        );
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
  Future<void> _startVerification(String phoneE164, {String? name}) async {
    // Fresh attempt — reset the per-attempt latches.
    _otpScreenOpen = false;
    _signingIn = false;
    _onCodeArrived = null;
    _pendingName = name;

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
      if (!mounted) {
        await _safeLogin(verifiedNumber); // no UI to animate; just persist
        return;
      }
      _otpScreenOpen = false;
      _onCodeArrived = null;

      // Tear down the ENTIRE auth route stack before showing success — the OTP
      // screen AND any lingering reCAPTCHA / SMS-consent route the OS left on
      // top. `pushReplacement` alone only swaps the topmost route, which is why
      // the captcha screen could stay stuck behind the app. Do it after the
      // current frame so we never navigate mid-callback (a source of the
      // "internal error" on the way back).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _safeLogin(verifiedNumber);
          return;
        }
        final navigator = Navigator.of(context);
        // Drop everything back to the first (gate) route, then put the
        // celebration in its place — a clean stack with nothing lingering.
        navigator.popUntil((r) => r.isFirst);
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerifiedSuccessPage(
              phoneE164: verifiedNumber,
              onDone: () => _safeLogin(verifiedNumber),
            ),
          ),
        );
      });
    } catch (e) {
      _signingIn = false; // let them retry
      rethrow; // surfaced by the caller (OTP screen shows it; auto-path ignores)
    }
  }

  /// Persist the session, swallowing any post-verification failure. The user is
  /// already verified by Firebase at this point, so a flaky prefs/network write
  /// must NOT throw an unhandled async error (which surfaced as an "internal
  /// error" when the app was reopened). Login itself is best-effort internally;
  /// this is a belt-and-braces guard around the whole call.
  Future<void> _safeLogin(String verifiedNumber) async {
    try {
      await _auth.login(verifiedNumber, name: _pendingName);
    } catch (_) {
      // Verified but couldn't fully persist — the gate still flips to
      // logged-in via AuthStore, and prefs sync will retry later. Never crash.
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Hands the logged-out subtree a way to start phone verification through the
/// gate's single pipeline. The onboarding finish screen (mounted as the gate's
/// [AuthGate.child]) reads this to fire the OTP flow with the collected name,
/// so both entries — plain login and onboarding — share one OTP/sign-in path.
class AuthGateController extends InheritedWidget {
  const AuthGateController({
    super.key,
    required this.verify,
    required super.child,
  });

  /// Kick off verification for [phoneE164], attaching an optional display
  /// [name] to the session once the number is verified.
  final Future<void> Function(String phoneE164, {String? name}) verify;

  static AuthGateController of(BuildContext context) {
    final c =
        context.dependOnInheritedWidgetOfExactType<AuthGateController>();
    assert(c != null, 'No AuthGateController above this widget');
    return c!;
  }

  @override
  bool updateShouldNotify(AuthGateController old) => verify != old.verify;
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

