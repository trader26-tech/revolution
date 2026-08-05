import '../../categories/domain/item_catalog.dart';

/// The result of the add flow — a ready-to-save reminder for one item.
///
/// Kept minimal and self-contained: whatever backend/storage lands later reads
/// from this. Dates are already resolved (expiry computed from the anchor).
class ReminderDraft {
  const ReminderDraft({
    required this.itemKey,
    required this.title,
    required this.categoryName,
    this.expiryDate,
    required this.remindDaysBefore,
    this.documentNumber,
    this.hasReminder = true,
  });

  final String itemKey;
  final String title;
  final String categoryName;

  /// Null for store-only items (PAN, Voter ID) that have no expiry.
  final DateTime? expiryDate;
  final int remindDaysBefore;
  final String? documentNumber;
  final bool hasReminder;

  /// The date we'd actually nudge the user, if there's an expiry.
  DateTime? get remindOn =>
      expiryDate?.subtract(Duration(days: remindDaysBefore));

  Map<String, dynamic> toJson() => {
        'item_key': itemKey,
        'title': title,
        'category': categoryName,
        if (expiryDate != null) 'expiry_date': _fmt(expiryDate!),
        if (remindOn != null) 'remind_on': _fmt(remindOn!),
        'remind_days_before': remindDaysBefore,
        if (documentNumber != null && documentNumber!.isNotEmpty)
          'document_number': documentNumber,
        'has_reminder': hasReminder,
      };

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Builds a [ReminderDraft] from an [Item] and the single date the user gave,
/// applying the item's predefined rules (anchor + validity + lead time).
ReminderDraft buildDraft({
  required Item item,
  required String categoryName,
  DateTime? date, // the one date the user entered (issue or expiry)
  String? documentNumber,
}) {
  DateTime? expiry;
  switch (item.anchor) {
    case AnchorType.expiry:
      expiry = date;
    case AnchorType.issuePlusValidity:
      expiry = date?.add(Duration(days: item.validityDays ?? 365));
    case AnchorType.none:
      expiry = null;
  }
  return ReminderDraft(
    itemKey: item.key,
    title: item.name,
    categoryName: categoryName,
    expiryDate: expiry,
    remindDaysBefore: item.leadDays,
    documentNumber: documentNumber,
    hasReminder: item.hasReminder,
  );
}
