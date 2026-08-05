import 'catalog.dart';
import 'reminder.dart';

/// Turns a catalog item into a fully-prefilled [ReminderDraft].
///
/// This is what makes onboarding pure tapping: given only the item and today's
/// date, we compute a sensible next due date and reminder lead time so the user
/// never has to enter anything. They can refine any of it later.
class Scheduling {
  const Scheduling._();

  /// A best-guess next due date for [item], measured from [from] (today).
  ///
  ///  * evergreen / recurring → now + reviewInterval
  ///  * fixedYears            → now + validityYears (we don't know the issue
  ///                            date yet, so assume it starts today; the user
  ///                            corrects it when they add the real document)
  ///  * expiryOnly            → a soft default 12 months out
  static DateTime nextDueDate(CatalogItem item, {required DateTime from}) {
    switch (item.validityKind) {
      case ValidityKind.evergreen:
        final months = item.reviewIntervalMonths ?? 12;
        return _addMonths(from, months);
      case ValidityKind.fixedYears:
        final years = item.defaultValidityYears ?? 1;
        return DateTime(from.year + years, from.month, from.day);
      case ValidityKind.expiryOnly:
        return _addMonths(from, 12);
    }
  }

  /// The full prefilled draft for [item].
  static ReminderDraft draftFor(
    CatalogItem item, {
    required DateTime from,
  }) {
    final category = kCategoryByItemKey[item.key];
    final due = nextDueDate(item, from: from);
    final remindOn = due.subtract(Duration(days: item.defaultRemindDaysBefore));
    return ReminderDraft(
      category: category?.key ?? 'other',
      itemKey: item.key,
      title: item.title,
      expiryDate: due,
      remindOn: remindOn,
      remindDaysBefore: item.defaultRemindDaysBefore,
      metadata: const {'source': 'onboarding'},
    );
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    // Clamp the day so e.g. Jan 31 + 1 month → Feb 28.
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day < lastDay ? d.day : lastDay;
    return DateTime(year, month, day);
  }
}
