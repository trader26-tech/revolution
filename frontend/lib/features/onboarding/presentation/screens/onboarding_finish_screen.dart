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
/// The user's completed setup — every reminder they picked, with its schedule —
/// is rendered LIVE behind, softly blurred and dimmed. It reads as "your setup
/// is done and sitting right here". A single sheet rises over it: "Almost done!
/// Just your name and number." Once they see their own work already prepared,
/// giving a name + number to save it feels like claiming it, not starting over.
///
/// Verification reuses the app's one OTP pipeline via [AuthGateController], so
/// this screen is mounted as [AuthGate.child]: it shows while logged out and
/// the gate flips to the app the instant the number is verified.
class OnboardingFinishScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: false,
      body: Starfield(
        intensity: 0.6,
        child: Stack(
          children: [
            // ── The completed setup, blurred + dimmed behind everything ──
            Positioned.fill(
              child: _BlurredSummary(picked: picked, drafts: drafts),
            ),
            // ── The claim sheet, riding at the bottom ──
            const Align(
              alignment: Alignment.bottomCenter,
              child: _ClaimSheet(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked reminders, laid out as a real finished-looking summary, then
/// blurred and dimmed so the sheet reads clearly on top. The content is the
/// user's actual work — sections with their items and schedules — so it feels
/// like their setup is genuinely there, ready to be saved.
class _BlurredSummary extends StatelessWidget {
  const _BlurredSummary({required this.picked, required this.drafts});

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
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ShaderMask(
          // Fade the summary out toward the bottom so it slides cleanly under
          // the sheet with no hard seam.
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.62, 0.92],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: Opacity(
            opacity: 0.5,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your setup',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_total(sections)} reminders ready',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 18),
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
    // Lift the sheet above the keyboard when it's up.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
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
          child: Padding(
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
                'Verify & finish',
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
