import 'package:flutter/material.dart';

import 'task.dart';

/// The status filters offered in the top-right filter menu.
enum TaskFilter { all, scheduled, unscheduled, active, completed }

extension TaskFilterInfo on TaskFilter {
  String get label => switch (this) {
        TaskFilter.all => 'All',
        TaskFilter.scheduled => 'Scheduled',
        TaskFilter.unscheduled => 'Unscheduled',
        TaskFilter.active => 'Active',
        TaskFilter.completed => 'Completed',
      };

  IconData get icon => switch (this) {
        TaskFilter.all => Icons.all_inbox_rounded,
        TaskFilter.scheduled => Icons.event_available_rounded,
        TaskFilter.unscheduled => Icons.event_busy_rounded,
        TaskFilter.active => Icons.radio_button_unchecked,
        TaskFilter.completed => Icons.check_circle_rounded,
      };

  /// Whether this filter is actually narrowing the list (everything but `all`).
  bool get isActive => this != TaskFilter.all;

  bool matches(Task t) => switch (this) {
        TaskFilter.all => true,
        TaskFilter.scheduled => t.isScheduled,
        TaskFilter.unscheduled => !t.isScheduled,
        TaskFilter.active => !t.done,
        TaskFilter.completed => t.done,
      };
}

/// Apply a filter to a task list.
List<Task> applyFilter(List<Task> tasks, TaskFilter filter) =>
    tasks.where(filter.matches).toList();
