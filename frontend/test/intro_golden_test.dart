import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_flow.dart';

void main() {
  testWidgets('intro golden', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const OnboardingFlow(),
    ));
    await tester.pump(const Duration(milliseconds: 1600));
    await expectLater(
      find.byType(OnboardingFlow),
      matchesGoldenFile('intro_preview.png'),
    );
  });
}
