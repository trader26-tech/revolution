import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/widgets/starfield.dart';
import 'package:revolution/features/onboarding/presentation/screens/chip_select_screen.dart';
import 'package:revolution/features/onboarding/presentation/widgets/reminder_confirm_sheet.dart';

void main() {
  testWidgets('page2 chips: render, toggle, preselected, Continue', (tester) async {
    final picked = preselectedChipKeys();
    expect(picked, isNotEmpty, reason: 'some chips preselected');
    Map<String, ReminderDraft>? completed;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Starfield(
      child: ChipSelectWizard(
        picked: picked,
        onToggle: (k) => picked.contains(k) ? picked.remove(k) : picked.add(k),
        onComplete: (d) => completed = d,
      ),
    ))));
    await tester.pump(const Duration(seconds: 2));

    // Chips wrap under sections — tap a known label to toggle.
    final netflix = find.text('Netflix');
    expect(netflix, findsWidgets, reason: 'chip label present');
    await tester.tap(netflix.first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);

    // Continue fires drafts.
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(completed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
