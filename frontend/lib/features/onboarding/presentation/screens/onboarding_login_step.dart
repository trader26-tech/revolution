import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/country_code.dart';

/// The final onboarding step: a smooth, low-friction phone/WhatsApp sign-in that
/// claims the reminders picked so far to the user's account.
///
/// Kept deliberately calm — one big number field, a reassuring line about why,
/// and a single primary action. [count] lets us reassure the user their work is
/// safe ("Save your 6 reminders"). [onDone] fires when sign-in succeeds (wired
/// to the real OTP flow later).
class OnboardingLoginStep extends StatefulWidget {
  const OnboardingLoginStep({
    super.key,
    required this.count,
    required this.onDone,
  });

  final int count;
  final VoidCallback onDone;

  @override
  State<OnboardingLoginStep> createState() => _OnboardingLoginStepState();
}

class _OnboardingLoginStepState extends State<OnboardingLoginStep> {
  final _controller = TextEditingController();
  CountryCode _country = kCountryCodes.first;
  String _digits = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _digits.length >= (_country.maxLen - 1).clamp(6, 15);

  void _onChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = digits.length > _country.maxLen
        ? digits.substring(0, _country.maxLen)
        : digits;
    final formatted = _country.format(clipped);
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() => _digits = clipped);
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in kCountryCodes)
              ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                title: Text(c.name),
                trailing: Text(c.dial,
                    style: const TextStyle(color: AppColors.inkSoft)),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _country = picked);
      _onChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: Color(0xFF25D366), size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Almost there!',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.count > 0
                      ? 'Add your number and we\'ll save your ${widget.count} reminders and ping you on WhatsApp before each one.'
                      : 'Add your number and we\'ll ping you on WhatsApp before every bill.',
                  style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 28),
                // Number field.
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _pickCountry,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
                          child: Row(
                            children: [
                              Text(_country.flag,
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Text(
                                _country.dial,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded,
                                  color: AppColors.inkFaint),
                            ],
                          ),
                        ),
                      ),
                      Container(
                          width: 1, height: 28, color: AppColors.cardBorder),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: _onChanged,
                          keyboardType: TextInputType.phone,
                          autofocus: false,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.ink,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '00000 00000',
                            hintStyle: TextStyle(
                              color: AppColors.inkFaint,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 15, color: AppColors.inkFaint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Private and secure. We never share your number.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _valid
                  ? () {
                      HapticFeedback.mediumImpact();
                      widget.onDone();
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                disabledBackgroundColor: AppColors.cardBorder,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                widget.count > 0 ? 'Save my reminders' : 'Continue on WhatsApp',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
