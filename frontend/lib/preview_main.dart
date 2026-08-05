// Throwaway preview of the welcome hero. Not shipped.
// Build: flutter build web -t lib/preview_main.dart
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/steps/welcome_step.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: WelcomeStep(onStart: () {}),
    );
  }
}
