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
    });

    test('a "yes" adds items, a "no" adds nothing, no duplicates', () {
      final c = OnboardingController();
      c.answer(kQuiz[0], yes: true);
      final afterFirst = c.count;
      expect(afterFirst, greaterThan(0));

      c.answer(kQuiz[1], yes: false); // no-op
      expect(c.count, afterFirst);

      // Answering the same question yes again must not double-count.
      c.answer(kQuiz[0], yes: true);
      expect(c.count, afterFirst);
    });
  });

  testWidgets('walks Welcome → quiz taps → Reveal', (tester) async {
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

    // Welcome: just Pip + a title + Start.
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await advance();

    // Answer each quiz question with a single tap; the flow auto-advances.
    for (final q in kQuiz) {
      expect(find.text(q.prompt), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await advance();
    }

    // Reveal: the finish CTA, two-line message, no item list.
    expect(find.text('Let’s go'), findsOneWidget);
    expect(doneCalled, isFalse);

    // Let the count-up animation finish.
    await tester.pump(const Duration(seconds: 2));
  });
}
