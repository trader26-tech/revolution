import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A slim segmented progress bar for the onboarding wizard — one segment per
/// step, filling left-to-right as the user advances. Sits at the very top so
/// the user always knows how far along they are and how much is left.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.step,
    required this.total,
    this.accent = AppColors.accent,
  });

  /// Zero-based index of the current step.
  final int step;

  /// Total number of steps.
  final int total;

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i <= step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              height: 6,
              decoration: BoxDecoration(
                color: done ? accent : AppColors.cardBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}
