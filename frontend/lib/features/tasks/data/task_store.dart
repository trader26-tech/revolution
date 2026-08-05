import 'package:flutter/foundation.dart';

import '../domain/task.dart';

/// In-memory task store shared across Home and Calendar. Swap the internals for
/// real persistence later without touching the UI.
class TaskStore extends ChangeNotifier {
  final List<Task> _tasks = [];

  /// A simple incrementing id — fine for an in-memory store.
  int _seq = 0;

  List<Task> get tasks => List.unmodifiable(_tasks);

  /// Tasks that have a due date, soonest first.
  List<Task> get scheduled {
    final list = _tasks.where((t) => t.isScheduled).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return list;
  }

  /// Tasks with no date yet.
  List<Task> get unscheduled =>
      _tasks.where((t) => !t.isScheduled).toList();

  bool get isEmpty => _tasks.isEmpty;

  /// Quick-add: create a task from just a name and return it.
  Task add(String title) {
    final task = Task(id: 'local-${_seq++}', title: title.trim());
    _tasks.insert(0, task);
    notifyListeners();
    return task;
  }

  void update(Task updated) {
    final i = _tasks.indexWhere((t) => t.id == updated.id);
    if (i != -1) {
      _tasks[i] = updated;
      notifyListeners();
    }
  }

  void toggleDone(Task task) {
    update(task.copyWith(done: !task.done));
  }

  void remove(Task task) {
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
  }
}
