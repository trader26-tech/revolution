import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';
import 'bamboo_background.dart';

/// The common skeleton for every onboarding screen — the source of the "one
/// calm idea per screen" feel: bamboo backdrop, a roomy centred content area,
/// an optional Skip, and a single full-width CTA pinned to the bottom.
///
/// Content never overflows: the middle is scrollable if a small screen can't
/// fit it, while the CTA stays put.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.content,
    this.cta,
    this.onCta,
    this.onSkip,
    this.footnote,
    this.busy = false,
  });

  /// The centred hero content (mascot, headline, list…).
  final Widget content;

  /// Full-width primary button label. Null hides the button.
  final String? cta;
  final VoidCallback? onCta;

  /// Optional top-right Skip.
  final VoidCallback? onSkip;

  /// Optional tiny grey line above the CTA (e.g. a source or reassurance).
  final String? footnote;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return BambooBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Skip row (kept even when empty so layout is stable).
            SizedBox(
              height: 52,
              child: onSkip == null
                  ? null
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: TextButton(
                          onPressed: onSkip,
                          style: TextButton.styleFrom(
                            foregroundColor: Bamboo.inkSoft,
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  child: Center(child: content),
                ),
              ),
            ),
            if (footnote != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
                child: Text(
                  footnote!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Bamboo.inkSoft,
                      ),
                ),
              ),
            if (cta != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : onCta,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(cta!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
