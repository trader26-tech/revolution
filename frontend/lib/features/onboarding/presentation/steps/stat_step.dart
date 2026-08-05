import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';
import '../../../mascot/presentation/bobo_mascot.dart';
import '../widgets/onboarding_scaffold.dart';

/// The framing beat — makes the mental load feel real before we solve it.
/// Orbit's "we overspend ₹X" screen, re-aimed at forgetting instead of money.
class StatStep extends StatelessWidget {
  const StatStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return OnboardingScaffold(
      cta: 'That’s me',
      onCta: onNext,
      footnote: 'Bills, renewals, insurance, birthdays, services…',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'We each juggle\n'),
                TextSpan(
                  text: '30+ deadlines',
                  style: TextStyle(color: Bamboo.green),
                ),
                const TextSpan(text: '\na year — in our heads.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: text.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: Bamboo.ink,
            ),
          ),
          const SizedBox(height: 40),
          const BoboMascot(size: 120, mood: BoboMood.sleepy),
        ],
      ),
    );
  }
}
