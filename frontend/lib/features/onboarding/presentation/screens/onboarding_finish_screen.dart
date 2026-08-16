import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/starfield.dart';
import '../../../auth/data/auth_store.dart';
import '../../../auth/domain/country_code.dart';
import '../../../auth/presentation/auth_gate.dart';
import '../../../auth/presentation/widgets/app_logo.dart';
import '../../../auth/presentation/widgets/country_flag.dart';
import '../../../home/home_page.dart';
import '../../../tasks/data/task_store.dart';

/// Open the name + phone "claim" screen — the shared verify surface. [verify] is
/// the gate's OTP trigger (capture it from AuthGateController where it's in
/// scope, since the page's own context can't reach the controller). Used by
/// both the onboarding finish screen and the home preview lock so verification
/// always asks for name + number on one premium, full-screen page.
///
/// This is a full PAGE (pushed route), not a bottom sheet — a first impression
/// deserves the whole canvas: the orbit brandmark over a live starfield, a warm
/// headline, two large fields, and a confident CTA. Named `showClaimSheet` still
/// for its two callers; the "sheet" is historical.
void showClaimSheet(
  BuildContext context,
  Future<void> Function(String phoneE164, {String? name}) verify,
) {
  HapticFeedback.mediumImpact();
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => _ClaimPage(onVerify: verify),
      transitionsBuilder: (context, anim, _, child) {
        // A calm fade + gentle rise — the page settles in, no harsh slam.
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// The make-or-break final screen of onboarding.
///
/// The user's finished app — the REAL [HomePage], already populated with the
/// reminders they just set up (created on the server under the anonymous owner
/// id) — fills the whole screen behind, only LIGHTLY veiled (a gentle dim) so
/// they can still READ it: "this is your app, already built." A small prompt
/// floats at the bottom — "Final step to unlock your reminders" + a compact
/// "Verify to get in" button. Tapping it RISES a sheet (name + number → SMS
/// verify) over the still-visible home. Once they see their own work waiting,
/// verifying to claim it feels like unlocking, not starting over.
///
/// On verify, [AuthStore.login] claims the anonymous session onto the phone, so
/// the exact tasks shown here carry straight into the signed-in app.
///
/// Verification reuses the app's one OTP pipeline via [AuthGateController], so
/// this screen is mounted as [AuthGate.child]: it shows while logged out and
/// the gate flips to the app the instant the number is verified.
class OnboardingFinishScreen extends StatefulWidget {
  const OnboardingFinishScreen({super.key, required this.store});

  /// The task store, already holding the freshly-created onboarding reminders,
  /// used to render the real Home behind the sheet.
  final TaskStore store;

  @override
  State<OnboardingFinishScreen> createState() => _OnboardingFinishScreenState();
}

class _OnboardingFinishScreenState extends State<OnboardingFinishScreen> {
  /// Slide the claim sheet up on demand. Read the gate's verify callback HERE
  /// (this State's context is under AuthGateController; the sheet's own context
  /// is not), then hand it to the shared opener.
  void _openClaim() {
    showClaimSheet(context, AuthGateController.of(context).verify);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── The finished app (their REAL home), full-screen, lightly veiled
          //    but still readable ──
          Positioned.fill(
            child: _HomePreview(store: widget.store),
          ),
          // ── A small floating prompt + compact button at the bottom ──
          Align(
            alignment: Alignment.bottomCenter,
            child: _FinalStepPrompt(onTap: _openClaim),
          ),
        ],
      ),
    );
  }
}

/// The small floating prompt at the bottom: one line of copy over a soft
/// gradient scrim, and a compact "Verify to get in" button. Deliberately tiny —
/// the home behind it is the hero; this is just the key to it.
class _FinalStepPrompt extends StatelessWidget {
  const _FinalStepPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // A scrim so the text is legible over the home preview.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bg.withValues(alpha: 0.0),
            AppColors.bg.withValues(alpha: 0.75),
            AppColors.bg,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_open_rounded,
                  size: 22, color: AppColors.accent),
              const SizedBox(height: 10),
              const Text(
                'Final step to unlock your reminders',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Verify your number to save everything and get in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _VerifyButton(
                  enabled: true,
                  loading: false,
                  label: 'Verify to get in',
                  onTap: onTap,
                ),
              ),
              // DEV: straight into Home while login is being sorted out.
              TextButton(
                onPressed: () =>
                    AuthStore.instance.login('+10000000000', name: 'You'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkSoft,
                ),
                child: const Text(
                  'Skip for now → Home',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The user's finished app — the REAL [HomePage], driven by the store already
/// holding their freshly-created reminders — filling the screen. Only LIGHTLY
/// veiled: a soft dim (so the bottom prompt reads clearly) rather than a heavy
/// one, and non-interactive (this is a preview). What they see here is exactly
/// what the signed-in app shows, because it IS that widget.
class _HomePreview extends StatelessWidget {
  const _HomePreview({required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        // Match the app shell's background gradient so it's seamless.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: Stack(
          children: [
            // The real Home, softened just enough to sit behind the prompt.
            Positioned.fill(
              child: Opacity(
                opacity: 0.9,
                child: HomePage(store: store),
              ),
            ),
            // A gentle dim so the floating prompt has a calm ground — light at
            // the top (home stays readable), deeper toward the bottom.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bg.withValues(alpha: 0.12),
                      AppColors.bg.withValues(alpha: 0.28),
                      AppColors.bg.withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full-page name + number screen that turns the finished setup into an
/// account. The whole canvas is the Orbit space theme — a live starfield behind
/// the brandmark — so the first impression feels crafted and premium, not a
/// plain card. Two large fields (name, then number) and one confident CTA.
class _ClaimPage extends StatefulWidget {
  const _ClaimPage({required this.onVerify});

  /// The gate's verification trigger, captured above the page (where the
  /// AuthGateController is in scope) and passed in — the page's own context
  /// can't reach the controller.
  final Future<void> Function(String phoneE164, {String? name}) onVerify;

  @override
  State<_ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends State<_ClaimPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  CountryCode _country = kCountryCodes.first; // India
  bool _submitting = false;

  // NOTE: we deliberately do NOT setState on every keystroke. Rebuilding the
  // whole page per character re-laid-out every field + the button and made the
  // screen feel jumpy. Instead only the verify button listens to the
  // controllers (via ListenableBuilder below), so typing is smooth and stable.

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  String get _digits => _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
  bool get _nameOk => _nameCtrl.text.trim().length >= 2;
  bool get _phoneOk => _digits.length >= 6 && _digits.length <= _country.maxLen;
  bool get _valid => _nameOk && _phoneOk;

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final e164 = '${_country.dial}$_digits';
    final name = _nameCtrl.text.trim();

    // Close this page FIRST, then start verification via the callback captured
    // above. Popping first means the OTP screen the gate pushes lands on top
    // (not hidden behind this route), so Verify visibly advances.
    Navigator.of(context).pop();
    await widget.onVerify(e164, name: name);
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
      setState(() {
        _country = picked;
        final trimmed = _digits.length > _country.maxLen
            ? _digits.substring(0, _country.maxLen)
            : _digits;
        final text = _country.format(trimmed);
        _phoneCtrl.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Starfield(
        intensity: 0.7,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Column(
              children: [
                // A small back affordance, top-left — this is a pushed page.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.inkSoft),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // The brandmark — the orbit logo, glowing, centered high
                        // on the page so it anchors the whole screen.
                        const Center(child: AppLogo(size: 76)),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            const Icon(Icons.lock_open_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              'ONE LAST STEP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                color: AppColors.accent.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Save your reminders',
                          style: TextStyle(
                            fontSize: 32,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Your name and number keep everything safe and '
                          'synced across your devices.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _FieldLabel('YOUR NAME'),
                        const SizedBox(height: 8),
                        _NameField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          onSubmitted: () => _phoneFocus.requestFocus(),
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel('PHONE NUMBER'),
                        const SizedBox(height: 8),
                        _PhoneRow(
                          country: _country,
                          controller: _phoneCtrl,
                          focusNode: _phoneFocus,
                          onPickCountry: _pickCountry,
                          onSubmit: _submit,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Icon(Icons.lock_rounded,
                                size: 13, color: AppColors.inkFaint),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Private & secure. We never share your number.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
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
                // The CTA, pinned at the bottom, lifting above the keyboard.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    // Only the button rebuilds as you type — it watches both
                    // controllers directly, so the rest of the page stays put.
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_nameCtrl, _phoneCtrl]),
                      builder: (context, _) => _VerifyButton(
                        enabled: _valid && !_submitting,
                        loading: _submitting,
                        label: 'Continue',
                        onTap: _submit,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small uppercase caption above each field — quiet structure that makes the
/// page read as considered, not a bare stack of inputs.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppColors.inkFaint,
      ),
    );
  }
}

/// The name input — a large glass field that lifts with an accent glow when
/// focused, matching the phone field so both read as one premium set.
class _NameField extends StatefulWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused ? AppColors.accent : AppColors.cardBorder,
          width: _focused ? 1.6 : 1.2,
        ),
        boxShadow: [
          if (_focused)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
            child: Icon(Icons.person_rounded,
                size: 21,
                color: _focused ? AppColors.accent : AppColors.inkFaint),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              cursorColor: AppColors.accent,
              onSubmitted: (_) => widget.onSubmitted(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Your name',
                hintStyle: TextStyle(
                  color: AppColors.inkFaint,
                  fontWeight: FontWeight.w600,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone input row — country selector + grouped number field. Lifts with an
/// accent glow when focused, matching the name field.
class _PhoneRow extends StatefulWidget {
  const _PhoneRow({
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
  State<_PhoneRow> createState() => _PhoneRowState();
}

class _PhoneRowState extends State<_PhoneRow> {
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

  String get _hint => widget.country.format('X' * widget.country.maxLen);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused ? AppColors.accent : AppColors.cardBorder,
          width: _focused ? 1.6 : 1.2,
        ),
        boxShadow: [
          if (_focused)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onPickCountry,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 10, 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountryFlag(iso: widget.country.iso, size: 21),
                  const SizedBox(width: 8),
                  Text(
                    widget.country.dial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded,
                      size: 20, color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 28, color: AppColors.cardBorder),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              cursorColor: AppColors.accent,
              onSubmitted: (_) => widget.onSubmit(),
              inputFormatters: [_GroupingFormatter(widget.country)],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: 1.4,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _hint,
                hintStyle: const TextStyle(
                  color: AppColors.inkFaint,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
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

/// Live-formats the number with the active country's grouping + caps length.
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

/// The accent verify button — bold when the form is valid.
class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
    this.label = 'Verify & finish',
  });

  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: enabled ? Colors.white : AppColors.inkFaint,
                ),
              ),
      ),
    );
  }
}

/// Country picker sheet — a slim copy of the login page's, so the finish screen
/// stays self-contained.
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
                child: Text(
                  'Select country',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
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
                    trailing: Text(
                      c.dial,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
