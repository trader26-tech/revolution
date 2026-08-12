import '../../tasks/domain/task.dart';

/// One document in the LOCAL library.
///
/// Documents are stored entirely on-device: the file is copied into the app's
/// documents directory and this metadata is persisted in shared_preferences.
/// Nothing is ever uploaded — the library is private to the phone.
class Document {
  const Document({
    required this.id,
    required this.name,
    required this.folder,
    required this.localPath,
    required this.addedAt,
    this.originalName,
    this.size,
  });

  /// Stable local id (a timestamp-based key).
  final String id;

  /// The user-given display name.
  final String name;

  /// The folder = a [TaskCategory].
  final TaskCategory folder;

  /// Absolute path to the on-device copy of the file.
  final String localPath;

  /// When it was added.
  final DateTime addedAt;

  /// The picked file's original filename (keeps the real extension for viewers).
  final String? originalName;

  /// File size in bytes, when known.
  final int? size;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folder': folder.name,
        'local_path': localPath,
        'added_at': addedAt.toIso8601String(),
        'original_name': originalName,
        'size': size,
      };

  factory Document.fromJson(Map<String, dynamic> j) => Document(
        id: j['id'] as String,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Document',
        folder: TaskCategory.values.firstWhere(
          (c) => c.name == j['folder'],
          orElse: () => TaskCategory.other,
        ),
        localPath: j['local_path'] as String? ?? '',
        addedAt: DateTime.tryParse(j['added_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        originalName: j['original_name'] as String?,
        size: (j['size'] as num?)?.toInt(),
      );
}
