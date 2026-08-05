import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revolution/features/onboarding/domain/quiz.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_controller.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_flow.dart';

void main() {
  group('OnboardingController', () {
    test('starts empty', () {
      final c = OnboardingController();
      expect(c.count, 0);
      expect(c.resolvedItems, isEmpty);
      expect(c.hasAny, isFalse);
    });

    test('toggling a row selects then clears it', () {
      final c = OnboardingController();
      c.toggle(kQuiz[0]);
      expect(c.isSelected(kQuiz[0]), isTrue);
      expect(c.count, greaterThan(0));

      c.toggle(kQuiz[0]);
      expect(c.isSelected(kQuiz[0]), isFalse);
      expect(c.count, 0);
    });

    test('multiple rows union their items without duplicates', () {
      final c = OnboardingController()
        ..toggle(kQuiz[0])
        ..toggle(kQuiz[1]);
      final keys = c.resolvedItems.map((i) => i.key).toList();
      expect(keys.toSet().length, keys.length, reason: 'no duplicates');
      expect(c.count, keys.length);
    });
  });

  testWidgets('walks Welcome → Stat → Checklist → Reveal', (tester) async {
    var doneCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(onDone: () async => doneCalled = true),
      ),
    );

    Future<void> advance() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Welcome → stat.
    expect(find.text('Meet Bobo'), findsOneWidget);
    await tester.tap(find.text('Meet Bobo'));
    await advance();

    // Stat framing screen → checklist.
    expect(find.text('That’s me'), findsOneWidget);
    await tester.tap(find.text('That’s me'));
    await advance();

    // Checklist: one screen, tick a couple of rows, then continue.
    expect(find.text('Which of these\nare you?'), findsOneWidget);
    await tester.tap(find.text(kQuiz[0].prompt));
    await tester.tap(find.text(kQuiz[2].prompt));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await advance();

    // Reveal: finish CTA present, not yet finished.
    expect(find.text('Let’s go'), findsOneWidget);
    expect(doneCalled, isFalse);

    // Let the count-up animation finish.
    await tester.pump(const Duration(seconds: 2));
  });
}
