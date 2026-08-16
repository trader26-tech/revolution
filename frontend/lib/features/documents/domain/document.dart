/// The LOCAL documents library — a real, nestable file tree kept entirely
/// on-device. Two record types, both persisted in shared_preferences:
///
///   • [DocFolder] — a folder. `parentId == null` means it sits at the root.
///     Folders nest to any depth (a folder's parent is another folder).
///   • [DocItem]   — a document (a file copied into app storage), living in
///     exactly one folder (or the root when `folderId == null`).
///
/// Nothing is ever uploaded; the file bytes live in the app's documents dir and
/// these records just point at them.
library;

class DocFolder {
  const DocFolder({
    required this.id,
    required this.name,
    required this.parentId,
    required this.createdAt,
  });

  final String id;
  String get displayName => name.trim().isEmpty ? 'Folder' : name.trim();
  final String name;

  /// The parent folder id, or null for a root-level folder.
  final String? parentId;
  final DateTime createdAt;

  DocFolder copyWith({String? name, String? parentId}) => DocFolder(
        id: id,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'created_at': createdAt.toIso8601String(),
      };

  factory DocFolder.fromJson(Map<String, dynamic> j) => DocFolder(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Folder',
        parentId: j['parent_id'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class DocItem {
  const DocItem({
    required this.id,
    required this.name,
    required this.folderId,
    required this.localPath,
    required this.addedAt,
    this.originalName,
    this.size,
    this.carrierTaskId,
    this.backedUp = false,
  });

  final String id;
  final String name;

  /// The folder this document lives in, or null when it's at the root.
  final String? folderId;

  /// Absolute path to the on-device copy.
  final String localPath;
  final DateTime addedAt;
  final String? originalName;
  final int? size;

  /// The id of this document's hidden "carrier" task on the server — the row the
  /// file bytes are attached to (via POST /tasks/{id}/document). Null = never
  /// backed up. Set once the carrier task is created + the file uploaded.
  final String? carrierTaskId;

  /// True once the file bytes are confirmed uploaded to the carrier task's
  /// bucket. False = local-only (never uploaded, or upload pending/failed).
  final bool backedUp;

  bool get isPdf =>
      localPath.toLowerCase().endsWith('.pdf') ||
      (originalName ?? '').toLowerCase().endsWith('.pdf');

  String? get sizeLabel {
    final s = size;
    if (s == null || s <= 0) return null;
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(0)} KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DocItem copyWith({
    String? name,
    String? folderId,
    String? localPath,
    String? carrierTaskId,
    bool? backedUp,
  }) =>
      DocItem(
        id: id,
        name: name ?? this.name,
        folderId: folderId ?? this.folderId,
        localPath: localPath ?? this.localPath,
        addedAt: addedAt,
        originalName: originalName,
        size: size,
        carrierTaskId: carrierTaskId ?? this.carrierTaskId,
        backedUp: backedUp ?? this.backedUp,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folder_id': folderId,
        'local_path': localPath,
        'added_at': addedAt.toIso8601String(),
        'original_name': originalName,
        'size': size,
        'carrier_task_id': carrierTaskId,
        'backed_up': backedUp,
      };

  factory DocItem.fromJson(Map<String, dynamic> j) => DocItem(
        id: j['id'] as String,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Document',
        folderId: j['folder_id'] as String?,
        localPath: j['local_path'] as String? ?? '',
        addedAt: DateTime.tryParse(j['added_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        originalName: j['original_name'] as String?,
        size: (j['size'] as num?)?.toInt(),
        carrierTaskId: j['carrier_task_id'] as String?,
        backedUp: j['backed_up'] as bool? ?? false,
      );
}
