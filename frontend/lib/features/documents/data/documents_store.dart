import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/auth_store.dart';
import '../../settings/data/profile_store.dart';
import '../domain/document.dart';
import 'doc_backup_service.dart';

/// The documents library — a nestable folder tree kept on-device, with OPTIONAL
/// cloud backup.
///
/// Files are COPIED into the app's documents directory; the folder tree and
/// document records are persisted in shared_preferences as JSON. When the user's
/// [ProfileStore.cloudBackup] is ON, each document is ALSO mirrored to the
/// account in the cloud (via [DocBackupService], which rides the existing
/// task-scoped file endpoints), and a fresh install pulls them back down.
class DocumentsStore extends ChangeNotifier {
  DocumentsStore(
      {DocBackupService? backup, ProfileStore? profile, AuthStore? auth})
      : _backup = backup ?? DocBackupService(),
        _profile = profile ?? ProfileStore.instance,
        _auth = auth ?? AuthStore.instance {
    // React to the Settings toggle: when the user turns cloud backup ON, sync in
    // the background so existing documents get pushed up (and any missing ones
    // pulled down) without them leaving Settings.
    _profile.addListener(_onProfileChanged);
    _lastCloudOn = _profile.cloudBackup;
    // React to LOGIN: the instant the account becomes canonical (phone claim
    // done), pull the account's documents down. This is the key fix — restore no
    // longer depends only on the one-shot at load(); logging in re-triggers it
    // with the real account id, so a returning user's folders come back.
    _auth.addListener(_onAuthChanged);
    _lastLoggedIn = _auth.isLoggedIn;
  }

  final DocBackupService _backup;
  final ProfileStore _profile;
  final AuthStore _auth;
  bool _lastCloudOn = false;
  bool _lastLoggedIn = false;

  bool get _cloudOn => _profile.cloudBackup;

  void _onProfileChanged() {
    final on = _profile.cloudBackup;
    if (on && !_lastCloudOn && _loaded) {
      // OFF → ON: back up everything not yet in the cloud (+ pull anything new).
      unawaited(syncWithCloud());
    }
    _lastCloudOn = on;
  }

  void _onAuthChanged() {
    final loggedIn = _auth.isLoggedIn;
    // Rising edge of login → pull the account's documents (retrying, so a cold
    // backend or a claim that just landed doesn't lose them).
    if (loggedIn && !_lastLoggedIn && _loaded) {
      unawaited(refreshFromCloud());
    }
    _lastLoggedIn = loggedIn;
  }

  @override
  void dispose() {
    _profile.removeListener(_onProfileChanged);
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  static const _foldersKey = 'doc_folders_v1';
  static const _itemsKey = 'doc_items_v1';
  static const _subDir = 'documents';

  final List<DocFolder> _folders = [];
  final List<DocItem> _items = [];
  bool _loaded = false;

  /// True while a cloud RESTORE (pull-down) is in flight — the Documents page
  /// shows a "Restoring your documents…" banner so an empty list after login
  /// reads as "loading", not "you have nothing".
  bool _restoring = false;
  bool get isRestoring => _restoring;

  /// Guards against two restore loops running at once (e.g. load() + a login
  /// re-trigger firing together).
  bool _restoreInFlight = false;

  bool get isInitialLoad => !_loaded;

  /// Total documents across the whole tree (for the Home badge).
  int get totalCount => _items.length;

  /// Every document across the whole tree (unmodifiable) — for global search.
  List<DocItem> get allItems => List.unmodifiable(_items);

  /// Total folders across the whole tree (for the Documents hero).
  int get folderCount => _folders.length;

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
    // With cloud backup on, reconcile with the account in the background: pull
    // down anything this device is missing, then push up anything not yet backed
    // up. Never blocks the initial paint.
    if (_cloudOn) unawaited(syncWithCloud());
  }

  /// Full two-way reconcile with the cloud (best-effort, background):
  ///   1. RESTORE — download any account documents this device doesn't have.
  ///   2. BACK UP — upload any local documents not yet in the cloud.
  /// Safe to call any time (e.g. after the user turns backup on). No-op if off.
  Future<void> syncWithCloud() async {
    if (!_cloudOn) return;
    await restoreFromCloud();
    await backUpPending();
  }

  /// Pull the account's documents down, RETRYING on failure so a cold/slow
  /// backend (or a claim that lands a beat late) never silently loses them.
  ///
  /// The old bug: this ran once, and if that single `GET /tasks` came back empty
  /// or threw (Railway cold-start, or the request ran under the anonymous id
  /// before the phone-claim finished), it gave up forever — so a returning user's
  /// documents never appeared. Now: it tries up to [_restoreAttempts] times with
  /// backoff, distinguishing a genuine "no documents" (a clean empty list — stop)
  /// from a transient failure (throw — retry). Shows [isRestoring] throughout so
  /// the UI reads "loading", not "empty".
  static const _restoreAttempts = 5;

  Future<void> restoreFromCloud() async {
    if (!_cloudOn || _restoreInFlight) return;
    _restoreInFlight = true;
    _restoring = true;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < _restoreAttempts; attempt++) {
        try {
          final done = await _restoreOnce();
          if (done) return; // succeeded (found docs, or account is genuinely empty)
        } catch (_) {
          // Transient (cold backend / not-yet-canonical id) — fall through to
          // wait + retry below.
        }
        // Backoff: 1s, 2s, 3s… giving Railway time to wake and the claim to land.
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    } finally {
      _restoreInFlight = false;
      _restoring = false;
      notifyListeners();
    }
  }

  /// One restore pass. Returns true when it definitively completed (the list came
  /// back — whether it had documents or was genuinely empty). Throws on a
  /// network/backend error so [restoreFromCloud] retries.
  Future<bool> _restoreOnce() async {
    final remotes = await _backup.listRemote(); // throws on failure → retried
    final have =
        _items.map((d) => d.carrierTaskId).whereType<String>().toSet();
    var changed = false;
    for (final r in remotes) {
      if (have.contains(r.carrierTaskId)) continue; // already local
      final bytes = await _backup.download(r.carrierTaskId);
      if (bytes == null || bytes.isEmpty) continue;
      final folderId = await _ensureFolderPath(r.folderPath);
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final ext = _extOf(r.originalName ?? '');
      final dir = await _docsDir();
      final dest = '${dir.path}/$id${ext.isEmpty ? '' : '.$ext'}';
      final file = await File(dest).writeAsBytes(bytes, flush: true);
      _items.insert(
        0,
        DocItem(
          id: id,
          name: r.name,
          folderId: folderId,
          localPath: file.path,
          addedAt: DateTime.now(),
          originalName: r.originalName,
          size: bytes.length,
          carrierTaskId: r.carrierTaskId,
          backedUp: true,
        ),
      );
      have.add(r.carrierTaskId);
      changed = true;
    }
    if (changed) {
      notifyListeners();
      await _persist();
    }
    return true; // the list came back cleanly — done (retry only on throw)
  }

  /// Force a fresh restore from the cloud — call this after login completes (the
  /// account id is now canonical). Safe to call repeatedly; dedupes by carrier id
  /// so it never creates duplicates, and the in-flight guard prevents overlap.
  ///
  /// It also RECONCILES: any local document whose carrier the account can't see
  /// (it was uploaded under a PRIOR/anonymous id and got orphaned by the claim)
  /// is re-uploaded under the now-canonical id — so a doc that's still on THIS
  /// device gets correctly re-linked to the phone account. (Docs already lost —
  /// not local anywhere — can't be recovered from the client.)
  Future<void> refreshFromCloud() async {
    if (!_cloudOn) return;
    await restoreFromCloud();
    await _reconcileOrphaned();
    await backUpPending();
  }

  /// Re-link local documents whose cloud carrier isn't visible to the current
  /// account (orphaned under an old anonymous id). Best-effort — a failed list
  /// just skips reconciliation this pass.
  Future<void> _reconcileOrphaned() async {
    if (!_cloudOn) return;
    final List<RemoteDoc> remotes;
    try {
      remotes = await _backup.listRemote();
    } catch (_) {
      return; // can't tell what the account has → don't touch anything
    }
    final visible = remotes.map((r) => r.carrierTaskId).toSet();
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final d = _items[i];
      // Marked backed up, but the account can't see its carrier → orphaned.
      if (d.backedUp &&
          d.carrierTaskId != null &&
          !visible.contains(d.carrierTaskId) &&
          _folderAllowsCloud(d.folderId)) {
        _items[i] = d.copyWith(backedUp: false, carrierTaskId: '');
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _persist();
      // backUpPending() (called right after) will re-upload these under the
      // canonical id, re-linking them to the phone account.
    }
  }

  /// Upload every local document that isn't backed up yet — the retry path for
  /// files added while offline, or right after the user turns backup on.
  Future<void> backUpPending() async {
    if (!_cloudOn) return;
    // Snapshot so mutation during the await loop is safe. Skip items whose folder
    // (or any ancestor folder) has cloud backup turned OFF — those stay on-device
    // only, per the user's per-folder choice.
    final pending =
        _items.where((d) => !d.backedUp && _folderAllowsCloud(d.folderId));
    for (final d in pending.toList()) {
      await _backUpItem(d);
    }
  }

  /// Whether an item in [folderId] may back up to the cloud: true unless that
  /// folder or any ancestor has cloudSync == false. Root items (null) always
  /// may (the root isn't a toggleable folder).
  bool _folderAllowsCloud(String? folderId) {
    var current = folderById(folderId);
    while (current != null) {
      if (!current.cloudSync) return false;
      current = folderById(current.parentId);
    }
    return true;
  }

  /// Resolve (creating as needed) the folder chain described by [folderPath]
  /// (folder names joined by ' / '); returns the leaf folder id, or null for the
  /// root. Reuses an existing folder at each level so restore doesn't duplicate.
  Future<String?> _ensureFolderPath(String folderPath) async {
    final trail = folderPath.trim();
    if (trail.isEmpty) return null;
    String? parentId;
    for (final rawName in trail.split(' / ')) {
      final name = rawName.trim();
      if (name.isEmpty) continue;
      final existing = _folders.firstWhere(
        (f) =>
            f.parentId == parentId &&
            f.displayName.toLowerCase() == name.toLowerCase(),
        orElse: () => DocFolder(
            id: '', name: '', parentId: parentId, createdAt: DateTime.now()),
      );
      if (existing.id.isNotEmpty) {
        parentId = existing.id;
      } else {
        final folder = DocFolder(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          parentId: parentId,
          createdAt: DateTime.now(),
        );
        _folders.add(folder);
        parentId = folder.id;
      }
    }
    return parentId;
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

  /// Toggle whether a folder's documents back up to the cloud. OFF keeps that
  /// folder's files on this device only.
  Future<void> setFolderCloudSync(String id, bool value) async {
    final i = _folders.indexWhere((f) => f.id == id);
    if (i == -1) return;
    _folders[i] = _folders[i].copyWith(cloudSync: value);
    notifyListeners();
    await _persist();
  }

  /// Move a folder under [newParentId] (null = root). No-op if it would create a
  /// cycle (moving a folder into itself/its descendants).
  Future<void> moveFolder(String id, String? newParentId) async {
    if (newParentId != null && _isSelfOrDescendant(newParentId, id)) return;
    final i = _folders.indexWhere((f) => f.id == id);
    if (i == -1) return;
    // Explicit rebuild (copyWith can't set parentId back to null for a root
    // move). Carry cloudSync + createdAt through unchanged.
    final f = _folders[i];
    _folders[i] = DocFolder(
      id: f.id,
      name: f.name,
      parentId: newParentId,
      createdAt: f.createdAt,
      cloudSync: f.cloudSync,
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
    // When cloud backup is on, push this document up in the background — the UI
    // doesn't wait on the network; the row's badge flips to "backed up" when it
    // lands (a failure just leaves it local, to retry on the next sync).
    if (_cloudOn) _startBackUp(doc);
    return doc;
  }

  /// Kick off a document upload AND register it as a pending write, so a login
  /// [ApiClient.claim] that fires mid-upload WAITS for it before the server
  /// re-keys the account to the phone. Without this, a document uploaded around
  /// login time races the claim and gets orphaned under the anonymous id — the
  /// exact bug where subscriptions come back but documents don't.
  void _startBackUp(DocItem doc) {
    final future = _backUpItem(doc);
    ApiClient.instance.trackPendingWrite(future);
    unawaited(future);
  }

  /// Upload one document to the cloud + mark it backed up. Safe to call repeatedly
  /// (skips already-backed items). No-op when cloud backup is off.
  Future<void> _backUpItem(DocItem doc) async {
    if (!_cloudOn || doc.backedUp) return;
    final carrierId =
        await _backup.backUp(doc, folderPath: _folderPathString(doc.folderId));
    if (carrierId == null) return; // stays local; retried on next syncToCloud
    final i = _items.indexWhere((d) => d.id == doc.id);
    if (i == -1) {
      // Deleted while uploading — undo the orphaned cloud copy.
      await _backup.remove(carrierId);
      return;
    }
    _items[i] = _items[i].copyWith(carrierTaskId: carrierId, backedUp: true);
    notifyListeners();
    await _persist();
  }

  /// The human folder trail for [folderId] — folder names joined by ' / ' (empty
  /// at root). Stored on the carrier so restore can rebuild the same tree.
  String _folderPathString(String? folderId) =>
      pathTo(folderId).map((f) => f.displayName).join(' / ');

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
    // Also remove its cloud copy so the account doesn't keep a deleted file.
    final carrier = removed.carrierTaskId;
    if (carrier != null) unawaited(_backup.remove(carrier));
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
