import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_filter.dart';

/// A day-based grouping of tasks for the home screen: Today, Tomorrow, and
/// everything later ("Scheduled"), each sorted by due date/time. Unscheduled
/// tasks (no date) land in their own bucket.
class HomeGroups {
  const HomeGroups({
    required this.today,
    required this.tomorrow,
    required this.later,
    required this.unscheduled,
  });

  final List<Task> today;
  final List<Task> tomorrow;

  /// Everything due after tomorrow, sorted soonest-first.
  final List<Task> later;

  /// Tasks with no date at all.
  final List<Task> unscheduled;

  bool get isEmpty =>
      today.isEmpty && tomorrow.isEmpty && later.isEmpty && unscheduled.isEmpty;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Build the home groups from a task list, respecting the active [filter].
/// Overdue tasks (due before today) fold into Today so they stay visible.
HomeGroups groupForHome(List<Task> tasks, {required TaskFilter filter}) {
  final now = DateTime.now();
  final today = _dayOf(now);
  final tomorrow = today.add(const Duration(days: 1));

  final visible = applyFilter(tasks, filter);

  final todayList = <Task>[];
  final tomorrowList = <Task>[];
  final laterList = <Task>[];
  final unscheduledList = <Task>[];

  for (final t in visible) {
    if (!t.isScheduled) {
      unscheduledList.add(t);
      continue;
    }
    final day = _dayOf(t.dueAt!);
    if (!day.isAfter(today)) {
      todayList.add(t); // today or overdue
    } else if (day == tomorrow) {
      tomorrowList.add(t);
    } else {
      laterList.add(t);
    }
  }

  int byDue(Task a, Task b) => a.dueAt!.compareTo(b.dueAt!);
  todayList.sort(byDue);
  tomorrowList.sort(byDue);
  laterList.sort(byDue);

  return HomeGroups(
    today: todayList,
    tomorrow: tomorrowList,
    later: laterList,
    unscheduled: unscheduledList,
  );
}

/// The counts shown on the four stat cards.
class HomeStats {
  const HomeStats({
    required this.scheduled,
    required this.unscheduled,
    required this.active,
    required this.completed,
  });

  final int scheduled;
  final int unscheduled;
  final int active;
  final int completed;

  int countFor(TaskFilter f) => switch (f) {
        TaskFilter.scheduled => scheduled,
        TaskFilter.unscheduled => unscheduled,
        TaskFilter.active => active,
        TaskFilter.completed => completed,
        TaskFilter.all => active + completed,
      };
}

HomeStats statsFor(List<Task> tasks) => HomeStats(
      scheduled: tasks.where((t) => t.isScheduled).length,
      unscheduled: tasks.where((t) => !t.isScheduled).length,
      active: tasks.where((t) => !t.done).length,
      completed: tasks.where((t) => t.done).length,
    );
