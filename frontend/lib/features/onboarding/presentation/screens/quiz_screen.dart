import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_quiz.dart';

/// Screen 2 — a light quiz. "What do you juggle?" with tappable chips the user
/// can multi-select. Their picks drive the personalised numbers on screen 3.
class QuizScreen extends StatelessWidget {
  const QuizScreen({
    super.key,
    required this.picked,
    required this.onToggle,
  });

  final Set<String> picked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'What do you\njuggle?',
            style: text.displaySmall?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap all that apply — we’ll do the remembering.',
            style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final o in kQuizOptions)
                    _Chip(
                      option: o,
                      selected: picked.contains(o.key),
                      onTap: () => onToggle(o.key),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final QuizOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = option.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.14) : AppColors.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? c : AppColors.cardBorder,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? c : AppColors.ink,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 18, color: c),
            ],
          ],
        ),
      ),
    );
  }
}
