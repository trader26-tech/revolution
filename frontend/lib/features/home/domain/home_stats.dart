import '../../tasks/domain/task.dart';

/// The at-a-glance numbers the Home hero shows — computed once from the task
/// list so the header, hero card, and category cards all read from one source.
class HomeStats {
  const HomeStats({
    required this.total,
    required this.dueToday,
    required this.dueThisMonth,
    required this.overdue,
    required this.documents,
    required this.monthSpend,
    required this.currency,
    required this.byCategory,
    required this.upNext,
  });

  /// Every reminder tracked.
  final int total;

  /// Unfinished reminders due today.
  final int dueToday;

  /// Unfinished reminders due at any point this calendar month (incl. today,
  /// incl. ones already overdue-this-month).
  final int dueThisMonth;

  /// Overdue & not done.
  final int overdue;

  /// Reminders that have a document/photo attached.
  final int documents;

  /// Sum of amounts on items due this month (the "money due" figure).
  final double monthSpend;

  /// Currency of the spend total (from the commonest task currency).
  final String currency;

  /// Task count per category, only categories that have at least one.
  final Map<TaskCategory, int> byCategory;

  /// The soonest upcoming scheduled, unfinished reminders (today onward),
  /// nearest first — for the "Up Next" cards.
  final List<Task> upNext;

  bool get isEmpty => total == 0;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Crunch the whole dashboard in one pass.
HomeStats computeHomeStats(List<Task> tasks, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = _dayOf(n);
  final monthStart = DateTime(n.year, n.month, 1);
  final monthEnd = DateTime(n.year, n.month + 1, 1); // exclusive

  var dueToday = 0;
  var dueThisMonth = 0;
  var overdue = 0;
  var documents = 0;
  var monthSpend = 0.0;
  final byCategory = <TaskCategory, int>{};
  final upcoming = <Task>[];
  final currencyVotes = <String, int>{};

  for (final t in tasks) {
    // Category tally (every task counts).
    byCategory.update(t.category, (v) => v + 1, ifAbsent: () => 1);
    if (t.hasDocument) documents++;
    currencyVotes.update(t.currency, (v) => v + 1, ifAbsent: () => 1);

    if (!t.isScheduled) continue;
    final day = _dayOf(t.dueAt!);

    // Due-this-month window (calendar month).
    final inThisMonth =
        !t.dueAt!.isBefore(monthStart) && t.dueAt!.isBefore(monthEnd);
    if (inThisMonth && !t.done) {
      dueThisMonth++;
      if (t.hasAmount) monthSpend += t.amount!;
    }

    if (t.done) continue;
    if (day == today) dueToday++;
    if (day.isBefore(today)) overdue++;

    // Up-next: today onward, unfinished.
    if (!day.isBefore(today)) upcoming.add(t);
  }

  upcoming.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

  // Pick the commonest currency for the spend label.
  var currency = 'INR';
  var best = -1;
  currencyVotes.forEach((c, v) {
    if (v > best) {
      best = v;
      currency = c;
    }
  });

  return HomeStats(
    total: tasks.length,
    dueToday: dueToday,
    dueThisMonth: dueThisMonth,
    overdue: overdue,
    documents: documents,
    monthSpend: monthSpend,
    currency: currency,
    byCategory: byCategory,
    upNext: upcoming,
  );
}
