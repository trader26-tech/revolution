import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:revolution/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots into onboarding on first run', (tester) async {
    // No stored flag → first run.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const RevolutionApp());

    // The gate resolves the (async) first-run flag, then shows the welcome
    // step. A few fixed pumps let the SharedPreferences future complete; we
    // avoid pumpAndSettle because Pip's idle animation never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Show me how'), findsOneWidget);
  });
}
