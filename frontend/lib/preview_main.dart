// Throwaway preview: bill-statement style intro cards. Not shipped.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/screens/intro_screen.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: SizedBox(width: 393, child: SafeArea(child: IntroScreen())),
        ),
      ),
    );
  }
}
