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
  });

  /// The number we texted, shown so the user can confirm it's theirs.
  final String phoneE164;

  /// Called with the typed 6-digit code. Should throw/return; the parent flips
  /// [errorText] on failure and navigates away on success.
  final Future<void> Function(String code) onConfirm;

  /// Re-send the OTP. Restarts the countdown.
  final Future<void> Function() onResend;

  /// A message from the parent (wrong code, expired, …) shown under the boxes.
  final String? errorText;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  static const _len = 6;
  static const _resendSeconds = 30;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _submitting = false;

  String get _code => _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
  bool get _complete => _code.length == _len;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
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
    if (mounted) _focus.requestFocus();
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
          onTap: () => _focus.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Padding(
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
                        const TextSpan(text: 'We texted a 6-digit code to '),
                        TextSpan(
                          text: widget.phoneE164,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _CodeBoxes(
                    length: _len,
                    code: _code,
                    focused: _focus.hasFocus,
                    error: widget.errorText != null,
                    onTap: () => _focus.requestFocus(),
                  ),
                  // The real (invisible) input driving the boxes.
                  Offstage(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_len),
                      ],
                      onSubmitted: (_) => _submit(),
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
                  const Spacer(),
                  if (_submitting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
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
  });

  final int length;
  final String code;
  final bool focused;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
