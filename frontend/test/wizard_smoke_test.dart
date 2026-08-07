import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_flow.dart';

void main() {
  testWidgets('walk intro→categories→payoff, no exceptions', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OnboardingFlow(onDone: () {})));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Continue through the 5 categories.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 4)); // let cascade finish
      final cont = find.text('Continue');
      final finish = find.text('Finish');
      final none = find.text('None of these');
      final target = tester.any(cont)
          ? cont
          : tester.any(finish)
              ? finish
              : none;
      await tester.tap(target, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final ex = tester.takeException();
      if (ex != null) {
        // ignore: avoid_print
        print('EXCEPTION at category $i: $ex');
        rethrowIfNeeded(ex);
      }
    }
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}

void rethrowIfNeeded(Object ex) {
  throw ex;
}
