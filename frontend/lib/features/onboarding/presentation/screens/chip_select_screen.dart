import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/starfield.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// Onboarding page 2: "What should we remember?"
///
/// Five life categories, each a wrap of pill chips — tap all that apply. The
/// commonest picks arrive already selected, so the page reads as "yes, that's
/// me" rather than a form. One line of copy, one button, nothing else.
///
/// [ChipSelectBody] is the embeddable content (used as page 2 of the
/// onboarding PageView); [ChipSelectScreen] wraps it as a standalone screen
/// with its own header and continue button.

/// The chips ticked on arrival — seed a picked-set with these.
Set<String> preselectedChipKeys() => {
  for (final s in kOnboardingChipSections)
    for (final i in s.items)
      if (i.preselected) i.key,
};

/// A ready-to-save draft for every picked chip.
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

/// The scrolling chip-picker content, with state hoisted to the parent.
class ChipSelectBody extends StatelessWidget {
  const ChipSelectBody({
    super.key,
    required this.picked,
    required this.onToggle,
  });

  final Set<String> picked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What should we\nremember?',
                style: TextStyle(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap all that apply.',
                style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final s in kOnboardingChipSections) ...[
          _SectionHeader(section: s),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: [
              for (final i in s.items)
                _Chip(
                  item: i,
                  color: s.color,
                  selected: picked.contains(i.key),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onToggle(i.key);
                  },
                ),
            ],
          ),
          const SizedBox(height: 26),
        ],
        const Center(
          child: Text(
            "Don't see yours? Add more anytime.",
            style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint),
          ),
        ),
      ],
    );
  }
}

/// The standalone version: header + body + its own continue button.
class ChipSelectScreen extends StatefulWidget {
  const ChipSelectScreen({super.key, required this.onContinue, this.onBack});

  /// Fires with a draft per selected chip when the user taps Continue.
  final ValueChanged<Map<String, ReminderDraft>> onContinue;
  final VoidCallback? onBack;

  @override
  State<ChipSelectScreen> createState() => _ChipSelectScreenState();
}

class _ChipSelectScreenState extends State<ChipSelectScreen> {
  final Set<String> _selected = preselectedChipKeys();

  @override
  Widget build(BuildContext context) {
    final n = _selected.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Starfield(
        intensity: 0.7,
        child: SafeArea(
          child: Column(
            children: [
              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed:
                          widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.inkSoft,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: ChipSelectBody(
                  picked: _selected,
                  onToggle: (key) => setState(() {
                    _selected.contains(key)
                        ? _selected.remove(key)
                        : _selected.add(key);
                  }),
                ),
              ),
              // Bottom action — the sky fades up into it so the button
              // floats rather than sitting on an opaque bar.
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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
                  height: 54,
                  child: FilledButton(
                    onPressed: () =>
                        widget.onContinue(chipDraftsFor(_selected)),
                    child: Text(
                      n == 0 ? 'Skip for now' : 'Continue with $n',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});
  final OnboardingChipSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          // A little glowing "planet" — the section colour as a soft orb.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: section.color.withValues(alpha: 0.16),
              boxShadow: [
                BoxShadow(
                  color: section.color.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Icon(section.icon, size: 15, color: section.color),
          ),
          const SizedBox(width: 10),
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// One pill chip, styled for deep space.
///
/// Unselected it's a faint glass pill floating on the sky — barely-there fill,
/// hairline edge. Selected it lights up like a star coming on: the section
/// colour fills in, a soft outer glow blooms behind it, and its icon morphs
/// into a check.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.item,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final OnboardingChipItem item;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // Selected: a soft violet-tinted fill that reads lit. Unselected: a
        // near-transparent glass pane so the stars show through faintly.
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.30),
                  color.withValues(alpha: 0.16),
                ],
              )
            : null,
        color: selected ? null : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.85)
              : AppColors.glassBorder,
          width: 1.4,
        ),
        // The star turning on: a coloured glow blooms behind a selected chip.
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          splashColor: color.withValues(alpha: 0.18),
          highlightColor: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    selected ? Icons.check_rounded : item.icon,
                    key: ValueKey(selected),
                    size: 16,
                    color: selected ? Colors.white : AppColors.inkSoft,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
