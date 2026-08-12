import '../../tasks/domain/task.dart';

/// One item in the Documents library.
///
/// A document comes from one of two sources, unified here so the Documents tab
/// shows everything in one place:
///   • [DocSource.standalone] — added directly in the Documents tab (its own
///     server record, id = the documents-row id).
///   • [DocSource.task]       — a file attached to a reminder (e.g. an insurance
///     policy). id = the TASK id; opened/shared via the task document endpoint.
enum DocSource { standalone, task }

class Document {
  const Document({
    required this.id,
    required this.name,
    required this.folder,
    required this.source,
    this.contentType,
    this.size,
    this.createdAt,
  });

  /// Standalone → documents-row id. Task → the task id.
  final String id;

  /// The user-facing name (standalone: user-given; task: the reminder title).
  final String name;

  /// The folder = a [TaskCategory] name (subscription/insurance/…).
  final TaskCategory folder;

  final DocSource source;
  final String? contentType;
  final int? size;
  final DateTime? createdAt;

  bool get isPdf => (contentType ?? '').contains('pdf') ||
      name.toLowerCase().endsWith('.pdf');

  /// Human size, e.g. "1.2 MB" — null when unknown.
  String? get sizeLabel {
    final s = size;
    if (s == null || s <= 0) return null;
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(0)} KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static TaskCategory _folderFrom(String? raw) {
    return TaskCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => TaskCategory.other,
    );
  }

  /// From a standalone `/documents` row.
  factory Document.fromJson(Map<String, dynamic> j) => Document(
        id: j['id'].toString(),
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Document',
        folder: _folderFrom(j['folder'] as String?),
        source: DocSource.standalone,
        contentType: j['content_type'] as String?,
        size: (j['size'] as num?)?.toInt(),
        createdAt: j['created_at'] == null
            ? null
            : DateTime.tryParse(j['created_at'] as String),
      );

  /// From a reminder that carries an attached document.
  factory Document.fromTask(Task t) => Document(
        id: t.id,
        name: t.title,
        folder: t.category,
        source: DocSource.task,
        contentType: null,
        createdAt: t.dueAt,
      );
}
