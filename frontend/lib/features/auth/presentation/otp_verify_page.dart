import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/starfield.dart';

/// The OTP entry screen — second leg of phone login, shown right after the SMS
/// is sent. Six boxed digits, a live resend countdown, and the same starlit,
/// premium feel as the number screen.
///
/// It's deliberately dumb about Firebase: the parent owns the verificationId
/// and the actual verify calls. This page only collects a 6-digit code and
/// reports it up via [onConfirm], surfaces [errorText] the parent hands back,
/// and asks to resend via [onResend].
class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({
    super.key,
    required this.phoneE164,
    required this.onConfirm,
    required this.onResend,
    this.errorText,
    this.sending = false,
    this.onSkip,
  });

  /// DEV escape hatch: skip verification and go straight to Home. When null the
  /// affordance is hidden. Wired while login is being sorted out so the OTP
  /// screen is never a dead-end (e.g. verification failing on a simulator).
  final VoidCallback? onSkip;

  /// The number we texted, shown so the user can confirm it's theirs.
  final String phoneE164;

  /// Called with the typed 6-digit code. Should throw/return; the parent flips
  /// [errorText] on failure and navigates away on success.
  final Future<void> Function(String code) onConfirm;

  /// Re-send the OTP. Restarts the countdown.
  final Future<void> Function() onResend;

  /// A message from the parent (wrong code, expired, …) shown under the boxes.
  final String? errorText;

  /// True while the code is still on its way (Firebase deciding Play
  /// Integrity/reCAPTCHA, SMS in flight). The boxes show a gentle "sending the
  /// code…" state and input waits, so the screen never feels frozen.
  final bool sending;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage>
    with WidgetsBindingObserver {
  static const _len = 6;
  static const _resendSeconds = 30;

  final _controller = TextEditingController();
  final _focus = FocusNode(); // drives the hidden field behind the boxes
  final _fallbackFocus = FocusNode(); // the visible fallback text field
  Timer? _timer;
  Timer? _kbCheck;
  int _secondsLeft = _resendSeconds;
  bool _submitting = false;

  /// Shown only when the keyboard refused to appear for the box UI — then we
  /// reveal a real, visible text field so the code can always be typed by hand
  /// (e.g. the OTP arrived on another device, so nothing auto-fills).
  bool _showFallbackField = false;

  String get _code => _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
  bool get _complete => _code.length == _len;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _startCountdown();
    // The reCAPTCHA / SMS-consent step leaves and re-enters this screen, and
    // the OS drops the keyboard while we're away. Watch the app lifecycle so we
    // can bring the keyboard back the moment we return.
    WidgetsBinding.instance.addObserver(this);
    _focusSoon();
  }

  @override
  void didUpdateWidget(covariant OtpVerifyPage old) {
    super.didUpdateWidget(old);
    // Once the code has actually been sent (sending → false), pop the keyboard
    // so the user can type immediately without tapping.
    if (old.sending && !widget.sending) _focusSoon();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground (back from the reCAPTCHA webview / SMS
    // screen) → re-open the keyboard so the field is ready to type.
    if (state == AppLifecycleState.resumed && !widget.sending) _focusSoon();
  }

  /// Request focus after the current frame, so the keyboard reliably rises even
  /// right after a route/lifecycle transition (a bare requestFocus mid-build is
  /// often dropped). Then verify the keyboard actually appeared — if it didn't,
  /// fall back to the visible text field.
  void _focusSoon() {
    if (_showFallbackField) return; // already on the visible field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.sending) return;
      _focus.requestFocus();
      _scheduleKeyboardCheck();
    });
  }

  /// Give the keyboard a moment to rise; if it hasn't (no bottom inset), the box
  /// UI's hidden field failed — reveal the visible fallback field instead.
  void _scheduleKeyboardCheck() {
    _kbCheck?.cancel();
    _kbCheck = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || widget.sending || _showFallbackField) return;
      final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;
      if (!keyboardUp) _revealFallbackField();
    });
  }

  /// Manual "tap to enter" → try the keyboard once more, then fall back.
  void _summonKeyboard() {
    _focus.requestFocus();
    _scheduleKeyboardCheck();
  }

  void _revealFallbackField() {
    setState(() => _showFallbackField = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fallbackFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _kbCheck?.cancel();
    _controller.dispose();
    _focus.dispose();
    _fallbackFocus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    // Auto-submit the instant all six digits are in — no button hunt.
    if (_complete && !_submitting) _submit();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _submit() async {
    if (!_complete || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.onConfirm(_code);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    _controller.clear();
    await widget.onResend();
    _startCountdown();
    if (!mounted) return;
    // Fresh attempt — try the box UI + keyboard again from scratch.
    if (_showFallbackField) {
      _fallbackFocus.requestFocus();
    } else {
      _focusSoon();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.ink),
      ),
      extendBodyBehindAppBar: true,
      body: Starfield(
        intensity: 0.7,
        child: GestureDetector(
          // Tap anywhere to bring the keyboard back — to the visible fallback
          // field if it's showing, otherwise the boxes' hidden field.
          onTap: () =>
              (_showFallbackField ? _fallbackFocus : _focus).requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            // Scrollable so nothing is trapped behind the keyboard on short
            // screens — the Verify button always stays reachable.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  const Text(
                    'Enter the code',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: widget.sending
                              ? 'Sending a 6-digit code to '
                              : 'We texted a 6-digit code to ',
                        ),
                        TextSpan(
                          text: widget.phoneE164,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: widget.sending ? '…' : '.'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Primary: the six code boxes (the version that worked), driven
                  // by the hidden field. Tapping them summons the keyboard.
                  Stack(
                    children: [
                      SizedBox(
                        height: 1,
                        width: 1,
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            autofocus: !_showFallbackField,
                            showCursor: false,
                            keyboardType: TextInputType.number,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(_len),
                            ],
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                      ),
                      _CodeBoxes(
                        length: _len,
                        code: _code,
                        focused: _focus.hasFocus && !widget.sending,
                        error: widget.errorText != null,
                        sending: widget.sending,
                        onTap: () => _focus.requestFocus(),
                      ),
                    ],
                  ),
                  // Fallback: if the keyboard never came up (e.g. code arrived on
                  // ANOTHER device and there's nothing to auto-fill), show a real,
                  // visible text field right here so the code can always be typed.
                  if (_showFallbackField) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      focusNode: _fallbackFocus,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_len),
                      ],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter the 6-digit code',
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          letterSpacing: 0,
                          color: AppColors.inkFaint,
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.accent, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Tap affordance — brings the keypad back, and if that still
                  // doesn't work, reveals the fallback field above.
                  if (!widget.sending && !_focus.hasFocus && !_showFallbackField)
                    GestureDetector(
                      onTap: _summonKeyboard,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.keyboard_rounded,
                              size: 16, color: AppColors.accent),
                          SizedBox(width: 6),
                          Text(
                            'Tap to enter the code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      widget.errorText!,
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _ResendRow(
                    secondsLeft: _secondsLeft,
                    onResend: _resend,
                  ),
                  const SizedBox(height: 28),
                  // An explicit, always-visible Verify button. The code still
                  // auto-submits when six digits land, but this guarantees a
                  // clear way forward — never a screen with no button. Disabled
                  // (but visible) until the code is complete and actually
                  // verifiable (verificationId has arrived).
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: (_complete && !widget.sending && !_submitting)
                          ? _submit
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.accent.withValues(alpha: 0.25),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.sending ? 'Sending…' : 'Verify',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // DEV escape: never be trapped on this screen (e.g. when
                  // verification can't complete on a simulator).
                  if (widget.onSkip != null)
                    Center(
                      child: TextButton(
                        onPressed: widget.onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.inkSoft,
                        ),
                        child: const Text(
                          'Skip for now → Home',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The six digit cells. The active cell (next empty slot) glows with the accent.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.length,
    required this.code,
    required this.focused,
    required this.error,
    required this.onTap,
    this.sending = false,
  });

  final int length;
  final String code;
  final bool focused;
  final bool error;
  final VoidCallback onTap;

  /// True while the SMS is still on its way — the boxes soften so the screen
  /// reads as "waiting for the code" rather than idle.
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: sending ? 0.5 : 1.0,
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(length, (i) {
          final filled = i < code.length;
          final active = focused && i == code.length;
          final borderColor = error
              ? const Color(0xFFFF6B6B)
              : active
                  ? AppColors.accent
                  : AppColors.cardBorder;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: active || error ? 1.6 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              filled ? code[i] : '',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          );
        }),
        ),
      ),
    );
  }
}

/// "Resend code" — a live countdown, then a tappable accent link.
class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsLeft, required this.onResend});

  final int secondsLeft;
  final Future<void> Function() onResend;

  @override
  Widget build(BuildContext context) {
    if (secondsLeft > 0) {
      return Text(
        'Resend code in ${secondsLeft}s',
        style: const TextStyle(
          color: AppColors.inkFaint,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return GestureDetector(
      onTap: onResend,
      child: const Text(
        'Resend code',
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
