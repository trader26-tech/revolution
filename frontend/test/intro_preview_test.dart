import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/core/widgets/starfield.dart';
import 'package:revolution/features/onboarding/presentation/screens/intro_screen.dart';

void main() {
  testWidgets('intro preview', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(
        backgroundColor: AppColors.bg,
        body: Starfield(child: SafeArea(child: IntroScreen())),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1600));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(IntroScreen),
        matchesGoldenFile('intro_preview.png'));
  });
}
