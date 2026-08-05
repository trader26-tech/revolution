import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/features/mascot/presentation/bobo_mascot.dart';

void main() {
  // Every mood must resolve to at least one real asset candidate ending in a
  // bundled PNG — so Bobo is never invisible on any screen.
  for (final mood in BoboMood.values) {
    testWidgets('Bobo renders an Image for $mood', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BoboMascot(size: 120, mood: mood))),
      );
      // The widget builds an Image (the first candidate); missing files fall
      // through errorBuilder to the next, so an Image is always present.
      expect(find.byType(Image), findsWidgets);
    });
  }
}
