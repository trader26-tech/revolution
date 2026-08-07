import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// Onboarding page 2: "Which … should we remember?"
///
/// A one-category-per-screen wizard. Revo greets from the top-left, a progress
/// bar shows how far along the five categories you are, and each category is a
/// clean LIST of rows (icon + name + radio) — the commonest ones arrive
/// already selected. A bottom line reassures ("even if it's not here, we've
/// got it") above the Continue button, which walks to the next category.
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
  /// The timeline runs: Revo pops in → the question types in word-by-word →
  /// "Tap all that apply." fades up → the rows cascade one-by-one → the bottom
  /// CTA reveals. Longer than a plain fade so the typewriter has room to read.
  late final AnimationController _intro;

  /// Resets to the top on every category change so each screen starts fresh
  /// (Revo at the top, question typing in) rather than mid-scroll.
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

  void _back() {
    HapticFeedback.lightImpact();
    if (_index == 0) {
      widget.onExit?.call();
      return;
    }
    setState(() => _index--);
    _replay();
  }

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
                  // Top bar: back + a five-segment progress bar.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.inkSoft,
                        ),
                        Expanded(
                          child: _ProgressBar(
                            count: _sections.length,
                            index: _index,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_index + 1}/${_sections.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      children: [
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
                              child: _RevoEntrance(
                                t: (_intro.value / 0.26).clamp(0.0, 1.0),
                                child: const AnimatedMascot(
                                  size: 60,
                                  glow: false,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: _MagicText(
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
                        _reveal(
                          taglineStart,
                          const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Text(
                              'Tap all that apply.',
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
                          // The promise — short.
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Not here? '),
                                TextSpan(
                                  text: "We've got it.",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent
                                        .withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: _next,
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
}

/// The five-segment fill bar: past + current segments are lit violet, upcoming
/// ones are dim; the current one animates its fill in.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: 5,
              decoration: BoxDecoration(
                color: i <= index
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(3),
                boxShadow: i <= index
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// The question, revealed word-by-word like it's being typed. [progress] is a
/// 0→1 fraction of how much of the text is shown; the last visible word carries
/// a soft violet caret while typing, which vanishes once the line is complete.
///
/// The full text is laid out invisibly underneath so the box reserves its final
/// height from frame one — the rows below never jump as words land.
/// Revo's entrance: fades in while scaling up past full size and settling back
/// with a springy overshoot, rising a touch as he arrives — a bubbly bounce,
/// not a snap. [t] runs 0->1 across his slice of the timeline.
class _RevoEntrance extends StatelessWidget {
  const _RevoEntrance({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // elasticOut gives the bubbly overshoot-and-settle; easeOut fades/lifts.
    final spring = Curves.elasticOut.transform(t);
    final ease = Curves.easeOut.transform(t);
    final scale = 0.2 + spring * 0.8; // starts small, overshoots, then settles
    return Opacity(
      opacity: ease,
      child: Transform.translate(
        offset: Offset(0, (1 - ease) * 10),
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }
}

/// The question, revealed the way an AI would conjure it: each word
/// MATERIALISES on its own — blurring in from a haze, floating up into place,
/// and settling with a springy overshoot and a brief violet glow. Not typed.
///
/// [progress] is a 0->1 fraction across the question's timeline slice; from it
/// each word gets its own local 0->1 so they arrive one after another. The full
/// text is laid out invisibly beneath so the box holds its final size from
/// frame one and nothing below ever reflows.
class _MagicText extends StatelessWidget {
  const _MagicText({
    super.key,
    required this.text,
    required this.progress,
    required this.style,
  });

  final String text;

  /// 0 → nothing shown, 1 → whole line shown.
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Split on spaces but keep newlines attached, so the two-line questions
    // ("Which subscriptions\nshould we remember?") wrap where they're meant to.
    final words = text.split(' ');
    final shown = (words.length * progress).ceil().clamp(0, words.length);
    final done = shown >= words.length;
    final visible = words.take(shown).join(' ');

    final caretColor = AppColors.accent.withValues(alpha: done ? 0.0 : 0.9);

    // A Stack: the full text sizes the box (transparent), the typed slice sits
    // on top. Both share the same style + wrapping, so no reflow.
    return Stack(
      children: [
        Opacity(
          opacity: 0,
          child: Text(text, style: style),
        ),
        Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: visible),
              // A block caret riding just after the last typed word.
              TextSpan(
                text: done ? '' : ' |',
                style: TextStyle(color: caretColor),
              ),
            ],
          ),
        ),
      ],
    );
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
