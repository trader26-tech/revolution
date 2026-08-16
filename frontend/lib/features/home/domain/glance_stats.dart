import '../../details/domain/currency.dart' show toInr;
import '../../tasks/domain/task.dart';
import '../presentation/collection_page.dart' show nextOccurrence;

/// An app-wide "at a glance" summary of the user's reminders + spend, computed
/// once from all tasks. Every number here already existed somewhere in the app
/// (per-category hero stats, the chat's query engine) — this just aggregates them
/// across the WHOLE account so the ★ can surface them in one look.
class GlanceStats {
  const GlanceStats({
    required this.monthlyInr,
    required this.overdue,
    required this.thisWeek,
    required this.thisWeekInr,
    required this.nextTask,
    required this.nextDate,
    required this.totalTracked,
  });

  /// Combined monthly spend across ALL tasks, every currency folded into ₹.
  final double monthlyInr;

  /// Reminders that are past due and not done (soonest-overdue first).
  final List<Task> overdue;

  /// Reminders whose next occurrence falls within the next 7 days (soonest first).
  final List<Task> thisWeek;

  /// Sum of this-week amounts (as billed — a rough ₹ heads-up, not normalised).
  final double thisWeekInr;

  /// The single soonest upcoming reminder + its date (null when nothing's due).
  final Task? nextTask;
  final DateTime? nextDate;

  /// Total number of reminders tracked (drives the empty state).
  final int totalTracked;

  bool get isEmpty => totalTracked == 0;

  /// Build the glance from the full task list.
  factory GlanceStats.from(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    var monthly = 0.0;
    final overdue = <Task>[];
    final week = <Task>[];
    var weekInr = 0.0;
    DateTime? nextDate;
    Task? nextTask;

    for (final t in tasks) {
      if (t.done) continue;

      // Monthly-equivalent spend, all currencies → ₹.
      if (t.hasAmount) {
        final perMonth = _toMonthly(t.amount!, t.repeat, t.repeatTimes);
        monthly += toInr(perMonth, t.currency);
      }

      if (!t.isScheduled) continue;

      // Overdue: the ORIGINAL due date is in the past (a recurring item that has
      // rolled forward isn't overdue — nextOccurrence would be today/future).
      final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      if (due.isBefore(today)) {
        overdue.add(t);
      }

      // This week + the soonest-upcoming, via the shared recurrence roll-forward.
      final occ = nextOccurrence(t, from: today);
      if (!occ.isBefore(today) && occ.isBefore(weekEnd)) {
        week.add(t);
        if (t.hasAmount) weekInr += t.amount!;
      }
      if (!occ.isBefore(today) && (nextDate == null || occ.isBefore(nextDate))) {
        nextDate = occ;
        nextTask = t;
      }
    }

    overdue.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    week.sort((a, b) =>
        nextOccurrence(a, from: today).compareTo(nextOccurrence(b, from: today)));

    return GlanceStats(
      monthlyInr: monthly,
      overdue: overdue,
      thisWeek: week,
      thisWeekInr: weekInr,
      nextTask: nextTask,
      nextDate: nextDate,
      totalTracked: tasks.length,
    );
  }
}

/// A rough monthly-equivalent of one payment, given "every [n] [unit]". Ported
/// verbatim from collection_page's per-category hero math so the app-wide total
/// uses the exact same normalisation (a one-off counts at face value).
double _toMonthly(double amount, RepeatCadence r, int times) {
  final n = times < 1 ? 1 : times;
  final perMonth = switch (r) {
    RepeatCadence.minute => 30 * 24 * 60,
    RepeatCadence.hour => 30 * 24,
    RepeatCadence.daily => 30,
    RepeatCadence.weekly => 52 / 12,
    RepeatCadence.monthly => 1,
    RepeatCadence.yearly => 1 / 12,
    RepeatCadence.none => 1,
  };
  return amount * perMonth / n;
}
