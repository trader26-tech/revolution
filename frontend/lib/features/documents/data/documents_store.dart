import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tasks/domain/task.dart';
import '../domain/document.dart';

/// The LOCAL documents library — everything lives on-device, nothing uploads.
///
/// Files are COPIED into the app's documents directory (so a document survives
/// even if the user later deletes the original from Downloads), and the list of
/// documents (name, folder, local path, size) is persisted in shared_preferences
/// as JSON. Fully offline, fully private.
class DocumentsStore extends ChangeNotifier {
  DocumentsStore();

  static const _prefsKey = 'documents_v1';
  static const _subDir = 'documents';

  final List<Document> _docs = [];
  bool _loaded = false;

  bool get isInitialLoad => !_loaded;
  List<Document> get all => List.unmodifiable(_docs);
  int get count => _docs.length;

  /// Grouped by folder, in the app's canonical category order, empties skipped.
  Map<TaskCategory, List<Document>> get byFolder {
    final map = <TaskCategory, List<Document>>{};
    for (final d in _docs) {
      map.putIfAbsent(d.folder, () => []).add(d);
    }
    final ordered = <TaskCategory, List<Document>>{};
    for (final c in TaskCategory.values) {
      final items = map[c];
      if (items != null && items.isNotEmpty) ordered[c] = items;
    }
    return ordered;
  }

  /// Load the saved library from disk. Safe to call repeatedly.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      _docs.clear();
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          final doc = Document.fromJson(e as Map<String, dynamic>);
          // Drop entries whose file has gone missing, so the list never lies.
          if (doc.localPath.isNotEmpty && File(doc.localPath).existsSync()) {
            _docs.add(doc);
          }
        }
      }
    } catch (_) {
      // Corrupt/absent store → start empty.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_docs.map((d) => d.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort; the in-memory list is still correct for this session.
    }
  }

  /// The directory the on-device copies live in (created on first use).
  Future<Directory> _docsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_subDir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Add a document by COPYING [sourcePath] into local storage. Returns the
  /// created [Document]. Nothing leaves the device.
  Future<Document> addFromPath({
    required String name,
    required TaskCategory folder,
    required String sourcePath,
    String? originalName,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ext = _extOf(originalName ?? sourcePath);
    final dir = await _docsDir();
    final dest = '${dir.path}/$id${ext.isEmpty ? '' : '.$ext'}';

    final srcFile = File(sourcePath);
    final copied = await srcFile.copy(dest);
    final size = await copied.length();

    final doc = Document(
      id: id,
      name: name.trim().isEmpty ? 'Document' : name.trim(),
      folder: folder,
      localPath: copied.path,
      addedAt: DateTime.now(),
      originalName: originalName,
      size: size,
    );
    _docs.insert(0, doc);
    notifyListeners();
    await _persist();
    return doc;
  }

  /// Add a document from picked BYTES (when the picker gave bytes, not a path).
  Future<Document> addFromBytes({
    required String name,
    required TaskCategory folder,
    required List<int> bytes,
    String? originalName,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ext = _extOf(originalName ?? '');
    final dir = await _docsDir();
    final dest = '${dir.path}/$id${ext.isEmpty ? '' : '.$ext'}';

    final file = await File(dest).writeAsBytes(bytes, flush: true);

    final doc = Document(
      id: id,
      name: name.trim().isEmpty ? 'Document' : name.trim(),
      folder: folder,
      localPath: file.path,
      addedAt: DateTime.now(),
      originalName: originalName,
      size: bytes.length,
    );
    _docs.insert(0, doc);
    notifyListeners();
    await _persist();
    return doc;
  }

  /// Remove a document — deletes the on-device copy and forgets it. Optimistic.
  Future<void> remove(Document doc) async {
    final i = _docs.indexWhere((d) => d.id == doc.id);
    if (i == -1) return;
    final removed = _docs.removeAt(i);
    notifyListeners();
    try {
      final f = File(removed.localPath);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // File already gone — fine.
    }
    await _persist();
  }

  static String _extOf(String nameOrPath) {
    final dot = nameOrPath.lastIndexOf('.');
    if (dot < 0 || dot == nameOrPath.length - 1) return '';
    return nameOrPath.substring(dot + 1).toLowerCase();
  }
}
