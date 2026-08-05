/// Domain model mirroring a row of the backend `reminders` table.
class Reminder {
  const Reminder({
    required this.id,
    required this.category,
    required this.itemKey,
    required this.title,
    this.documentNumber,
    this.issueDate,
    required this.expiryDate,
    required this.remindOn,
    required this.remindDaysBefore,
    this.metadata = const {},
  });

  final String id;
  final String category;
  final String itemKey;
  final String title;
  final String? documentNumber;
  final DateTime? issueDate;
  final DateTime expiryDate;
  final DateTime remindOn;
  final int remindDaysBefore;
  final Map<String, dynamic> metadata;

  /// Whole days until expiry from today (negative if already expired).
  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return due.difference(today).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;

  /// True once we've entered the reminder window (past remind_on, not expired).
  bool get isDueSoon {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(DateTime(remindOn.year, remindOn.month, remindOn.day)) &&
        !isExpired;
  }

  static DateTime? _parseDate(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        category: json['category'] as String,
        itemKey: json['item_key'] as String,
        title: json['title'] as String,
        documentNumber: json['document_number'] as String?,
        issueDate: _parseDate(json['issue_date']),
        expiryDate: DateTime.parse(json['expiry_date'] as String),
        remindOn: DateTime.parse(json['remind_on'] as String),
        remindDaysBefore: (json['remind_days_before'] as num).toInt(),
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// Payload sent to the backend to create a reminder.
class ReminderDraft {
  ReminderDraft({
    required this.category,
    required this.itemKey,
    required this.title,
    this.documentNumber,
    this.issueDate,
    required this.expiryDate,
    required this.remindOn,
    required this.remindDaysBefore,
    this.metadata = const {},
  });

  final String category;
  final String itemKey;
  final String title;
  final String? documentNumber;
  final DateTime? issueDate;
  final DateTime expiryDate;
  final DateTime remindOn;
  final int remindDaysBefore;
  final Map<String, dynamic> metadata;

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'category': category,
        'item_key': itemKey,
        'title': title,
        if (documentNumber != null && documentNumber!.isNotEmpty)
          'document_number': documentNumber,
        if (issueDate != null) 'issue_date': _fmt(issueDate!),
        'expiry_date': _fmt(expiryDate),
        'remind_on': _fmt(remindOn),
        'remind_days_before': remindDaysBefore,
        'metadata': metadata,
      };
}
