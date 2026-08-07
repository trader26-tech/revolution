import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// Onboarding page 2: "What should we remember?"
///
/// Five life categories, each a wrap of pill chips — tap all that apply. The
/// commonest picks arrive already selected, so the page reads as "yes, that's
/// me" rather than a form. One line of copy, one button, nothing else.
class ChipSelectScreen extends StatefulWidget {
  const ChipSelectScreen({
    super.key,
    required this.onContinue,
    this.onBack,
  });

  /// Fires with a draft per selected chip when the user taps Continue.
  final ValueChanged<Map<String, ReminderDraft>> onContinue;
  final VoidCallback? onBack;

  @override
  State<ChipSelectScreen> createState() => _ChipSelectScreenState();
}

class _ChipSelectScreenState extends State<ChipSelectScreen> {
  final Set<String> _selected = {
    for (final s in kOnboardingChipSections)
      for (final i in s.items)
        if (i.preselected) i.key,
  };

  void _toggle(OnboardingChipItem item) {
    HapticFeedback.lightImpact();
    setState(() {
      _selected.contains(item.key)
          ? _selected.remove(item.key)
          : _selected.add(item.key);
    });
  }

  Map<String, ReminderDraft> _drafts() => {
        for (final s in kOnboardingChipSections)
          for (final i in s.items)
            if (_selected.contains(i.key))
              i.key: ReminderDraft(
                name: i.defaultName,
                day: i.defaultDay,
                frequency: i.defaultFrequency,
              ),
      };

  @override
  Widget build(BuildContext context) {
    final n = _selected.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.inkSoft,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
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
                            selected: _selected.contains(i.key),
                            onTap: () => _toggle(i),
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
              ),
            ),
            // Bottom action.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => widget.onContinue(_drafts()),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    n == 0 ? 'Skip for now' : 'Continue with $n',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});
  final OnboardingChipSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Icon(section.icon, size: 18, color: section.color),
          const SizedBox(width: 8),
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

/// One pill chip. Unselected it's a quiet white pill; selected it tints with
/// the section colour and its icon morphs into a check.
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
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.10) : AppColors.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.55) : AppColors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    selected ? Icons.check_rounded : item.icon,
                    key: ValueKey(selected),
                    size: 16,
                    color: selected ? color : AppColors.inkFaint,
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
