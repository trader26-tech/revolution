import 'package:flutter_test/flutter_test.dart';

import 'package:revolution/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const RevolutionApp());

    expect(find.text('Revolution'), findsOneWidget);
    expect(find.text('Ping backend /health'), findsOneWidget);
  });
}
