// Throwaway preview: the 3 onboarding screens side by side. Not shipped.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/screens/benefits_screen.dart';
import 'features/onboarding/presentation/screens/intro_screen.dart';
import 'features/onboarding/presentation/screens/quiz_screen.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    final picked = {'bills', 'subscriptions', 'insurance'};
    Widget frame(Widget child) => Container(
          margin: const EdgeInsets.all(10),
          width: 300,
          height: 640,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(child: child),
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: const Color(0xFFE3E5E9),
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            frame(const IntroScreen()),
            frame(QuizScreen(picked: picked, onToggle: (_) {})),
            frame(BenefitsScreen(picked: picked)),
          ]),
        ),
      ),
    );
  }
}
