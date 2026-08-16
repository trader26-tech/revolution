import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../domain/document.dart';

/// Cloud backup for the standalone Documents library, built ON TOP of the
/// existing task-scoped file endpoints — so it needs NO new backend.
///
/// Each backed-up document is mirrored by a hidden "carrier" task on the server:
///   • `POST /tasks` creates the carrier (marked with [kMarker] in sub_category
///     so it is NEVER shown as a reminder), carrying the doc's name, folder path,
///     and original filename in its fields.
///   • `POST /tasks/{id}/document` (ApiClient.uploadDocument) attaches the bytes
///     to that carrier — the file then lives in the account's Supabase bucket.
///   • `GET /tasks` on a fresh device lists the carriers; each file is pulled
///     back via the signed URL (ApiClient.documentUrl) and re-materialised.
///
/// This is deliberately self-contained: it talks straight to [ApiClient] and
/// never touches [TaskStore], so document carriers stay out of the reminders
/// list, the Home feed, and local notifications.
class DocBackupService {
  DocBackupService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// The sub_category marker that flags a task as a document carrier (not a
  /// reminder). The tasks UI already filters by category/sub_category, so a value
  /// this distinctive is safe to exclude everywhere.
  static const kMarker = '__docbackup__';

  /// A carrier task's payload, mapped back to the fields we need to restore a
  /// document on another device.
  ///
  /// We stash the library metadata in the carrier's plain fields:
  ///   • title        → the document's display name
  ///   • note         → "folderPath\noriginalName" (folderPath = names joined by
  ///                    ' / ', empty for root; originalName may be blank)
  /// The actual file rides in the carrier's document attachment (bucket).

  /// Create the carrier task for [doc] and upload its bytes. Returns the created
  /// carrier task id, or null if anything failed (caller keeps the doc local +
  /// unbacked, to retry later). [folderPath] is the human folder trail (names
  /// joined by ' / ', empty at root) used to rebuild the tree on restore.
  Future<String?> backUp(
    DocItem doc, {
    required String folderPath,
  }) async {
    try {
      final file = File(doc.localPath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();

      // 1) Create the hidden carrier task.
      final note = '$folderPath\n${doc.originalName ?? ''}';
      final res = await _api.post('/tasks', {
        'title': doc.name,
        'category': 'other',
        'sub_category': kMarker,
        'note': note,
        // Never alert: no due date, reminders off.
        'reminder_on': false,
      });
      if (res is! Map || res['id'] == null) return null;
      final carrierId = res['id'].toString();

      // 2) Attach the bytes to it.
      final path = await _api.uploadDocument(
        carrierId,
        bytes: bytes,
        filename: doc.originalName ?? '${doc.name}.bin',
        contentType: _contentTypeFor(doc.originalName ?? doc.localPath),
      );
      if (path == null) {
        // Bucket upload failed — drop the empty carrier so we don't leave junk.
        await _deleteCarrier(carrierId);
        return null;
      }
      return carrierId;
    } catch (_) {
      return null;
    }
  }

  /// Remove a document's carrier task (and its attached file) from the cloud —
  /// called when the user deletes a backed-up document. Best-effort.
  Future<void> remove(String carrierTaskId) => _deleteCarrier(carrierTaskId);

  Future<void> _deleteCarrier(String carrierTaskId) async {
    try {
      await _api.delete('/tasks/$carrierTaskId');
    } catch (_) {
      // Best-effort — a leftover carrier is harmless (filtered from the UI).
    }
  }

  /// List every document carrier for the account. Returns lightweight records
  /// the store turns back into local [DocItem]s + folders. Empty on any error.
  Future<List<RemoteDoc>> listRemote() async {
    try {
      final res = await _api.get('/tasks');
      if (res is! List) return const [];
      final out = <RemoteDoc>[];
      for (final e in res) {
        if (e is! Map) continue;
        if ((e['sub_category'] as String?) != kMarker) continue;
        final id = e['id']?.toString();
        if (id == null) continue;
        final note = (e['note'] as String?) ?? '';
        final parts = note.split('\n');
        out.add(RemoteDoc(
          carrierTaskId: id,
          name: (e['title'] as String?)?.trim().isNotEmpty == true
              ? e['title'] as String
              : 'Document',
          folderPath: parts.isNotEmpty ? parts[0].trim() : '',
          originalName: parts.length > 1 && parts[1].trim().isNotEmpty
              ? parts[1].trim()
              : null,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Download a carrier's file bytes via its signed URL. Null if unavailable.
  Future<List<int>?> download(String carrierTaskId) async {
    try {
      final url = await _api.documentUrl(carrierTaskId);
      if (url == null) return null;
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// A rough content-type from a filename/extension — enough for the bucket to
  /// store + serve it. Defaults to a generic binary type.
  static String _contentTypeFor(String nameOrPath) {
    final ext = nameOrPath.contains('.')
        ? nameOrPath.substring(nameOrPath.lastIndexOf('.') + 1).toLowerCase()
        : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'heic' => 'image/heic',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }
}

/// A document carrier as read back from the server, before it's turned into a
/// local [DocItem] + folder tree.
class RemoteDoc {
  const RemoteDoc({
    required this.carrierTaskId,
    required this.name,
    required this.folderPath,
    this.originalName,
  });

  final String carrierTaskId;
  final String name;

  /// The folder trail the doc lived in, folder names joined by ' / ' (empty =
  /// root). Rebuilt into real folders on restore.
  final String folderPath;
  final String? originalName;
}
