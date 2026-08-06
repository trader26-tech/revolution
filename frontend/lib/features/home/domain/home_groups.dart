import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_filter.dart';

/// A day-based grouping of tasks for the home screen: Pending (overdue & not
/// done), Today, the Next 7 days, everything after that (Remaining), and undated
/// tasks — each sorted by due date/time.
class HomeGroups {
  const HomeGroups({
    required this.pending,
    required this.today,
    required this.next7,
    required this.remaining,
    required this.unscheduled,
  });

  /// Overdue (due before today) AND not completed — needs attention now.
  final List<Task> pending;

  final List<Task> today;

  /// Due within the next 7 days (day after today → +7), soonest-first.
  final List<Task> next7;

  /// Everything due after the next-7-days window, soonest-first.
  final List<Task> remaining;

  /// Tasks with no date at all.
  final List<Task> unscheduled;

  bool get isEmpty =>
      pending.isEmpty &&
      today.isEmpty &&
      next7.isEmpty &&
      remaining.isEmpty &&
      unscheduled.isEmpty;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Build the home groups from a task list, respecting the active [filter].
///
/// Overdue tasks that AREN'T done are surfaced as "Pending" (their own group,
/// shown first). An overdue task that's already done just sits in Today.
HomeGroups groupForHome(List<Task> tasks, {required TaskFilter filter}) {
  final now = DateTime.now();
  final today = _dayOf(now);
  final next7End = today.add(const Duration(days: 7)); // inclusive window end

  final visible = applyFilter(tasks, filter);

  final pendingList = <Task>[];
  final todayList = <Task>[];
  final next7List = <Task>[];
  final remainingList = <Task>[];
  final unscheduledList = <Task>[];

  for (final t in visible) {
    if (!t.isScheduled) {
      unscheduledList.add(t);
      continue;
    }
    final day = _dayOf(t.dueAt!);
    if (day.isBefore(today)) {
      // Overdue → Pending if unfinished, else just Today.
      (t.done ? todayList : pendingList).add(t);
    } else if (day == today) {
      todayList.add(t);
    } else if (!day.isAfter(next7End)) {
      next7List.add(t); // tomorrow … +7 days
    } else {
      remainingList.add(t);
    }
  }

  int byDue(Task a, Task b) => a.dueAt!.compareTo(b.dueAt!);
  pendingList.sort(byDue);
  todayList.sort(byDue);
  next7List.sort(byDue);
  remainingList.sort(byDue);

  return HomeGroups(
    pending: pendingList,
    today: todayList,
    next7: next7List,
    remaining: remainingList,
    unscheduled: unscheduledList,
  );
}

