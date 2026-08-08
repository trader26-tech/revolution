import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../onboarding/presentation/screens/onboarding_finish_screen.dart'
    show showClaimSheet;
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

  /// While true, we show the "You're in." celebration IN PLACE (not as a pushed
  /// route). When its animation finishes it calls back to persist the session,
  /// which flips [AuthStore.isLoggedIn] → the gate rebuilds into AppShell. This
  /// declarative swap is why the success screen always closes cleanly — there's
  /// no route to pop and no navigator to fight.
  bool _celebrating = false;
  String? _celebrateNumber;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        // The celebration takes over the whole screen for its ~2s beat, then
        // logs in. Shown inline (not a pushed route) so it can never get stuck.
        if (_celebrating && _celebrateNumber != null) {
          return VerifiedSuccessPage(
            phoneE164: _celebrateNumber!,
            onDone: () => _safeLogin(_celebrateNumber!),
          );
        }

        // Verified → the real, fully-interactive app.
        if (_auth.isLoggedIn) {
          return AuthGateController(
            verify: _startVerification,
            child: const AppShell(verified: true),
          );
        }

        // NOT verified → a PREVIEW of Home: the user's added items are rendered
        // exactly as they'll appear, but the whole app is non-interactive (no
        // buttons, no taps, no tab switch). The ONLY live control is the verify
        // prompt covering the bottom. It's a "here's what you've got — verify to
        // use it" teaser. Verifying unlocks the real app above.
        return AuthGateController(
          verify: _startVerification,
          child: _PreviewLock(onVerify: _startVerifyFromBanner),
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

  /// The preview lock's "Verify & continue" was tapped: rise the shared name +
  /// phone claim sheet (the same premium sheet onboarding uses), which collects
  /// the name and number and calls [_startVerification] — the OTP screen and
  /// celebration then layer on top, and the gate rebuilds into the real app.
  void _startVerifyFromBanner() {
    showClaimSheet(context, _startVerification);
  }

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

      // Drop the keyboard before we leave the auth screens — otherwise the
      // phone/OTP field's soft keyboard lingers on top of the celebration and
      // then Home. Unfocus the primary focus explicitly (works even after the
      // route it belonged to is popped).
      FocusManager.instance.primaryFocus?.unfocus();

      // Pop ALL auth routes (the OTP screen + any lingering reCAPTCHA / SMS
      // route the OS left on top) back to the gate route, so the celebration —
      // which we now render INLINE via _celebrating — isn't hidden behind them.
      // Then flip _celebrating so build() shows VerifiedSuccessPage in place of
      // the login page. No pushed success route → nothing can get stuck on top.
      final navigator = Navigator.of(context);
      navigator.popUntil((r) => r.isFirst);
      setState(() {
        _celebrating = true;
        _celebrateNumber = verifiedNumber;
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

/// Wraps the (unverified) app in a NON-INTERACTIVE preview: the user sees their
/// added items rendered exactly as they will in Home, but nothing responds to
/// taps — no add button, no task rows, no tab switch, no settings. The only live
/// control is the "Verify & continue" prompt covering the bottom. Verifying
/// unlocks the real, fully-interactive app.
///
/// Built with [IgnorePointer] over the whole shell (freezes all input) + an
/// [AbsorbPointer]-free prompt on top (so only it receives touches).
class _PreviewLock extends StatelessWidget {
  const _PreviewLock({required this.onVerify});

  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The frozen preview — the real Home with the user's items, but every
        // gesture is swallowed so nothing is clickable.
        const Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: _PreviewChild(),
          ),
        ),
        // The verify prompt — the sole interactive surface, pinned to the bottom
        // with a fade so the preview reads as "locked behind this".
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _VerifyGate(onVerify: onVerify),
        ),
      ],
    );
  }
}

/// The child slot for the preview — a separate widget so the const [IgnorePointer]
/// can hold it while the enclosing lock stays cheap to rebuild.
class _PreviewChild extends StatelessWidget {
  const _PreviewChild();
  @override
  Widget build(BuildContext context) => const AppShell(verified: true);
}

/// The bottom "Verify & continue" gate over the preview — a soft upward fade
/// into a solid panel, with the copy and the single CTA that unlocks the app.
class _VerifyGate extends StatelessWidget {
  const _VerifyGate({required this.onVerify});

  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    // Material provides the text baseline/theme so Text renders normally (no
    // yellow debug underline that appears under raw Text with no Material
    // ancestor).
    return Material(
      type: MaterialType.transparency,
      child: Container(
      // Fade from transparent (so the preview shows through above) into a solid
      // panel that anchors the CTA.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00100B20),
            Color(0xE6100B20),
            AppColors.bg,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This is your space.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verify your number to unlock it — save everything you set up\nand sync it across your devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: onVerify,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Verify & continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
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
  Timer? _sendTimeout;

  @override
  void initState() {
    super.initState();
    // Route the gate's codeSent into our state.
    widget.registerCodeSink((id) {
      if (mounted) {
        _sendTimeout?.cancel();
        setState(() => _verificationId = id);
      }
    });
    _armSendTimeout();
  }

  /// If the code never arrives (misconfigured Firebase — e.g. the release
  /// keystore's SHA isn't registered, so Play Integrity/reCAPTCHA can't verify
  /// the app), the screen would otherwise sit in "sending…" forever with no way
  /// forward. Surface a clear, escapable error instead of a silent dead-end.
  void _armSendTimeout() {
    _sendTimeout?.cancel();
    _sendTimeout = Timer(const Duration(seconds: 30), () {
      if (mounted && _verificationId == null) {
        setState(() => _error =
            "Couldn't send the code. Check your connection and tap Resend — "
            'if it keeps failing, try again shortly.');
      }
    });
  }

  @override
  void dispose() {
    _sendTimeout?.cancel();
    super.dispose();
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

