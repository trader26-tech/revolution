import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/features/calendar/domain/occurrences.dart';
import 'package:revolution/features/tasks/domain/task.dart';

void main() {
  test('one-off task appears once, only if in range', () {
    final t = Task(id: '1', title: 'x', dueAt: DateTime(2026, 8, 20));
    final occ = expandOccurrences([t],
        from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));
    expect(occ.length, 1);
    expect(occ.first.date, DateTime(2026, 8, 20));
  });

  test('monthly task recurs across the window', () {
    final t = Task(id: '2', title: 'EMI',
        dueAt: DateTime(2026, 1, 5), repeat: RepeatCadence.monthly);
    final occ = expandOccurrences([t],
        from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));
    // Exactly one occurrence in August (the 5th).
    expect(occ.length, 1);
    expect(occ.first.date, DateTime(2026, 8, 5));
  });

  test('weekly task yields multiple occurrences in a month', () {
    final t = Task(id: '3', title: 'w',
        dueAt: DateTime(2026, 8, 3), repeat: RepeatCadence.weekly);
    final occ = expandOccurrences([t],
        from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));
    expect(occ.length, greaterThanOrEqualTo(4));
  });

  test('unscheduled tasks produce nothing', () {
    final t = Task(id: '4', title: 'no date');
    final occ = expandOccurrences([t],
        from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));
    expect(occ, isEmpty);
  });
}
