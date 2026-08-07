import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// Onboarding page 2: "Which … should we remember?"
///
/// A one-category-per-screen wizard. The flow's shared 3-dot header (common to
/// every onboarding screen) carries the macro progress; this screen shows only
/// a light in-content counter — "Subscriptions · 1 of 5" with a back-arrow —
/// so there's no rival progress bar. Revo greets from the top-left, and each
/// category is a clean LIST of rows (icon + name + radio) — the commonest ones
/// arrive already selected. A bottom line reassures ("not here? add more in the
/// app") above the Continue button, which walks to the next category.
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
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      children: [
                        // Category counter: back-arrow + "Subscriptions · 1 of 5".
                        // The flow's 3-dot header carries the macro progress now,
                        // so this is a light, in-content label — NOT a second
                        // progress bar competing with the dots above.
                        _CategoryCounter(
                          title: section.title,
                          index: _index,
                          count: _sections.length,
                          onBack: _back,
                        ),
                        const SizedBox(height: 12),
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
                          // The promise — short. Meaning: whatever isn't in
                          // this shortlist is still available to add once you're
                          // inside the app, so the accent lands on "in the app".
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Not here? Add more '),
                                TextSpan(
                                  text: 'in the app.',
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

/// The in-content category counter: a back-arrow beside a soft pill reading
/// "Subscriptions · 1 of 5". This tells you WHICH category of five you're on
/// without a second progress bar — the flow's 3-dot header owns the macro
/// progress, so this stays deliberately light and textual.
class _CategoryCounter extends StatelessWidget {
  const _CategoryCounter({
    required this.title,
    required this.index,
    required this.count,
    required this.onBack,
  });

  final String title;
  final int index;
  final int count;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back — tucked left, small, so it reads as a step-back not a top bar.
        _BackChip(onTap: onBack),
        const SizedBox(width: 10),
        // The pill: category name, a dot, then "N of 5".
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      color: AppColors.accent.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(text: '  ·  '),
                  TextSpan(text: '${index + 1} of $count'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.inkFaint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small circular back affordance — light enough to sit inside the content,
/// not read as a page-level app bar.
class _BackChip extends StatelessWidget {
  const _BackChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

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

  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Split on spaces but keep newlines attached, so the two-line questions
    // ("Which subscriptions\nshould we remember?") wrap where they're meant to.
    final lines = text.split(String.fromCharCode(10));
    final wordCount = lines.fold<int>(0, (n, l) => n + l.split(' ').length);

    // Stagger the word STARTS evenly across [0 .. 1 - wordWindow] and give every
    // word the same window, so the FIRST starts at 0 and the LAST finishes
    // exactly at progress == 1. This guarantees every word — including the last
    // ("remember?") — reaches local t == 1 and fully settles (no glow/haze left
    // stuck on it once the line is done). The window is wider than one slot so
    // consecutive words overlap and the reveal flows like a cascade.
    const wordWindow = 0.55; // each word's fade-in length, in timeline units
    final lastStart = wordCount > 1 ? (1 - wordWindow) : 0.0;
    final step = wordCount > 1 ? lastStart / (wordCount - 1) : 0.0;
    double localFor(int i) {
      final start = i * step;
      return ((progress - start) / wordWindow).clamp(0.0, 1.0);
    }

    var wordIndex = 0;
    final rows = <Widget>[];
    for (final line in lines) {
      final children = <Widget>[
        for (final w in line.split(' '))
          _MagicWord(word: w, t: localFor(wordIndex++), style: style),
      ];
      rows.add(
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );
    }

    // The invisible full text underneath reserves the final height/width so the
    // materialising words never shift the layout as they land.
    return Stack(
      children: [
        Opacity(opacity: 0, child: Text(text, style: style)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ],
    );
  }
}

/// One word of the magic reveal. Across its own 0-to-1 life [t] it fades in,
/// un-blurs from a haze, floats up, scales from small with a springy overshoot,
/// and flashes a soft violet glow that fades as it settles.
class _MagicWord extends StatelessWidget {
  const _MagicWord({required this.word, required this.t, required this.style});

  final String word;
  final double t;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final ease = Curves.easeOut.transform(t);
    final spring = Curves.elasticOut.transform(t);

    final blur = (1 - ease) * 8; // haze that resolves as it arrives
    final lift = (1 - ease) * 14; // floats up into place
    final scale = 0.7 + spring * 0.3; // small, overshoot, then settle
    // Glow blooms mid-arrival then fades to nothing. Hard-zero once basically
    // settled so no faint halo can linger on a word (esp. the last one).
    final glow = t >= 0.999 ? 0.0 : math.sin(t.clamp(0.0, 1.0) * math.pi);

    Widget label = Text(
      word,
      style: style.copyWith(
        shadows: [
          Shadow(
            color: AppColors.accent.withValues(alpha: 0.55 * glow),
            blurRadius: 18 * glow,
          ),
        ],
      ),
    );

    // A cheap per-word blur while it's arriving, dropped once settled so
    // finished text stays crisp.
    if (blur > 0.05) {
      label = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: label,
      );
    }

    return Opacity(
      opacity: ease,
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: label,
          ),
        ),
      ),
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
