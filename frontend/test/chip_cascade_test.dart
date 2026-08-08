import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/widgets/starfield.dart';
import 'package:revolution/features/onboarding/presentation/screens/chip_select_screen.dart';

void main() {
  testWidgets('shimmer question + chips cascade in and are interactive', (tester) async {
    final picked = preselectedChipKeys();
    var toggles = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Starfield(
      child: ChipSelectWizard(
        picked: picked,
        onToggle: (_) => toggles++,
        onComplete: (_) {},
      ),
    ))));

    // The MagicText question renders its words.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('What'), findsWidgets);
    expect(find.textContaining('remember'), findsWidgets);

    // Let the full 3.2s entrance play out.
    await tester.pump(const Duration(milliseconds: 3600));
    expect(tester.takeException(), isNull);

    // A chip is fully in and tappable at the end.
    final netflix = find.text('Netflix');
    expect(netflix, findsWidgets);
    await tester.tap(netflix.first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(toggles, greaterThan(0), reason: 'chip is interactive after cascade');
    expect(tester.takeException(), isNull);
    debugPrint('>>> ok: toggles=$toggles');
  });
}
