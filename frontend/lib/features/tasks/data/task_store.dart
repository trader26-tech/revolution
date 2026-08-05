import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/task.dart';

/// Task store shared across Home and Calendar. Persists on-device via
/// shared_preferences so tasks (and their icons) survive app restarts. Swap for
/// a backend DB later without touching the UI.
class TaskStore extends ChangeNotifier {
  final List<Task> _tasks = [];

  /// A simple incrementing id — fine for a local store.
  int _seq = 0;

  static const _storageKey = 'tasks_v1';
  SharedPreferences? _prefs;

  /// Load persisted tasks. Call once at startup (best-effort — a failure just
  /// starts empty).
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
        _tasks
          ..clear()
          ..addAll(list);
        // Keep ids unique after reload.
        for (final t in _tasks) {
          final n = int.tryParse(t.id.replaceAll('local-', ''));
          if (n != null && n >= _seq) _seq = n + 1;
        }
        notifyListeners();
      }
    } catch (_) {
      // Ignore — start with an empty list.
    }
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!
          .setString(_storageKey, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
    } catch (_) {
      // Non-fatal.
    }
  }

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

  /// Quick-add: create a task from a name (and optionally a brand icon).
  Task add(String title, {String? iconName, String? iconDomain}) {
    final task = Task(
      id: 'local-${_seq++}',
      title: title.trim(),
      iconName: iconName,
      iconDomain: iconDomain,
    );
    _tasks.insert(0, task);
    notifyListeners();
    _persist();
    return task;
  }

  void update(Task updated) {
    final i = _tasks.indexWhere((t) => t.id == updated.id);
    if (i != -1) {
      _tasks[i] = updated;
      notifyListeners();
      _persist();
    }
  }

  void toggleDone(Task task) {
    update(task.copyWith(done: !task.done));
  }

  void remove(Task task) {
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
    _persist();
  }

  /// Re-insert a previously removed task at its old position (for Undo).
  void restore(Task task, {int? at}) {
    if (_tasks.any((t) => t.id == task.id)) return;
    final index = (at ?? 0).clamp(0, _tasks.length);
    _tasks.insert(index, task);
    notifyListeners();
    _persist();
  }
}
