import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';
import '../../../mascot/presentation/bobo_mascot.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// The payoff — one number, two lines, Bobo. The relief moment.
class RevealStep extends StatefulWidget {
  const RevealStep({
    super.key,
    required this.controller,
    required this.onFinish,
    this.busy = false,
  });

  final OnboardingController controller;
  final VoidCallback onFinish;
  final bool busy;

  @override
  State<RevealStep> createState() => _RevealStepState();
}

class _RevealStepState extends State<RevealStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.controller.count;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return OnboardingScaffold(
      cta: 'Let’s go',
      onCta: widget.onFinish,
      busy: widget.busy,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BoboMascot(size: 168, mood: BoboMood.excited),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final shown = (_anim.value * _count).round().clamp(0, _count);
              return Text(
                '$shown',
                style: text.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Bamboo.green,
                  height: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'things off your mind.\nPip will nudge you before each one.',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Bamboo.ink,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
