import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/country_code.dart';
import 'widgets/app_logo.dart';
import 'widgets/country_flag.dart';

/// The phone-number login page — the app's first impression.
///
/// Minimal and premium: the logo, one light line, and a large phone field with
/// country-aware digit grouping (India → "98765 43210"). On Continue it hands
/// the full E.164 number back via [onSubmit]. No verification yet.
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key, required this.onSubmit});

  /// Called with the full E.164 number (e.g. '+919876543210').
  final Future<void> Function(String phoneE164) onSubmit;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  CountryCode _country = kCountryCodes.first; // India
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _digits => _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
  bool get _valid => _digits.length >= 6 && _digits.length <= _country.maxLen;

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final e164 = '${_country.dial}$_digits';
    try {
      await widget.onSubmit(e164);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CountrySheet(current: _country),
    );
    if (picked != null) {
      setState(() => _country = picked);
      // Trim to the new country's max length + re-space.
      final trimmed = _digits.length > _country.maxLen
          ? _digits.substring(0, _country.maxLen)
          : _digits;
      _controller.value = _formatted(trimmed);
    }
  }

  /// Re-space the field to the country's grouping, keeping the caret at the end.
  TextEditingValue _formatted(String digits) {
    final text = _country.format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Ambient background — layered soft colour blobs, not a flat sheet.
            const Positioned.fill(child: _AmbientBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            const AppLogo(size: 72),
                            const SizedBox(height: 40),
                            // Confident, left-aligned headline.
                            const Text(
                              'Enter your\nphone number',
                              style: TextStyle(
                                fontSize: 32,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'We’ll use this to securely save and sync your '
                              'reminders across your devices.',
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.45,
                                color: AppColors.inkSoft,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _PhoneField(
                              country: _country,
                              controller: _controller,
                              focusNode: _focus,
                              onPickCountry: _pickCountry,
                              onSubmit: _submit,
                            ),
                            const SizedBox(height: 16),
                            const _TrustRow(),
                            const SizedBox(height: 36),
                            _ContinueButton(
                              enabled: _valid && !_submitting,
                              loading: _submitting,
                              onTap: _submit,
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'By continuing you agree to our Terms & Privacy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.inkFaint),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft, out-of-focus colour blobs behind everything — a warm, premium ambient
/// backdrop instead of a flat gradient.
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.bg),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: _Blob(220, const Color(0xFF3B82F6), 0.18),
          ),
          Positioned(
            top: 40,
            right: -90,
            child: _Blob(240, const Color(0xFF8B5CF6), 0.14),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: _Blob(200, const Color(0xFF22D3EE), 0.10),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color, this.opacity);
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// A small, honest trust cue under the field.
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.lock_rounded, size: 14, color: AppColors.accent),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Private & encrypted. We never share your number.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The phone input: a card with the country selector and the big number field.
/// Lifts with an accent glow when focused, so it feels alive and premium.
class _PhoneField extends StatefulWidget {
  const _PhoneField({
    required this.country,
    required this.controller,
    required this.focusNode,
    required this.onPickCountry,
    required this.onSubmit,
  });

  final CountryCode country;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPickCountry;
  final VoidCallback onSubmit;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _focused = widget.focusNode.hasFocus);

  /// The country's hint, using X's (e.g. "XXXXX XXXXX"), not zeros.
  String get _hint => widget.country.format('X' * widget.country.maxLen);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focused ? AppColors.accent : AppColors.cardBorder,
          width: _focused ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? AppColors.accent.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: _focused ? 22 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Country selector.
          InkWell(
            onTap: widget.onPickCountry,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountryFlag(iso: widget.country.iso, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.country.dial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.expand_more_rounded,
                      size: 20, color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 28, color: AppColors.cardBorder),
          // Number field — big, grouped, confident digits.
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              cursorColor: AppColors.accent,
              onSubmitted: (_) => widget.onSubmit(),
              inputFormatters: [_GroupingFormatter(widget.country)],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: _hint,
                hintStyle: const TextStyle(
                  color: AppColors.inkFaint,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live-formats the number with the active country's grouping + caps its length.
class _GroupingFormatter extends TextInputFormatter {
  const _GroupingFormatter(this.country);
  final CountryCode country;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > country.maxLen) {
      digits = digits.substring(0, country.maxLen);
    }
    final text = country.format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// The gradient Continue button — bold when enabled, muted when not.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDeep],
                )
              : null,
          color: enabled ? null : AppColors.cardBorder,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: Colors.white),
              )
            : Text(
                'Continue',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: enabled ? Colors.white : AppColors.inkFaint,
                ),
              ),
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.current});
  final CountryCode current;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final items = kCountryCodes
        .where((c) => c.name.toLowerCase().contains(q) || c.dial.contains(q))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select country',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final c = items[i];
                  return ListTile(
                    leading: CountryFlag(iso: c.iso, size: 24),
                    title: Text(c.name),
                    trailing: Text(c.dial,
                        style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600)),
                    selected: c.iso == widget.current.iso,
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
