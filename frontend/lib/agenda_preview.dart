// Throwaway preview: the month-grouped Home agenda with seeded tasks
// (one-offs + recurring), no backend. Run: flutter run -t lib/agenda_preview.dart
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';
import 'features/tasks/data/task_store.dart';
import 'features/tasks/domain/task.dart';

/// A TaskStore that serves in-memory seed data instead of hitting the server.
class _SeedStore extends TaskStore {
  @override
  Future<void> load() async {}

  @override
  List<Task> get tasks => _seed;
}

DateTime _at(int year, int month, int day, [int h = 9, int m = 0]) =>
    DateTime(year, month, day, h, m);

final _now = DateTime.now();
final _y = _now.year;

final List<Task> _seed = [
  Task(id: '1', title: 'Passport renewal', dueAt: _at(_y, _now.month, 12)),
  Task(id: '2', title: 'Car insurance', dueAt: _at(_y, _now.month, 28)),
  Task(
      id: '3',
      title: 'Electricity bill',
      dueAt: _at(_y, _now.month, 3, 10),
      repeat: RepeatCadence.monthly),
  Task(
      id: '4',
      title: 'Rent',
      dueAt: _at(_y, _now.month, 1, 8),
      repeat: RepeatCadence.monthly),
  Task(id: '5', title: 'SIP investment', dueAt: _at(_y, _now.month + 1, 15)),
  Task(id: '6', title: 'Driving license', dueAt: _at(_y, _now.month + 1, 22)),
  Task(id: '7', title: 'Health insurance', dueAt: _at(_y, _now.month + 2, 9)),
  Task(id: '8', title: 'Property tax', dueAt: _at(_y, _now.month + 4, 5)),
  Task(id: '9', title: 'Buy a gift', done: false), // unscheduled
];

void main() => runApp(_App());

class _App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = _SeedStore();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: HomePage(store: store),
      ),
    );
  }
}
