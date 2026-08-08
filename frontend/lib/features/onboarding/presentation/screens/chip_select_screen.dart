import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/magic_text.dart' show MagicText, RevoEntrance;
import '../widgets/reminder_confirm_sheet.dart';

/// Onboarding page 2: "What should we remember?"
///
/// ONE scrollable screen, not a per-category wizard. Revo greets from the
/// top-left with a single question; below him the whole catalog scrolls as a
/// sectioned list — a header per category (SUBSCRIPTIONS, DOCUMENTS, …) with its
/// items as WRAPPING CHIPS under it, so a big catalog stays compact. The
/// commonest items arrive already selected. One "Continue" at the bottom fires
/// [onComplete] with a draft per picked item and moves straight to the payoff.
/// Faster and cleaner than stepping through five screens.
///
/// The flow's shared 3-dot header carries the macro progress, so there's no
/// per-section progress or momentum copy here.

/// The items ticked on arrival — seed a picked-set with these.
Set<String> preselectedChipKeys() => {
  for (final s in kOnboardingChipSections)
    for (final i in s.items)
      if (i.preselected) i.key,
};

/// A ready-to-save draft for every picked item, each prefilled to its NEXT
/// upcoming date from today (so the schedule screen shows real future dates,
/// customised to when the user onboards — not stale catalog defaults).
Map<String, ReminderDraft> chipDraftsFor(Set<String> picked) {
  final now = DateTime.now();
  return {
    for (final s in kOnboardingChipSections)
      for (final i in s.items)
        if (picked.contains(i.key))
          i.key: ReminderDraft.smart(
            name: i.defaultName,
            defaultDay: i.defaultDay,
            frequency: i.defaultFrequency,
            now: now,
          ),
  };
}

class ChipSelectWizard extends StatefulWidget {
  const ChipSelectWizard({
    super.key,
    required this.picked,
    required this.onToggle,
    required this.onComplete,
  });

  /// The shared picked set (lives in the parent so the payoff can read it).
  final Set<String> picked;
  final ValueChanged<String> onToggle;

  /// Fired on Continue with a ready-to-save draft per picked item.
  final ValueChanged<Map<String, ReminderDraft>> onComplete;

  @override
  State<ChipSelectWizard> createState() => _ChipSelectWizardState();
}

class _ChipSelectWizardState extends State<ChipSelectWizard>
    with SingleTickerProviderStateMixin {
  /// One-shot entrance, timed in ABSOLUTE MILLISECONDS so the reveal is a clean
  /// top-to-bottom WATERFALL that doesn't bunch up however many items there are.
  /// Tuned SNAPPY — the acts still read in order, but the chips stream in fast
  /// so nothing feels like a load:
  ///   0..350     Revo makes his bubbly entrance.
  ///   —— brief pause ——
  ///   650..1450  the question MATERIALISES word by word (the shimmer).
  ///   —— brief pause —— (a beat to READ the question)
  ///   1850..     the tagline, then EACH row (header, then each chip) fades in
  ///              one after another, a tight [_beatGap] apart, strictly in
  ///              reading order down the screen.
  late final AnimationController _intro;
  final _scroll = ScrollController();

  List<OnboardingChipSection> get _sections => kOnboardingChipSections;

  // Absolute timings (ms) for the fixed phases.
  // Snappy timing: the acts still read in order, but the user never waits on
  // the chips — they flow in quickly, close on each other's heels.
  static const _revoMs = 350;
  static const _questionStartMs = 650;
  static const _questionEndMs = 1450;
  static const _taglineMs = 1650;
  static const _cascadeStartMs = 1850; // first header begins here
  static const _beatGap = 55; // tight gap so chips stream in, no waiting
  static const _beatWindow = 260; // each row's fade-in length

  /// Total rows in the cascade: one header + its chips, per section.
  int get _beatCount =>
      _sections.fold(0, (n, s) => n + 1 + s.items.length);

  /// The full timeline length, sized so the LAST row still fully lands.
  int get _totalMs =>
      _cascadeStartMs + (_beatCount - 1) * _beatGap + _beatWindow;

  /// Elapsed milliseconds into the entrance.
  double get _ms => _intro.value * _totalMs;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _intro.duration = Duration(milliseconds: _totalMs);
      _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 0→1 progress across an absolute ms window — for MagicText's shimmer and the
  /// fixed-phase reveals.
  double _win(num startMs, num endMs) =>
      ((_ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

  /// Fade + slide-up for a fixed-phase element starting at [startMs].
  Widget _reveal(num startMs, Widget child, {num window = _beatWindow}) {
    // Entrance over → everything is simply, permanently visible. This also
    // guarantees nothing can ever fade back out after the intro.
    if (_intro.isCompleted) return child;
    final t = Curves.easeOutCubic.transform(_win(startMs, startMs + window));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    );
  }

  /// A chip/header's own entrance in the waterfall: fade + lift + a springy
  /// scale-in, starting at absolute [startMs].
  Widget _beatReveal(num startMs, Widget child) {
    if (_intro.isCompleted) return child;
    final raw = _win(startMs, startMs + _beatWindow);
    final ease = Curves.easeOutCubic.transform(raw);
    final spring = Curves.easeOutBack.transform(raw);
    return Opacity(
      opacity: ease,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - ease)),
        child: Transform.scale(
          scale: 0.85 + 0.15 * spring,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Each row's beat is derived STATICALLY from its position in the catalog
    // (sections in order: one header + its chips each), NOT from build order.
    // ListView builds/rebuilds lazily while scrolling, so a build-order cursor
    // hands rebuilt rows the wrong start times — which made top rows vanish
    // after scrolling. Position-derived beats are stable forever.
    final sectionBaseBeat = <int>[];
    var acc = 0;
    for (final s in _sections) {
      sectionBaseBeat.add(acc);
      acc += 1 + s.items.length;
    }
    num startOf(int beat) => _cascadeStartMs + beat * _beatGap;

    // No Scaffold/Starfield/SafeArea here — this renders inside OnboardingFlow,
    // which already provides the sky and safe area.
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
                  // Header: Revo (tail-left) + the question, which materialises
                  // word by word — the signature AI-conjuring shimmer.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        child: RevoEntrance(
                          t: _win(0, _revoMs),
                          child: Transform.flip(
                            flipX: true,
                            child: const AnimatedMascot(size: 60, glow: false),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: MagicText(
                            text: 'What should we\nremember?',
                            progress: _win(_questionStartMs, _questionEndMs),
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
                    _taglineMs,
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        'We already ticked what most people track — '
                        'untick what isn\'t yours.',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // The whole catalog, sectioned. The header and each chip take
                  // their own beat in the cascade, so the items shimmer in one
                  // after another down the screen.
                  for (var s = 0; s < _sections.length; s++)
                    _Section(
                      section: _sections[s],
                      picked: widget.picked,
                      onToggle: (key) {
                        HapticFeedback.lightImpact();
                        widget.onToggle(key);
                      },
                      topGap: s == 0 ? 0 : 14,
                      // Header + chips reveal on their own fixed beats, derived
                      // from catalog position — stable across scroll rebuilds.
                      headerReveal: (child) =>
                          _reveal(startOf(sectionBaseBeat[s]), child),
                      chipReveal: (i, child) =>
                          _beatReveal(startOf(sectionBaseBeat[s] + 1 + i), child),
                    ),
                ],
              ),
            ),
            // Bottom: one Continue, present as soon as the tagline lands so the
            // primary action is always there while the chips cascade above.
            _reveal(
              _taglineMs,
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
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
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onComplete(chipDraftsFor(widget.picked));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      // The button says exactly what will happen — the count
                      // updates live as chips are (un)ticked.
                      widget.picked.isEmpty
                          ? 'Skip for now'
                          : 'Remember these ${widget.picked.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One category block on the single-scroll picker: a header (the category name
/// as a quiet all-caps kicker) followed by its items as WRAPPING CHIPS — compact
/// pills that flow two-plus per row, so a long catalog stays short to scroll and
/// reads as "pick from the set".
class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.picked,
    required this.onToggle,
    required this.topGap,
    required this.headerReveal,
    required this.chipReveal,
  });

  final OnboardingChipSection section;
  final Set<String> picked;
  final ValueChanged<String> onToggle;
  final double topGap;

  /// Wraps the header (and each chip, by its index) in its own staggered
  /// entrance — the beat comes from catalog position, so it never shifts.
  final Widget Function(Widget child) headerReveal;
  final Widget Function(int index, Widget child) chipReveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topGap),
        // Section header — the category name, quiet and all-caps, with a small
        // icon so the sections read as distinct bands as you scroll.
        headerReveal(
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              children: [
                Icon(section.icon, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  section.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < section.items.length; i++)
              chipReveal(
                i,
                _Chip(
                  item: section.items[i],
                  selected: picked.contains(section.items[i].key),
                  onTap: () => onToggle(section.items[i].key),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One selectable chip: the item's icon + name in a compact pill. Selected, it
/// fills with a soft violet wash, its edge lights up, the icon flips to a check,
/// and it gets a gentle glow — one calm violet world on the dark sky, no
/// per-category colours. Unselected chips sit quietly in the glass surface.
class _Chip extends StatelessWidget {
  const _Chip({required this.item, required this.selected, required this.onTap});

  final OnboardingChipItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.26),
                  accent.withValues(alpha: 0.12),
                ],
              )
            : null,
        color: selected ? null : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.75) : AppColors.glassBorder,
          width: 1.4,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 14,
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: accent.withValues(alpha: 0.14),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The leading glyph swaps to a check when selected — a small,
                // satisfying confirmation without adding a separate control.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    selected ? Icons.check_rounded : item.icon,
                    key: ValueKey(selected),
                    size: 18,
                    color: selected ? Colors.white : AppColors.inkSoft,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.ink : AppColors.inkSoft,
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
