import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import '../domain/document.dart';

/// The Documents library store.
///
/// Presents ONE unified list from two sources:
///   • standalone documents (its own `/documents` records), and
///   • every reminder that has an attached document (from the shared
///     [TaskStore], so the two views stay in sync with no extra fetch).
///
/// The Documents tab reads [byFolder] to render folder sections. Adding,
/// opening (signed URL), and deleting all live here.
class DocumentsStore extends ChangeNotifier {
  DocumentsStore({required TaskStore tasks, ApiClient? api})
      : _tasks = tasks,
        _api = api ?? ApiClient.instance {
    // Task-attached docs change when the task list does — restay in sync.
    _tasks.addListener(_onTasksChanged);
  }

  final ApiClient _api;
  final TaskStore _tasks;

  final List<Document> _standalone = [];
  bool _loading = false;
  bool _hasLoaded = false;
  Object? _error;

  bool get isInitialLoad => !_hasLoaded;
  bool get loading => _loading;
  Object? get error => _error;

  void _onTasksChanged() {
    // Task-attached docs are derived live; just repaint.
    if (hasListeners) notifyListeners();
  }

  @override
  void dispose() {
    _tasks.removeListener(_onTasksChanged);
    super.dispose();
  }

  /// The reminders that carry a document, as library items.
  List<Document> get _fromTasks => [
        for (final t in _tasks.tasks)
          if (t.hasDocument) Document.fromTask(t),
      ];

  /// The full, merged library — standalone first (newest), then task docs.
  List<Document> get all => [..._standalone, ..._fromTasks];

  int get count => all.length;

  /// Grouped by folder, in the app's canonical category order, skipping empties.
  Map<TaskCategory, List<Document>> get byFolder {
    final map = <TaskCategory, List<Document>>{};
    for (final d in all) {
      map.putIfAbsent(d.folder, () => []).add(d);
    }
    // Canonical order.
    final ordered = <TaskCategory, List<Document>>{};
    for (final c in TaskCategory.values) {
      final items = map[c];
      if (items != null && items.isNotEmpty) ordered[c] = items;
    }
    return ordered;
  }

  /// Fetch the standalone documents. Call on tab open.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _api.listDocuments();
      _standalone
        ..clear()
        ..addAll(rows.map((e) => Document.fromJson(e as Map<String, dynamic>)));
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Add a standalone document (name + folder + file bytes). Inserts the
  /// returned row at the top on success.
  Future<Document> add({
    required String name,
    required TaskCategory folder,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final json = await _api.uploadStandaloneDocument(
      name: name,
      folder: folder.name,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    final created = Document.fromJson(json);
    _standalone.insert(0, created);
    notifyListeners();
    return created;
  }

  /// A short-lived signed URL to VIEW/SHARE [doc], from whichever source.
  Future<String?> urlFor(Document doc) {
    return switch (doc.source) {
      DocSource.standalone => _api.documentUrlById(doc.id),
      DocSource.task => _api.documentUrl(doc.id),
    };
  }

  /// Delete a STANDALONE document. (Task-attached docs are removed by editing
  /// the reminder, so this only handles the library's own records.) Optimistic.
  Future<void> remove(Document doc) async {
    if (doc.source != DocSource.standalone) return;
    final i = _standalone.indexWhere((d) => d.id == doc.id);
    if (i == -1) return;
    final removed = _standalone.removeAt(i);
    notifyListeners();
    try {
      await _api.deleteDocument(doc.id);
    } catch (_) {
      _standalone.insert(i, removed); // roll back
      notifyListeners();
      rethrow;
    }
  }
}
