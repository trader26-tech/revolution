import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/magic_text.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// Onboarding page 2: "Which … should we remember?"
///
/// A one-category-per-screen wizard. The flow's shared 3-dot header (common to
/// every onboarding screen) carries the macro progress. Two lines of copy do
/// the rest: the tagline under the question — "Choose a few, add more later" —
/// while the line just above the Continue button carries forward momentum —
/// "3 more to go", then "Last one" on the final screen. No separate progress
/// element;
/// the Continue button stays plain. Just a back-arrow sits at the top. Revo
/// greets from the top-left, and each category is a clean LIST of rows (icon +
/// name + radio) — the commonest ones arrive already selected.
///
/// [ChipSelectWizard] is the full self-driving flow used as page 2 of the
/// onboarding PageView; it fires [onComplete] with a draft per picked item
/// when the last category is done, and [onExit] if the user backs out of the
/// first one.

/// The items ticked on arrival — seed a picked-set with these.
Set<String> preselectedChipKeys() => {
  for (final s in kOnboardingChipSections)
    for (final i in s.items)
      if (i.preselected) i.key,
};

/// A ready-to-save draft for every picked item.
Map<String, ReminderDraft> chipDraftsFor(Set<String> picked) => {
  for (final s in kOnboardingChipSections)
    for (final i in s.items)
      if (picked.contains(i.key))
        i.key: ReminderDraft(
          name: i.defaultName,
          day: i.defaultDay,
          frequency: i.defaultFrequency,
        ),
};

/// "Which subscriptions should we remember?" etc. — a category-specific
/// question, kept short.
String _questionFor(OnboardingChipSection s) => switch (s.key) {
  'subs' => 'Which subscriptions\nshould we remember?',
  'docs' => 'Which documents\nshould we remember?',
  'family' => 'Whose dates\nshould we remember?',
  'insure' => 'Which renewals\nshould we remember?',
  'invest' => 'Which investments\nshould we remember?',
  _ => 'What should we\nremember?',
};

class ChipSelectWizard extends StatefulWidget {
  const ChipSelectWizard({
    super.key,
    required this.picked,
    required this.onToggle,
    required this.onComplete,
    this.onExit,
  });

  /// The shared picked set (lives in the parent so the payoff can read it).
  final Set<String> picked;
  final ValueChanged<String> onToggle;

  /// Fired when the user finishes the last category.
  final ValueChanged<Map<String, ReminderDraft>> onComplete;

  /// Fired when the user backs out of the first category (e.g. → intro).
  final VoidCallback? onExit;

  @override
  State<ChipSelectWizard> createState() => _ChipSelectWizardState();
}

class _ChipSelectWizardState extends State<ChipSelectWizard>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Drives the per-category entry cascade; replays on each category change.
  /// The timeline runs: Revo makes a slow bubbly entrance, the question's words
  /// materialise one by one, "Tap all that apply." drifts up, then the rows
  /// cascade in. Long and deliberate so nothing feels rushed.
  late final AnimationController _intro;

  /// Resets to the top on every category change so each screen starts fresh
  /// (Revo at the top, then the question materialising) rather than mid-scroll.
  final _scroll = ScrollController();

  List<OnboardingChipSection> get _sections => kOnboardingChipSections;
  OnboardingChipSection get _section => _sections[_index];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      // Slow and deliberate — a proper introduction. Revo takes his time, the
      // words materialise one by one, then the rows drift up. No hurry.
      duration: const Duration(milliseconds: 3400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _pickedInSection =>
      _section.items.where((i) => widget.picked.contains(i.key)).length;

  void _next() {
    HapticFeedback.lightImpact();
    if (_index >= _sections.length - 1) {
      widget.onComplete(chipDraftsFor(widget.picked));
      return;
    }
    setState(() => _index++);
    _replay();
  }

  void _replay() {
    // Jump back to the top so the new category starts from Revo, then replay
    // the whole entry cascade.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _intro
      ..reset()
      ..forward();
  }

  /// 0→1 progress over the timeline slice [start]..[end]. Linear, so each word
  /// gets an equal, unhurried beat to materialise (the per-word spring supplies
  /// the character of the motion).
  double _typeProgress(double start, double end) =>
      ((_intro.value - start) / (end - start)).clamp(0.0, 1.0);

  /// Fade + slide-up for the slice of the timeline [start]..[start]+[window].
  Widget _reveal(double start, Widget child, {double window = 0.3}) {
    final t = Curves.easeOutCubic
        .transform(((_intro.value - start) / window).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    final items = section.items;
    // The staged entry timeline (0..1), slow and deliberate:
    //   0.00..0.26  Revo makes his entrance — a slow bubbly bounce-in.
    //   0.26..0.66  the question's words MATERIALISE one by one (blur in, float
    //               up, settle with a springy overshoot + a soft glow).
    //   0.66..0.72  "Tap all that apply." drifts up.
    //   0.72..0.98  the rows cascade in, one calm beat each.
    const questionStart = 0.26;
    const questionEnd = 0.66;
    const taglineStart = 0.68;
    const rowsStart = 0.74;
    final perRow = (0.98 - rowsStart) / items.length;

    // No Scaffold/Starfield/SafeArea here — this renders as page 2 inside the
    // OnboardingFlow, which already provides the sky and safe area.
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        return Column(
          children: [
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      children: [
                        // No back button — the flow's shared 3-dot header carries
                        // the macro progress, and the "which of five categories"
                        // is carried by the Continue button's own fill.
                        // Header: Revo (left) + question.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Revo, first to arrive — a slow bubbly entrance: he
                            // fades in while scaling up past his size and
                            // settling back (a springy overshoot), so he lands
                            // with a little bounce rather than a snap.
                            Padding(
                              padding: const EdgeInsets.only(right: 6, top: 2),
                              child: RevoEntrance(
                                t: (_intro.value / 0.26).clamp(0.0, 1.0),
                                // Sitting top-left, Revo reads better with his
                                // tail pointing LEFT — mirror him horizontally.
                                // (His gaze flips with him, so it now leans right,
                                // still counterbalancing the tail.)
                                child: Transform.flip(
                                  flipX: true,
                                  child: const AnimatedMascot(
                                    size: 60,
                                    glow: false,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: MagicText(
                                  // Keyed by category so it restarts cleanly
                                  // when the question changes.
                                  key: ValueKey(section.key),
                                  text: _questionFor(section),
                                  progress: _typeProgress(
                                    questionStart,
                                    questionEnd,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 27,
                                    height: 1.12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Tagline under the question — one short line in a
                        // single light tone. Forward progress ("N more to go")
                        // lives down by the button.
                        _reveal(
                          taglineStart,
                          const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Text(
                              'Choose a few, add more later',
                              style: TextStyle(
                                fontSize: 14.5,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // The list — one row per item, cascading up.
                        for (var i = 0; i < items.length; i++)
                          _reveal(
                            rowsStart + perRow * i,
                            _Row(
                              item: items[i],
                              selected: widget.picked.contains(items[i].key),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onToggle(items[i].key);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Bottom: reassurance + Continue, the sky fading up into it.
                  // Reveal must COMPLETE within the 0..1 timeline, so start
                  // early enough that start+window <= 1.0 — otherwise the
                  // button caps at a faint fraction of full opacity and reads
                  // as "no button".
                  _reveal(
                    0.7,
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.bg.withValues(alpha: 0.0),
                            AppColors.bg.withValues(alpha: 0.85),
                            AppColors.bg,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Forward momentum, right above the button: "3 more to
                          // go" (or "Last one" on the final category) — the push
                          // to keep going. The "not here? add more in the app"
                          // reassurance now lives up in the tagline.
                          Text(
                            _remainingPhrase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: AppColors.accent.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // A plain, clean Continue — the "which of five" is
                          // spoken by Revo's tagline above, not carried here.
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed: _next,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _buttonLabel(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }

  String _buttonLabel() {
    final last = _index >= _sections.length - 1;
    if (_pickedInSection == 0) return last ? 'Finish' : 'None of these';
    return last ? 'Finish' : 'Continue';
  }

  /// The forward-looking progress phrase that leads Revo's tagline — how many
  /// categories are still ahead AFTER this one, framed as momentum: "4 more to
  /// go" … "1 more to go" … then "Last one" on the final screen. Short and
  /// motivating rather than a bare "N of 5".
  String _remainingPhrase() {
    final remaining = _sections.length - 1 - _index;
    if (remaining <= 0) return 'Last one';
    return '$remaining more to go';
  }
}

/// One list row: an icon tile, the name, and a radio circle. Selected, it fills
/// with a soft violet wash, its edge lights up, and the circle fills with a
/// check — one calm violet world, no per-category colours.
class _Row extends StatelessWidget {
  const _Row({required this.item, required this.selected, required this.onTap});

  final OnboardingChipItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.10),
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.7)
                : AppColors.glassBorder,
            width: 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: accent.withValues(alpha: 0.14),
            highlightColor: accent.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  // Icon tile.
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: selected ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      size: 21,
                      color: selected ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.ink : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Radio(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular selector on the right of a row.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accent : Colors.transparent,
        border: Border.all(
          color: selected
              ? AppColors.accent
              : AppColors.inkFaint.withValues(alpha: 0.7),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
