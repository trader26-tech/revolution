import 'package:flutter/material.dart';

import '../../domain/personas.dart';
import '../onboarding_controller.dart';
import '../widgets/persona_card.dart';
import 'pick_scaffold.dart';

/// Tap 1 (required) — "Which of these are you?". One tap selects a primary
/// persona and enables the CTA.
class PrimaryPickStep extends StatelessWidget {
  const PrimaryPickStep({
    super.key,
    required this.controller,
    required this.onNext,
  });

  final OnboardingController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return PickScaffold(
          stepLabel: 'STEP 1 OF 2',
          title: 'Which of these is you?',
          subtitle: 'Pick the one that fits best. You can always add more later.',
          ctaLabel: 'Continue',
          ctaEnabled: controller.hasPrimary,
          onCta: onNext,
          children: [
            for (final p in kPrimaryPersonas)
              PersonaCard(
                persona: p,
                selected: controller.primary?.key == p.key,
                onTap: () => controller.selectPrimary(p),
              ),
          ],
        );
      },
    );
  }
}
