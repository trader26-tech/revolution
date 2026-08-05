import 'package:flutter/material.dart';

import '../../../panda/presentation/panda_mascot.dart';
import '../onboarding_controller.dart';

/// The payoff. Pip, one number, two lines. No lists.
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PandaMascot(size: 168, mood: PandaMood.excited),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final shown = (_anim.value * _count).round().clamp(0, _count);
              return Text(
                '$shown',
                style: text.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                  height: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Two lines. That's the whole message.
          Text(
            'things handled for you.\nI’ll call before each one.',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: widget.busy ? null : widget.onFinish,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Let’s go'),
            ),
          ),
        ],
      ),
    );
  }
}
