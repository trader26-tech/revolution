import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../domain/task.dart';

/// Task store — the SERVER is the only store. Every add/update/delete goes to
/// the backend (Railway → Supabase); the local list is just a view of what the
/// server returned. Nothing is persisted on the device.
class TaskStore extends ChangeNotifier {
  TaskStore({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;
  final List<Task> _tasks = [];
  bool _loading = false;
  Object? _error;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get loading => _loading;
  Object? get error => _error;

  List<Task> get scheduled {
    final list = _tasks.where((t) => t.isScheduled).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return list;
  }

  List<Task> get unscheduled => _tasks.where((t) => !t.isScheduled).toList();
  bool get isEmpty => _tasks.isEmpty;

  /// Fetch the user's tasks from the server. Call at startup.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get('/tasks') as List;
      _tasks
        ..clear()
        ..addAll(data.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Create a task on the server and add the returned row (with its server id).
  Future<Task> add(String title, {String? iconName, String? iconDomain}) async {
    final body = {
      'title': title.trim(),
      'icon_name': iconName,
      'icon_domain': iconDomain,
    };
    final json = await _api.post('/tasks', body) as Map<String, dynamic>;
    final created = Task.fromJson(json);
    _tasks.insert(0, created);
    notifyListeners();
    return created;
  }

  /// Persist an edited task to the server (PATCH), updating the local view.
  Future<void> update(Task updated) async {
    final json =
        await _api.patch('/tasks/${updated.id}', updated.toJson())
            as Map<String, dynamic>;
    final saved = Task.fromJson(json);
    final i = _tasks.indexWhere((t) => t.id == saved.id);
    if (i != -1) _tasks[i] = saved;
    notifyListeners();
  }

  Future<void> toggleDone(Task task) =>
      update(task.copyWith(done: !task.done));

  /// Delete on the server. Optimistic: remove locally, roll back on failure.
  Future<void> remove(Task task) async {
    final previous = List<Task>.from(_tasks);
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
    try {
      await _api.delete('/tasks/${task.id}');
    } catch (_) {
      _tasks
        ..clear()
        ..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }

  /// Re-create a deleted task on the server (for Undo).
  Future<void> restore(Task task, {int? at}) async {
    try {
      await add(task.title,
          iconName: task.iconName, iconDomain: task.iconDomain);
    } catch (_) {
      // best-effort
    }
  }
}
