import '../../tasks/domain/task.dart';
import '../presentation/collection_page.dart' show nextOccurrence;

/// One day's worth of upcoming reminders in the glance agenda.
class GlanceDay {
  const GlanceDay(this.date, this.tasks);
  final DateTime date; // the day (midnight)
  final List<Task> tasks; // that day's reminders, soonest first
}

/// The ★ GLANCE — a "what's coming up" agenda for a REMINDER app: everything due
/// in the next 7 days, grouped by day and ordered, plus anything overdue pinned
/// on top. Money is NOT the focus (it's just an optional per-item tail).
class GlanceStats {
  const GlanceStats({
    required this.overdue,
    required this.days,
    required this.totalTracked,
    required this.upcomingCount,
  });

  /// Past-due, not-done reminders (soonest-overdue first) — the urgent bucket.
  final List<Task> overdue;

  /// The next 7 days, each with its reminders (only days that have any).
  final List<GlanceDay> days;

  /// Total reminders tracked (drives the empty state).
  final int totalTracked;

  /// How many reminders fall in the next 7 days (across [days]).
  final int upcomingCount;

  bool get isEmpty => totalTracked == 0;
  bool get hasNothingSoon => overdue.isEmpty && days.isEmpty;

  /// Build the agenda from the full task list. [horizonDays] = how far ahead.
  factory GlanceStats.from(List<Task> tasks, {int horizonDays = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizonEnd = today.add(Duration(days: horizonDays));

    final overdue = <Task>[];
    // day (midnight) → that day's tasks
    final byDay = <DateTime, List<Task>>{};

    for (final t in tasks) {
      if (t.done || !t.isScheduled) continue;

      // Overdue: the original due date is before today (a recurring item that has
      // already rolled forward is NOT overdue — its next occurrence is future).
      final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      if (due.isBefore(today)) {
        overdue.add(t);
        continue; // an overdue item lives in the overdue bucket, not the agenda
      }

      // Upcoming within the horizon → bucket by its next-occurrence day.
      final occ = nextOccurrence(t, from: today);
      final occDay = DateTime(occ.year, occ.month, occ.day);
      if (!occDay.isBefore(today) && occDay.isBefore(horizonEnd)) {
        byDay.putIfAbsent(occDay, () => []).add(t);
      }
    }

    overdue.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    // Order the days, and within each day sort by time (tasks with a set time
    // first, in time order; date-only ones after).
    final dayKeys = byDay.keys.toList()..sort();
    final days = <GlanceDay>[];
    var upcoming = 0;
    for (final d in dayKeys) {
      final items = byDay[d]!
        ..sort((a, b) {
          final at = a.dueAt, bt = b.dueAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          // Compare only the time-of-day so recurring items sort sensibly.
          final am = at.hour * 60 + at.minute;
          final bm = bt.hour * 60 + bt.minute;
          return am.compareTo(bm);
        });
      upcoming += items.length;
      days.add(GlanceDay(d, items));
    }

    return GlanceStats(
      overdue: overdue,
      days: days,
      totalTracked: tasks.length,
      upcomingCount: upcoming,
    );
  }
}
