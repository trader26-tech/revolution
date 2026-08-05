import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';
import '../../../mascot/presentation/bobo_mascot.dart';
import '../widgets/onboarding_scaffold.dart';

/// The hook — Bobo, one calm line, one button.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return OnboardingScaffold(
      cta: 'Meet Bobo',
      onCta: onStart,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BoboMascot(size: 200, mood: BoboMood.happy),
          const SizedBox(height: 32),
          Text(
            'Put it out\nof your head.',
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: Bamboo.ink,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bobo remembers every deadline for you.',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: Bamboo.inkSoft),
          ),
        ],
      ),
    );
  }
}
