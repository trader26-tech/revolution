import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/document.dart';

/// The LOCAL documents library — a nestable folder tree, entirely on-device.
///
/// Files are COPIED into the app's documents directory; the folder tree and
/// document records are persisted in shared_preferences as JSON. Fully offline,
/// fully private — nothing is ever uploaded.
class DocumentsStore extends ChangeNotifier {
  DocumentsStore();

  static const _foldersKey = 'doc_folders_v1';
  static const _itemsKey = 'doc_items_v1';
  static const _subDir = 'documents';

  final List<DocFolder> _folders = [];
  final List<DocItem> _items = [];
  bool _loaded = false;

  bool get isInitialLoad => !_loaded;

  /// Total documents across the whole tree (for the Home badge).
  int get totalCount => _items.length;

  // ── Tree queries ──────────────────────────────────────────────────────────

  /// Sub-folders directly inside [folderId] (root when null), name-sorted.
  List<DocFolder> foldersIn(String? folderId) {
    final list = _folders.where((f) => f.parentId == folderId).toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  /// Documents directly inside [folderId] (root when null), newest first.
  List<DocItem> itemsIn(String? folderId) {
    final list = _items.where((d) => d.folderId == folderId).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  DocFolder? folderById(String? id) {
    if (id == null) return null;
    for (final f in _folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The breadcrumb path from root → [folderId] (inclusive). Empty at root.
  List<DocFolder> pathTo(String? folderId) {
    final path = <DocFolder>[];
    var current = folderById(folderId);
    while (current != null) {
      path.insert(0, current);
      current = folderById(current.parentId);
    }
    return path;
  }

  /// How many items live ANYWHERE under [folderId] (for a folder's subtitle).
  int itemsUnder(String folderId) {
    var count = itemsIn(folderId).length;
    for (final sub in foldersIn(folderId)) {
      count += itemsUnder(sub.id);
    }
    return count;
  }

  /// True if [maybeAncestor] is [folderId] or any ancestor of it — used to stop
  /// a folder being moved into its own subtree.
  bool _isSelfOrDescendant(String folderId, String maybeAncestor) {
    var current = folderById(folderId);
    while (current != null) {
      if (current.id == maybeAncestor) return true;
      current = folderById(current.parentId);
    }
    return false;
  }

  // ── Load / persist ────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _folders.clear();
      _items.clear();

      final rawF = prefs.getString(_foldersKey);
      if (rawF != null && rawF.isNotEmpty) {
        for (final e in jsonDecode(rawF) as List<dynamic>) {
          _folders.add(DocFolder.fromJson(e as Map<String, dynamic>));
        }
      }
      final rawI = prefs.getString(_itemsKey);
      if (rawI != null && rawI.isNotEmpty) {
        for (final e in jsonDecode(rawI) as List<dynamic>) {
          final item = DocItem.fromJson(e as Map<String, dynamic>);
          // Drop entries whose file has gone missing so the list never lies.
          if (item.localPath.isNotEmpty && File(item.localPath).existsSync()) {
            _items.add(item);
          }
        }
      }
    } catch (_) {
      // Corrupt/absent → start empty.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _foldersKey,
        jsonEncode(_folders.map((f) => f.toJson()).toList()),
      );
      await prefs.setString(
        _itemsKey,
        jsonEncode(_items.map((d) => d.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<Directory> _docsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_subDir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ── Folder ops ────────────────────────────────────────────────────────────

  Future<DocFolder> createFolder({
    required String name,
    String? parentId,
  }) async {
    final folder = DocFolder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Folder' : name.trim(),
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    _folders.add(folder);
    notifyListeners();
    await _persist();
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    final i = _folders.indexWhere((f) => f.id == id);
    if (i == -1) return;
    _folders[i] = _folders[i].copyWith(name: name.trim());
    notifyListeners();
    await _persist();
  }

  /// Move a folder under [newParentId] (null = root). No-op if it would create a
  /// cycle (moving a folder into itself/its descendants).
  Future<void> moveFolder(String id, String? newParentId) async {
    if (newParentId != null && _isSelfOrDescendant(newParentId, id)) return;
    final i = _folders.indexWhere((f) => f.id == id);
    if (i == -1) return;
    _folders[i] = DocFolder(
      id: _folders[i].id,
      name: _folders[i].name,
      parentId: newParentId,
      createdAt: _folders[i].createdAt,
    );
    notifyListeners();
    await _persist();
  }

  /// Delete a folder and EVERYTHING under it (sub-folders + their files).
  Future<void> deleteFolder(String id) async {
    // Collect the whole subtree.
    final folderIds = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final f in _folders) {
        if (f.parentId != null &&
            folderIds.contains(f.parentId) &&
            !folderIds.contains(f.id)) {
          folderIds.add(f.id);
          changed = true;
        }
      }
    }
    // Delete the files of every item in that subtree.
    final doomed = _items.where((d) => folderIds.contains(d.folderId)).toList();
    for (final d in doomed) {
      await _deleteFileFor(d);
    }
    _items.removeWhere((d) => folderIds.contains(d.folderId));
    _folders.removeWhere((f) => folderIds.contains(f.id));
    notifyListeners();
    await _persist();
  }

  // ── Document ops ──────────────────────────────────────────────────────────

  Future<DocItem> addFromPath({
    required String name,
    required String? folderId,
    required String sourcePath,
    String? originalName,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ext = _extOf(originalName ?? sourcePath);
    final dir = await _docsDir();
    final dest = '${dir.path}/$id${ext.isEmpty ? '' : '.$ext'}';
    final copied = await File(sourcePath).copy(dest);
    final size = await copied.length();
    return _record(id, name, folderId, copied.path, originalName, size);
  }

  Future<DocItem> addFromBytes({
    required String name,
    required String? folderId,
    required List<int> bytes,
    String? originalName,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ext = _extOf(originalName ?? '');
    final dir = await _docsDir();
    final dest = '${dir.path}/$id${ext.isEmpty ? '' : '.$ext'}';
    final file = await File(dest).writeAsBytes(bytes, flush: true);
    return _record(id, name, folderId, file.path, originalName, bytes.length);
  }

  Future<DocItem> _record(
    String id,
    String name,
    String? folderId,
    String path,
    String? originalName,
    int size,
  ) async {
    final doc = DocItem(
      id: id,
      name: name.trim().isEmpty ? 'Document' : name.trim(),
      folderId: folderId,
      localPath: path,
      addedAt: DateTime.now(),
      originalName: originalName,
      size: size,
    );
    _items.insert(0, doc);
    notifyListeners();
    await _persist();
    return doc;
  }

  Future<void> renameItem(String id, String name) async {
    final i = _items.indexWhere((d) => d.id == id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(name: name.trim());
    notifyListeners();
    await _persist();
  }

  Future<void> moveItem(String id, String? folderId) async {
    final i = _items.indexWhere((d) => d.id == id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(folderId: folderId);
    notifyListeners();
    await _persist();
  }

  Future<void> removeItem(DocItem doc) async {
    final i = _items.indexWhere((d) => d.id == doc.id);
    if (i == -1) return;
    final removed = _items.removeAt(i);
    notifyListeners();
    await _deleteFileFor(removed);
    await _persist();
  }

  Future<void> _deleteFileFor(DocItem doc) async {
    try {
      final f = File(doc.localPath);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  static String _extOf(String nameOrPath) {
    final dot = nameOrPath.lastIndexOf('.');
    if (dot < 0 || dot == nameOrPath.length - 1) return '';
    return nameOrPath.substring(dot + 1).toLowerCase();
  }
}
