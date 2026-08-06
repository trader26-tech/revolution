import '../../tasks/domain/task.dart';

/// A single dated appearance of a task on the calendar. A one-off task has one;
/// a recurring task has many (its due date repeated forward).
class Occurrence {
  const Occurrence({required this.task, required this.date});

  final Task task;

  /// The date this occurrence falls on (date-only, time stripped for grouping).
  final DateTime date;
}

/// Expands the store's scheduled tasks into concrete dated occurrences within
/// [from]..[to] (inclusive). Recurring tasks are stepped forward by their
/// cadence; one-offs appear once if their date is in range.
///
/// Capped per task so a daily task over a huge range can't explode.
List<Occurrence> expandOccurrences(
  List<Task> tasks, {
  required DateTime from,
  required DateTime to,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  final out = <Occurrence>[];

  for (final t in tasks) {
    final due = t.dueAt;
    if (due == null) continue;
    var d = DateTime(due.year, due.month, due.day);

    if (t.repeat == RepeatCadence.none) {
      if (!d.isBefore(start) && !d.isAfter(end)) {
        out.add(Occurrence(task: t, date: d));
      }
      continue;
    }

    // For a repeating task, fast-forward the first occurrence to at/after the
    // window start, then step until we pass the end.
    var guard = 0;
    while (d.isBefore(start) && guard < 5000) {
      d = _next(d, t.repeat);
      guard++;
    }
    while (!d.isAfter(end) && guard < 5000) {
      out.add(Occurrence(task: t, date: d));
      d = _next(d, t.repeat);
      guard++;
    }
  }

  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// The next occurrence strictly after [date] for a [cadence]. Used by the day
/// sheet to show "Renews in N days · <date>" — the upcoming renewal, not the one
/// on the tapped day. For a non-repeating item this just returns [date].
DateTime nextOccurrenceAfter(DateTime date, RepeatCadence cadence) {
  if (cadence == RepeatCadence.none) return date;
  return _next(DateTime(date.year, date.month, date.day), cadence);
}

DateTime _next(DateTime d, RepeatCadence r) {
  switch (r) {
    case RepeatCadence.daily:
      return d.add(const Duration(days: 1));
    case RepeatCadence.weekly:
      return d.add(const Duration(days: 7));
    case RepeatCadence.monthly:
      return DateTime(d.year, d.month + 1, d.day);
    case RepeatCadence.yearly:
      return DateTime(d.year + 1, d.month, d.day);
    case RepeatCadence.none:
      return d; // unreachable
  }
}

/// Groups occurrences by their date (date-only key).
Map<DateTime, List<Occurrence>> groupByDay(List<Occurrence> occ) {
  final map = <DateTime, List<Occurrence>>{};
  for (final o in occ) {
    map.putIfAbsent(o.date, () => []).add(o);
  }
  return map;
}

/// A month's worth of occurrences, already split into date sub-groups. Used by
/// the home "monthly agenda" — one [MonthSection] per calendar month, each
/// holding its days in order and every day's occurrences in time order.
class MonthSection {
  MonthSection({required this.month, required this.days});

  /// First day of the month (date-only) — the section's stable key.
  final DateTime month;

  /// The days in this month that have occurrences, ascending, each with its
  /// occurrences (already time-sorted).
  final List<DaySection> days;

  int get total => days.fold(0, (n, d) => n + d.occurrences.length);
}

/// One day inside a [MonthSection].
class DaySection {
  DaySection({required this.date, required this.occurrences});

  final DateTime date; // date-only
  final List<Occurrence> occurrences;
}

/// Groups occurrences into ordered [MonthSection]s (each with ordered
/// [DaySection]s). Input need not be pre-sorted. Within a day, occurrences are
/// ordered by their task's due time, then title, so the agenda reads top-down.
List<MonthSection> groupByMonth(List<Occurrence> occ) {
  // month-start -> (day-start -> occurrences)
  final months = <DateTime, Map<DateTime, List<Occurrence>>>{};
  for (final o in occ) {
    final m = DateTime(o.date.year, o.date.month);
    final d = DateTime(o.date.year, o.date.month, o.date.day);
    months.putIfAbsent(m, () => {}).putIfAbsent(d, () => []).add(o);
  }

  final monthKeys = months.keys.toList()..sort();
  return [
    for (final mk in monthKeys)
      MonthSection(
        month: mk,
        days: () {
          final dayKeys = months[mk]!.keys.toList()..sort();
          return [
            for (final dk in dayKeys)
              DaySection(
                date: dk,
                occurrences: months[mk]![dk]!
                  ..sort((a, b) {
                    final at = a.task.dueAt, bt = b.task.dueAt;
                    // Both scheduled → by time; else keep stable by title.
                    if (at != null && bt != null) {
                      final byTime = at.compareTo(bt);
                      if (byTime != 0) return byTime;
                    }
                    return a.task.title
                        .toLowerCase()
                        .compareTo(b.task.title.toLowerCase());
                  }),
              ),
          ];
        }(),
      ),
  ];
}
