import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/features/calendar/calendar_page.dart';
import 'package:revolution/features/tasks/data/task_store.dart';
import 'package:revolution/features/tasks/domain/task.dart';

class _FakeStore extends TaskStore {
  final List<Task> _t;
  _FakeStore(this._t);
  @override
  List<Task> get tasks => _t;
}

void main() {
  testWidgets('calendar month grid renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 720 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final tasks = [
      for (var i = 1; i <= 20; i++)
        Task(id: '$i', title: 'Item $i',
            dueAt: DateTime(now.year, now.month, (i % 28) + 1)),
    ];

    final overflows = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        overflows.add(d.exceptionAsString());
      } else { old?.call(d); }
    };

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: CalendarPage(store: _FakeStore(tasks))),
    ));
    await tester.pump();

    FlutterError.onError = old;
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });
}
