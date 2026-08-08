import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/magic_text.dart' show RevoEntrance;
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
  /// One-shot entrance: Revo pops, the question fades up, then the sections
  /// cascade in. Plays once — this is now a single screen, nothing to replay.
  late final AnimationController _intro;
  final _scroll = ScrollController();

  List<OnboardingChipSection> get _sections => kOnboardingChipSections;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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

  /// Fade + slide-up for the slice of the timeline [start]..[start]+[window].
  Widget _reveal(double start, Widget child, {double window = 0.5}) {
    final t = Curves.easeOutCubic
        .transform(((_intro.value - start) / window).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  // Header: Revo (tail-left) + one overall question.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        child: RevoEntrance(
                          t: (_intro.value / 0.24).clamp(0.0, 1.0),
                          child: Transform.flip(
                            flipX: true,
                            child: const AnimatedMascot(size: 60, glow: false),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _reveal(
                          0.14,
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'What should we\nremember?',
                              style: TextStyle(
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
                        'Choose a few, add more later',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // The whole catalog, sectioned: a header per category, its
                  // items as rows under it. The sections cascade in one after
                  // another across the back of the entrance timeline.
                  for (var s = 0; s < _sections.length; s++)
                    _reveal(
                      (0.30 + s * 0.06).clamp(0.0, 0.5),
                      _Section(
                        section: _sections[s],
                        picked: widget.picked,
                        onToggle: (key) {
                          HapticFeedback.lightImpact();
                          widget.onToggle(key);
                        },
                        // A little top gap between sections (not before the
                        // first, which sits right under the tagline).
                        topGap: s == 0 ? 0 : 22,
                      ),
                    ),
                ],
              ),
            ),
            // Bottom: one Continue, the sky fading up into it.
            _reveal(
              0.55,
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
                      widget.picked.isEmpty ? 'Skip for now' : 'Continue',
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
  });

  final OnboardingChipSection section;
  final Set<String> picked;
  final ValueChanged<String> onToggle;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topGap),
        // Section header — the category name, quiet and all-caps, with a small
        // icon so the sections read as distinct bands as you scroll.
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in section.items)
              _Chip(
                item: item,
                selected: picked.contains(item.key),
                onTap: () => onToggle(item.key),
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
