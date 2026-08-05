import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revolution/features/onboarding/domain/quiz.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_flow.dart';

/// Guards the exact bug reported: tapping through onboarding overflowed on a
/// phone-sized screen. We drive the whole flow on a small 360×640 surface and
/// fail if any step throws a layout/overflow exception.
void main() {
  testWidgets('no overflow on a small phone screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(onDone: () async {}),
      ),
    );

    Future<void> advance() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('Meet Bobo'));
    await advance();

    await tester.tap(find.text('That’s me'));
    await advance();

    // Checklist screen — select every row (worst case for height). Scroll each
    // into view first, like a real user; ensureVisible throws if a row can't be
    // reached, catching any layout that traps content off-screen.
    for (final q in kQuiz) {
      await tester.ensureVisible(find.text(q.prompt));
      await tester.pump();
      await tester.tap(find.text(q.prompt));
    }
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await advance();

    expect(find.text('Let’s go'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    // Any RenderFlex overflow throws and is captured here.
    expect(tester.takeException(), isNull);
  });
}
