import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/features/reminders/domain/daily_digest.dart';
import 'package:revolution/features/tasks/domain/task.dart';

Task _task(
  String id,
  String title, {
  DateTime? dueAt,
  RepeatCadence repeat = RepeatCadence.none,
  bool done = false,
  bool reminderOn = true,
  double? amount,
  String currency = 'INR',
}) =>
    Task(
      id: id,
      title: title,
      dueAt: dueAt,
      repeat: repeat,
      done: done,
      reminderOn: reminderOn,
      amount: amount,
      currency: currency,
    );

void main() {
  final day = DateTime(2026, 8, 7); // a Friday

  group('buildDailyDigest', () {
    test('returns null when nothing is due — no notification that day', () {
      expect(buildDailyDigest([], day), isNull);
      expect(
        buildDailyDigest(
            [_task('1', 'Elsewhere', dueAt: DateTime(2026, 8, 9))], day),
        isNull,
      );
    });

    test('one digest covers everything due that day', () {
      final digest = buildDailyDigest([
        _task('1', 'Netflix',
            dueAt: DateTime(2026, 8, 7, 9), amount: 649, currency: 'INR'),
        _task('2', 'Gym', dueAt: DateTime(2026, 8, 7, 18)),
        _task('3', 'Not today', dueAt: DateTime(2026, 8, 8)),
      ], day)!;

      expect(digest.count, 2);
      expect(digest.title, '2 things due today');
      expect(digest.lines, ['Netflix — ₹649', 'Gym']);
    });

    test('single item gets a headline naming it', () {
      final digest = buildDailyDigest(
          [_task('1', 'Netflix', dueAt: DateTime(2026, 8, 7))], day)!;
      expect(digest.title, 'Due today: Netflix');
    });

    test('skips done tasks and reminder-off tasks', () {
      final digest = buildDailyDigest([
        _task('1', 'Done already', dueAt: DateTime(2026, 8, 7), done: true),
        _task('2', 'Muted', dueAt: DateTime(2026, 8, 7), reminderOn: false),
        _task('3', 'Live', dueAt: DateTime(2026, 8, 7)),
      ], day)!;
      expect(digest.lines, ['Live']);
    });

    test('recurring tasks appear on their recurrence days', () {
      final digest = buildDailyDigest([
        // Monthly on the 7th, started months earlier.
        _task('1', 'Rent',
            dueAt: DateTime(2026, 5, 7),
            repeat: RepeatCadence.monthly,
            amount: 25000),
      ], day)!;
      expect(digest.lines, ['Rent — ₹25,000']);
      // Recurring ids are never bulk-completed by the tray action.
      expect(digest.oneOffIds, isEmpty);
      expect(digest.recurringIds, ['1']);
    });

    test('amounts format per currency, decimals only when needed', () {
      final digest = buildDailyDigest([
        _task('1', 'Spotify',
            dueAt: DateTime(2026, 8, 7), amount: 1.99, currency: 'USD'),
        _task('2', 'Lakh',
            dueAt: DateTime(2026, 8, 7), amount: 122484, currency: 'INR'),
      ], day)!;
      expect(digest.lines, containsAll(['Spotify — \$1.99', 'Lakh — ₹1,22,484']));
    });

    test('payload round-trips through the notification', () {
      final digest = buildDailyDigest([
        _task('1', 'Netflix', dueAt: DateTime(2026, 8, 7), amount: 649),
        _task('2', 'Rent',
            dueAt: DateTime(2026, 8, 7), repeat: RepeatCadence.monthly),
      ], day)!;

      final back = DailyDigest.fromPayload(digest.toPayload())!;
      expect(back.date, digest.date);
      expect(back.title, digest.title);
      expect(back.lines, digest.lines);
      expect(back.oneOffIds, ['1']);
      expect(back.recurringIds, ['2']);

      expect(DailyDigest.fromPayload(null), isNull);
      expect(DailyDigest.fromPayload('not json'), isNull);
    });

    test('summary line stays tight for long days', () {
      final digest = buildDailyDigest([
        for (var i = 0; i < 5; i++)
          _task('$i', 'Task $i', dueAt: DateTime(2026, 8, 7, 8 + i)),
      ], day)!;
      expect(digest.summaryLine, 'Task 0  ·  Task 1  ·  +3 more');
    });
  });
}
