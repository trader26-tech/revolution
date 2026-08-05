import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revolution/features/onboarding/domain/personas.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_controller.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_flow.dart';

void main() {
  group('OnboardingController', () {
    test('needs a primary before it resolves any items', () {
      final c = OnboardingController();
      expect(c.hasPrimary, isFalse);
      expect(c.resolvedItems, isEmpty);
    });

    test('primary + add-on resolves a de-duplicated item set', () {
      final c = OnboardingController();
      c.selectPrimary(kPrimaryPersonas.first); // driver
      final primaryCount = c.resolvedItems.length;
      expect(primaryCount, greaterThan(0));

      // The "I ride a bike" add-on shares pollution_certificate + service with
      // the driver persona, so the union must not double-count them.
      final bikeAddon =
          kAddonPersonas.firstWhere((p) => p.key == 'add_bike');
      c.toggleAddon(bikeAddon);

      final keys = c.resolvedItems.map((i) => i.key).toList();
      expect(keys.toSet().length, keys.length, reason: 'no duplicates');
      expect(keys, contains('bike_insurance'));

      // Toggling the same add-on off clears it.
      c.toggleAddon(bikeAddon);
      expect(c.addon, isNull);
      expect(c.resolvedItems.length, primaryCount);
    });
  });

  testWidgets('flow reaches the reveal after two taps', (tester) async {
    var doneCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          onDone: () async => doneCalled = true,
        ),
      ),
    );

    // Pip's idle animation never settles, so advance with bounded pumps
    // rather than pumpAndSettle (which would time out).
    Future<void> advance() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    }

    // Welcome step.
    expect(find.text('Show me how'), findsOneWidget);
    await tester.tap(find.text('Show me how'));
    await advance();

    // Step 1: pick the first primary persona, then continue.
    expect(find.text('Which of these is you?'), findsOneWidget);
    await tester.tap(find.text(kPrimaryPersonas.first.label));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await advance();

    // Step 2: skip the optional add-on.
    expect(find.text('Anything else?'), findsOneWidget);
    await tester.tap(find.text('Show my plan'));
    await advance();

    // Reveal step shows the finish CTA.
    expect(find.text('Start tracking these'), findsOneWidget);
    expect(doneCalled, isFalse);

    // Let the reveal's count-up animation (1500ms) finish.
    await tester.pump(const Duration(seconds: 2));
  });
}
