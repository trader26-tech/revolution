import 'package:flutter/material.dart';

import '../../../panda/presentation/panda_mascot.dart';

/// The hook. Pip, four words, one button. Nothing to read.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PandaMascot(size: 200, mood: PandaMood.happy),
          const SizedBox(height: 28),
          Text(
            'PULLED FROM GITHUB ✅',
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}
