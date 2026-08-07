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
  late final AnimationController _intro;

  List<OnboardingChipSection> get _sections => kOnboardingChipSections;
  OnboardingChipSection get _section => _sections[_index];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
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

  void _replay() => _intro
    ..reset()
    ..forward();

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
    // Rows share the back half of the timeline, one staggered beat each.
    const rowsStart = 0.34;
    final perRow = (0.9 - rowsStart) / items.length;

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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      children: [
                        // Header: Revo (left) + question.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Revo, first to arrive — a little scale-in pop.
                            Padding(
                              padding: const EdgeInsets.only(right: 6, top: 2),
                              child: Transform.scale(
                                scale: Curves.easeOutBack.transform(
                                  (_intro.value / 0.16).clamp(0.0, 1.0),
                                ),
                                child: const AnimatedMascot(
                                  size: 60,
                                  glow: false,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _reveal(
                                0.12,
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _questionFor(section),
                                    style: const TextStyle(
                                      fontSize: 27,
                                      height: 1.12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _reveal(
                          0.22,
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
                  _reveal(
                    0.9,
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
