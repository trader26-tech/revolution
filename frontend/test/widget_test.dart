import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:revolution/features/onboarding/data/onboarding_store.dart';
import 'package:revolution/features/onboarding/presentation/onboarding_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gate shows home once onboarding is complete', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete_v1': true});

    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingGate(
          home: Scaffold(body: Center(child: Text('HOME'))),
          store: OnboardingStore(),
        ),
      ),
    );

    // Let the async first-run check resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('gate shows onboarding on first run', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingGate(
          home: Scaffold(body: Center(child: Text('HOME'))),
          store: OnboardingStore(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Onboarding welcome step, not home.
    expect(find.text('HOME'), findsNothing);
    expect(find.text('Meet Pip'), findsOneWidget);
  });
}
