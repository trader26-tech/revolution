import 'package:flutter/material.dart';

import '../../../panda/presentation/panda_mascot.dart';

/// Step 0 — the hook. Before asking for anything, tell the user why this
/// exists, in one sentence they feel in their gut: life admin is a hundred
/// tiny deadlines, and forgetting one costs money or stress.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const PandaMascot(size: 200, mood: PandaMood.happy),
                  const Spacer(),
          Text(
            'Life has a hundred\ntiny deadlines.',
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Insurance that lapses. A licence that expires. '
            'A birthday you meant to remember.\n\n'
            'Tell me two things about you, and I’ll take it from here — '
            'and I’ll call you a week before anything is due.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Spacer(flex: 2),
          _PrimaryButton(
            label: 'Show me how',
            onPressed: onStart,
          ),
          const SizedBox(height: 8),
          Text(
            'Takes 15 seconds. Just two taps.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
