import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../domain/task.dart';

/// Task store — the server (Railway → Supabase) is the source of truth, but the
/// last successful `/tasks` payload is CACHED on-device so a cold start paints
/// the real list instantly instead of a shimmer while a (possibly cold) Railway
/// round-trip runs. On load we hydrate from cache first, then refresh in the
/// background and re-cache.
class TaskStore extends ChangeNotifier {
  TaskStore({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const _cacheKey = 'tasks_cache_v1';

  final ApiClient _api;
  final List<Task> _tasks = [];
  bool _loading = false;
  bool _hasLoaded = false; // true once the first fetch has completed (ok or err)
  Object? _error;

  List<Task> get tasks => List.unmodifiable(_tasks);

  /// Every change flows through notifyListeners, so this one override keeps
  /// the scheduled daily notifications in lockstep with the task list —
  /// add/edit/toggle/delete included. The scheduler debounces, so bursts (and
  /// the load() loading-state notifications) cost one rebuild.
  @override
  void notifyListeners() {
    super.notifyListeners();
    ReminderScheduler.instance.onTasksChanged(List.unmodifiable(_tasks));
  }
  bool get loading => _loading;

  /// True until the very first fetch settles — so the UI can show a loading
  /// screen instead of flashing the "All clear" empty state.
  bool get isInitialLoad => !_hasLoaded;
  Object? get error => _error;

  /// Mark the store as "past its first load" WITHOUT hitting the server. Used
  /// when tasks are populated by another path (the onboarding commit inserts
  /// them locally as they're created), so the Home view leaves its shimmer and
  /// renders the list/empty state immediately instead of loading forever.
  void markLoaded() {
    if (_hasLoaded) return;
    _hasLoaded = true;
    notifyListeners();
  }

  List<Task> get scheduled {
    final list = _tasks.where((t) => t.isScheduled).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return list;
  }

  List<Task> get unscheduled => _tasks.where((t) => !t.isScheduled).toList();
  bool get isEmpty => _tasks.isEmpty;

  /// Fetch the user's tasks. Call at startup.
  ///
  /// Two phases for a snappy cold start:
  ///   1. Hydrate from the on-device cache SYNCHRONOUSLY-ish — if we have cached
  ///      rows, drop the shimmer and paint them immediately.
  ///   2. Refresh from the server in the background; on success, replace the
  ///      list and re-cache. A network failure keeps the cached rows on screen
  ///      instead of an error/empty flash.
  Future<void> load() async {
    // Phase 1 — cache. Only mark "loaded" (leave the shimmer) if we actually
    // had something cached, so a truly-first launch still shows the loader.
    final hadCache = await _hydrateFromCache();
    if (hadCache) {
      _hasLoaded = true;
      notifyListeners();
    } else {
      _loading = true;
      notifyListeners();
    }

    // Phase 2 — network refresh.
    _error = null;
    try {
      final data = await _api.get('/tasks') as List;
      final fresh =
          data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
      _tasks
        ..clear()
        ..addAll(fresh);
      _error = null;
      unawaited(_writeCache(fresh)); // best-effort, off the paint path
    } catch (e) {
      // Keep whatever we hydrated from cache; only surface the error if we have
      // nothing to show.
      if (_tasks.isEmpty) _error = e;
    } finally {
      _loading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Load cached tasks into [_tasks]. Returns true if any were present.
  Future<bool> _hydrateFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return false;
      final list = (jsonDecode(raw) as List)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) return false;
      _tasks
        ..clear()
        ..addAll(list);
      return true;
    } catch (_) {
      return false; // corrupt cache → ignore, fall through to network
    }
  }

  /// Persist the current task list so the next cold start paints instantly.
  Future<void> _writeCache(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(tasks.map((t) => t.toJson()).toList()),
      );
    } catch (_) {
      // Cache is best-effort; a write failure never affects the live list.
    }
  }

  /// Wipe the on-device task list and its cache — used by "Delete data & log
  /// off" so nothing lingers on this device after the account is reset.
  Future<void> clearAll() async {
    _tasks.clear();
    _hasLoaded = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  /// Create a task on the server and add the returned row (with its server id).
  ///
  /// ONE atomic request: the date, repeat, amount, category, and source all go
  /// in the create itself. Never create-then-patch — a two-step save can lose
  /// the second step (e.g. when login's claim moves rows between the two), and
  /// that is exactly how onboarding tasks used to arrive dateless.
  Future<Task> add(
    String title, {
    String? iconName,
    String? iconDomain,
    DateTime? dueAt,
    RepeatCadence repeat = RepeatCadence.none,
    int repeatTimes = 1,
    List<int> repeatDays = const [],
    double? amount,
    String? currency,
    String? category,
    String? source,
    String? imagePath,
    String? subCategory,
    int? birthYear,
    int remindDaysBefore = 0,
  }) async {
    final body = {
      'title': title.trim(),
      'icon_name': iconName,
      'icon_domain': iconDomain,
      'due_at': ?dueAt?.toIso8601String(),
      'repeat': repeat.name,
      'repeat_times': repeatTimes,
      if (repeatDays.isNotEmpty) 'repeat_days': repeatDays,
      'amount': ?amount,
      'currency': ?currency,
      'category': ?category,
      'source': ?source,
      'sub_category': ?subCategory,
    };
    final json = await _api.post('/tasks', body) as Map<String, dynamic>;
    // The server may not echo these back, so graft them on locally (they're
    // also written to the on-device cache).
    final created = Task.fromJson(json);
    if (imagePath != null && imagePath.isNotEmpty) {
      created.imagePath = imagePath;
    }
    if (created.subCategory == null &&
        subCategory != null &&
        subCategory.isNotEmpty) {
      created.subCategory = subCategory;
    }
    // Server may not persist these yet — keep the user's choice locally.
    if (created.repeatTimes == 1 && repeatTimes != 1) {
      created.repeatTimes = repeatTimes;
    }
    if (created.repeatDays.isEmpty && repeatDays.isNotEmpty) {
      created.repeatDays = repeatDays;
    }
    created.birthYear ??= birthYear;
    if (created.remindDaysBefore == 0 && remindDaysBefore != 0) {
      created.remindDaysBefore = remindDaysBefore;
    }
    _tasks.insert(0, created);
    notifyListeners();
    unawaited(_writeCache(_tasks));
    return created;
  }

  /// Persist an edited task to the server (PATCH), updating the local view.
  Future<void> update(Task updated) async {
    final json =
        await _api.patch('/tasks/${updated.id}', updated.toJson())
            as Map<String, dynamic>;
    final saved = Task.fromJson(json);
    // Local-only fields (not stored/echoed by the server) would be wiped by the
    // round-trip — carry them over from what the caller intended to save.
    saved.subCategory ??= updated.subCategory;
    saved.imagePath ??= updated.imagePath;
    saved.birthYear ??= updated.birthYear;
    if (saved.repeatTimes == 1 && updated.repeatTimes != 1) {
      saved.repeatTimes = updated.repeatTimes;
    }
    if (saved.repeatDays.isEmpty && updated.repeatDays.isNotEmpty) {
      saved.repeatDays = updated.repeatDays;
    }
    if (saved.remindDaysBefore == 0 && updated.remindDaysBefore != 0) {
      saved.remindDaysBefore = updated.remindDaysBefore;
    }
    final i = _tasks.indexWhere((t) => t.id == saved.id);
    if (i != -1) _tasks[i] = saved;
    notifyListeners();
    unawaited(_writeCache(_tasks));
  }

  /// Toggle done — OPTIMISTIC: flip the checkbox locally and repaint instantly,
  /// then persist in the background. Rolls back only if the server rejects it,
  /// so the tick feels immediate instead of waiting on the network.
  Future<void> toggleDone(Task task) async {
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i == -1) return;
    final original = _tasks[i];
    final toggled = original.copyWith(done: !original.done);
    _tasks[i] = toggled;
    notifyListeners(); // instant UI update

    try {
      final json = await _api.patch('/tasks/${toggled.id}', toggled.toJson())
          as Map<String, dynamic>;
      final saved = Task.fromJson(json);
      final j = _tasks.indexWhere((t) => t.id == saved.id);
      if (j != -1) {
        _tasks[j] = saved;
        notifyListeners();
      }
      unawaited(_writeCache(_tasks));
    } catch (_) {
      // Roll back to the pre-toggle state on failure.
      final j = _tasks.indexWhere((t) => t.id == original.id);
      if (j != -1) {
        _tasks[j] = original;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Delete on the server. Optimistic: remove locally, roll back on failure.
  Future<void> remove(Task task) async {
    final previous = List<Task>.from(_tasks);
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
    unawaited(_writeCache(_tasks));
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
      // Re-create with EVERYTHING the task had — undo must not lose the date,
      // repeat, or amount.
      await add(
        task.title,
        iconName: task.iconName,
        iconDomain: task.iconDomain,
        dueAt: task.dueAt,
        repeat: task.repeat,
        repeatTimes: task.repeatTimes,
        repeatDays: task.repeatDays,
        amount: task.amount,
        currency: task.currency,
        category: task.storedCategory?.name,
        imagePath: task.imagePath,
        subCategory: task.subCategory,
      );
    } catch (_) {
      // best-effort
    }
  }
}
