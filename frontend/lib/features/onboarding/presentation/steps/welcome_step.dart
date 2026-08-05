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
          const BoboMascot(size: 200, mood: BoboMood.waving),
          const SizedBox(height: 20),
          // The hero tag — a small pill that frames, in one glance, what Bobo is.
          const _HeroTag(),
          const SizedBox(height: 20),
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

/// A soft caramel pill that sits just under Bobo, naming what he is in a
/// glance — the hero's one-line meaning, as a crisp UI element.
class _HeroTag extends StatelessWidget {
  const _HeroTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Bamboo.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Bamboo.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🐾', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Text(
            'Your personal deadline keeper',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Bamboo.greenDeep,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
          ),
        ],
      ),
    );
  }
}
