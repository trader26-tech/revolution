import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/starfield.dart';
import '../../../auth/domain/country_code.dart';
import '../../../auth/presentation/auth_gate.dart';
import '../../../auth/presentation/widgets/country_flag.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// The make-or-break final screen of onboarding.
///
/// The user's finished app — their real Home, showing every reminder they set —
/// fills the whole screen behind, only LIGHTLY veiled (a soft blur + gentle dim)
/// so they can still READ it: "this is your app, already built." A small prompt
/// floats at the bottom — "Final step to unlock your reminders" + a compact
/// "Verify to get in" button. Tapping it RISES a sheet (name + number → SMS
/// verify) over the still-visible home. Once they see their own work waiting,
/// verifying to claim it feels like unlocking, not starting over.
///
/// Verification reuses the app's one OTP pipeline via [AuthGateController], so
/// this screen is mounted as [AuthGate.child]: it shows while logged out and
/// the gate flips to the app the instant the number is verified.
class OnboardingFinishScreen extends StatefulWidget {
  const OnboardingFinishScreen({
    super.key,
    required this.picked,
    required this.drafts,
  });

  /// The chip keys the user picked across onboarding.
  final Set<String> picked;

  /// The per-item schedule drafts (name / day / frequency), keyed by chip key.
  final Map<String, ReminderDraft> drafts;

  @override
  State<OnboardingFinishScreen> createState() => _OnboardingFinishScreenState();
}

class _OnboardingFinishScreenState extends State<OnboardingFinishScreen> {
  /// Slide the claim sheet up on demand.
  void _openClaim() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // full height for the keyboard
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _ClaimSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      body: Starfield(
        intensity: 0.6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── The finished app (their reminders), full-screen, lightly veiled
            //    but still readable ──
            Positioned.fill(
              child: _HomePreview(picked: widget.picked, drafts: widget.drafts),
            ),
            // ── A small floating prompt + compact button at the bottom ──
            Align(
              alignment: Alignment.bottomCenter,
              child: _FinalStepPrompt(onTap: _openClaim),
            ),
          ],
        ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// The user's finished app — their real reminders in the Home layout — filling
/// the screen. Only LIGHTLY veiled: a gentle blur + a soft dim, tuned so the
/// content stays READABLE (you can see your own reminders), while still reading
/// as "behind glass" so the prompt/sheet on top is clearly the focus.
class _HomePreview extends StatelessWidget {
  const _HomePreview({required this.picked, required this.drafts});

  final Set<String> picked;
  final Map<String, ReminderDraft> drafts;

  List<OnboardingChipSection> get _sections => [
        for (final s in kOnboardingChipSections)
          if (s.items.any((i) => picked.contains(i.key))) s,
      ];

  List<OnboardingChipItem> _pickedItems(OnboardingChipSection s) =>
      s.items.where((i) => picked.contains(i.key)).toList();

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    // Light veil: a small blur so it's clearly "behind glass" but every word is
    // still readable, plus a slight dim (opacity) rather than a heavy one.
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
        child: Opacity(
          opacity: 0.82,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A Home-style header (greeting + count), matching the app.
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your reminders',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_total(sections)} set up and ready',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // A faux profile chip, like the real home's top-right.
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.16),
                          border:
                              Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 20, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        for (final s in sections)
                          _SummarySection(
                            section: s,
                            items: _pickedItems(s),
                            drafts: drafts,
                          ),
                      ],
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

  int _total(List<OnboardingChipSection> sections) =>
      sections.fold(0, (n, s) => n + _pickedItems(s).length);
}

/// One category block in the blurred summary — a quiet all-caps header and its
/// picked items as compact rows.
class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.section,
    required this.items,
    required this.drafts,
  });

  final OnboardingChipSection section;
  final List<OnboardingChipItem> items;
  final Map<String, ReminderDraft> drafts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(section.icon, size: 15, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                section.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        for (final item in items) _SummaryRow(item: item, draft: drafts[item.key]),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// A single reminder row — icon, name, and its schedule sentence.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.item, this.draft});

  final OnboardingChipItem item;
  final ReminderDraft? draft;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d?.name ?? item.defaultName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  d == null
                      ? 'Reminder set'
                      : '${_freqLabel(d.timesPerYear)} · ${_dateLabel(d.month, d.day)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.accent),
        ],
      ),
    );
  }
}

/// Plain-English cadence for the summary, matching the schedule screen's words.
String _freqLabel(int timesPerYear) => switch (timesPerYear) {
      1 => 'Once a year',
      2 => 'Every 6 months',
      4 => 'Every 3 months',
      6 => 'Every 2 months',
      _ => 'Every month',
    };

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateLabel(int month, int day) =>
    '$day ${_monthNames[(month - 1).clamp(0, 11)]}';

/// The bottom sheet that turns the finished setup into an account — name +
/// number, then SMS verify. Small and calm: the heavy lifting (the reminders)
/// is already visibly done behind it.
class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet();

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  CountryCode _country = kCountryCodes.first; // India
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _phoneCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
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
    try {
      await AuthGateController.of(context)
          .verify(e164, name: _nameCtrl.text.trim());
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
    // A modal sheet: rounded card that grows with content and lifts above the
    // keyboard via viewInsets. It rises over the still-visible home preview.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 18, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Almost done!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add your name and number to save everything and get WhatsApp reminders.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 18),
                // Name.
                _NameField(
                  controller: _nameCtrl,
                  onSubmitted: () => _phoneFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                // Number.
                _PhoneRow(
                  country: _country,
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  onPickCountry: _pickCountry,
                  onSubmit: _submit,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _VerifyButton(
                    enabled: _valid && !_submitting,
                    loading: _submitting,
                    label: 'Verify & finish',
                    onTap: _submit,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_rounded, size: 13, color: AppColors.inkFaint),
                    SizedBox(width: 6),
                    Text(
                      'Private & secure. We never share your number.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The name input row.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 10, 0),
            child: Icon(Icons.person_rounded,
                size: 20, color: AppColors.inkFaint),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => onSubmitted(),
              style: const TextStyle(
                fontSize: 17,
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
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone input row — country selector + grouped number field.
class _PhoneRow extends StatelessWidget {
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

  String get _hint => country.format('X' * country.maxLen);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onPickCountry,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountryFlag(iso: country.iso, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    country.dial,
                    style: const TextStyle(
                      fontSize: 17,
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
          Container(width: 1, height: 26, color: AppColors.cardBorder),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              cursorColor: AppColors.accent,
              onSubmitted: (_) => onSubmit(),
              inputFormatters: [_GroupingFormatter(country)],
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _hint,
                hintStyle: const TextStyle(
                  color: AppColors.inkFaint,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
        duration: const Duration(milliseconds: 200),
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
