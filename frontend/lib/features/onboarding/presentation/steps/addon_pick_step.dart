import 'package:flutter/material.dart';

import '../../domain/personas.dart';
import '../onboarding_controller.dart';
import '../widgets/persona_card.dart';
import 'pick_scaffold.dart';

/// Tap 2 (optional) — "Anything else?". One add-on broadens the set, or the
/// user skips. Either way the next stop is the reveal.
class AddonPickStep extends StatelessWidget {
  const AddonPickStep({
    super.key,
    required this.controller,
    required this.onReveal,
  });

  final OnboardingController controller;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasAddon = controller.addon != null;
        return PickScaffold(
          stepLabel: 'STEP 2 OF 2 · OPTIONAL',
          title: 'Anything else?',
          subtitle: 'One more tap to round it out — or skip straight ahead.',
          ctaLabel: hasAddon ? 'Show my plan' : 'Show my plan',
          ctaEnabled: true,
          onCta: onReveal,
          onSkip: hasAddon ? null : onReveal,
          children: [
            for (final p in kAddonPersonas)
              PersonaCard(
                persona: p,
                selected: controller.addon?.key == p.key,
                onTap: () => controller.toggleAddon(p),
              ),
          ],
        );
      },
    );
  }
}
