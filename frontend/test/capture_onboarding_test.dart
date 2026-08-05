import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/features/onboarding/domain/quiz.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_controller.dart';
import 'package:revolution/features/onboarding/presentation/steps/quiz_step.dart';
import 'package:revolution/features/onboarding/presentation/steps/reveal_step.dart';
import 'package:revolution/features/onboarding/presentation/steps/stat_step.dart';
import 'package:revolution/features/onboarding/presentation/steps/welcome_step.dart';

/// Renders each onboarding step to a PNG under build/shots/ so the design can
/// be eyeballed without a device. Not an assertion test — a capture harness.
void main() {
  Future<void> shot(WidgetTester tester, String name, Widget child) async {
    tester.view.physicalSize = const Size(390, 844); // iPhone 14-ish
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: child),
    );
    await tester.pump(const Duration(milliseconds: 1300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
  }

  testWidgets('capture', (tester) async {
    final c = OnboardingController();
    for (final q in kQuiz) {
      c.answer(q, yes: true);
    }

    await shot(tester, 'welcome', WelcomeStep(onStart: () {}));
    await shot(tester, 'stat', StatStep(onNext: () {}));
    await shot(
      tester,
      'quiz',
      QuizStep(question: kQuiz[0], controller: c, onAnswered: () {}),
    );
    await shot(
      tester,
      'reveal',
      RevealStep(controller: c, onFinish: () {}),
    );
  });
}
