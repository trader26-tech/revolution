import 'package:flutter/material.dart';

/// Shared layout for the two "tap" steps: a step label, a big title, a
/// subtitle, a scrollable list of choices, and a bottom CTA that only lights
/// up once a valid choice is made.
class PickScaffold extends StatelessWidget {
  const PickScaffold({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.ctaLabel,
    required this.ctaEnabled,
    required this.onCta,
    this.onSkip,
  });

  final String stepLabel;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String ctaLabel;
  final bool ctaEnabled;
  final VoidCallback onCta;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepLabel,
                style: text.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => children[i],
          ),
        ),
        _Footer(
          ctaLabel: ctaLabel,
          ctaEnabled: ctaEnabled,
          onCta: onCta,
          onSkip: onSkip,
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.ctaLabel,
    required this.ctaEnabled,
    required this.onCta,
    required this.onSkip,
  });

  final String ctaLabel;
  final bool ctaEnabled;
  final VoidCallback onCta;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: ctaEnabled ? onCta : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(ctaLabel),
            ),
          ),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip — that’s enough'),
            ),
        ],
      ),
    );
  }
}
