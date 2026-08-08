import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import '../domain/onboarding_chip_catalog.dart';
import '../presentation/widgets/reminder_confirm_sheet.dart';

/// Turns the onboarding drafts into real server tasks.
///
/// Called on Finish, BEFORE phone verification — the tasks are created under
/// the current (anonymous) account, so the finish screen's live Home preview
/// shows genuine saved data. On verify, [AuthStore.login] claims this
/// anonymous session onto the verified phone; the claim WAITS for these writes
/// (see ApiClient.trackPendingWrite) so no row is moved mid-save.
///
/// Each task is ONE atomic create — title + date + repeat + category + brand
/// all in the same request. Never create-then-patch: losing the second step is
/// exactly how tasks used to arrive dateless.
///
/// Best-effort per task: one failed create never aborts the rest. Drafts are
/// committed CONCURRENTLY, so the whole set costs about one round-trip.
Future<void> commitOnboardingDrafts(
  TaskStore store,
  Map<String, ReminderDraft> drafts, {
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  // Leave the "initial load" shimmer immediately: the finish screen's Home
  // preview renders the real list frame right away, and each reminder pops in
  // as its create lands below.
  store.markLoaded();
  await Future.wait(
    drafts.entries.map((entry) async {
      final chipKey = entry.key;
      final draft = entry.value;
      try {
        await store.add(
          draft.name,
          dueAt: _nextOccurrence(today, draft),
          repeat: draft.frequency,
          category: _categoryOf(chipKey),
          source: chipKey,
          // Real brand logo when the catalog knows the domain (e.g. Netflix).
          iconDomain: _catalogItem(chipKey)?.domain,
        );
      } catch (_) {
        // Skip this one; keep going.
      }
    }),
  );
}

/// The catalog item behind a chip key (for its brand domain), if any.
OnboardingChipItem? _catalogItem(String key) {
  for (final section in kOnboardingChipSections) {
    for (final item in section.items) {
      if (item.key == key) return item;
    }
  }
  return null;
}

/// Map a chip key's prefix to the task's life category (schema `category`).
String _categoryOf(String key) {
  if (key.startsWith('subs_')) return 'subscription';
  if (key.startsWith('bills_')) return 'bill';
  if (key.startsWith('docs_')) return 'document';
  if (key.startsWith('family_')) return 'family';
  if (key.startsWith('insure_')) return 'insurance';
  if (key.startsWith('invest_')) return 'investment';
  return 'other';
}

/// The next date this reminder should fire, from its (month, day) and cadence.
///
/// - Yearly / one-off: the next time month/day comes around (this year if it's
///   still ahead, else next year).
/// - Monthly (and shorter): the next time the day-of-month arrives (this month
///   if the day hasn't passed, else next month), so a "10th every month" lands
///   on the upcoming 10th.
DateTime _nextOccurrence(DateTime today, ReminderDraft d) {
  final day = d.day.clamp(1, 28); // clamp to keep every month valid
  switch (d.frequency) {
    case RepeatCadence.yearly:
    case RepeatCadence.none:
      final month = d.month.clamp(1, 12);
      var year = today.year;
      var candidate = DateTime(year, month, day, 9);
      if (candidate.isBefore(today)) {
        candidate = DateTime(year + 1, month, day, 9);
      }
      return candidate;
    case RepeatCadence.monthly:
    case RepeatCadence.weekly:
    case RepeatCadence.daily:
      var year = today.year;
      var month = today.month;
      var candidate = DateTime(year, month, day, 9);
      if (candidate.isBefore(today)) {
        // Roll to next month (wrapping the year).
        month += 1;
        if (month > 12) {
          month = 1;
          year += 1;
        }
        candidate = DateTime(year, month, day, 9);
      }
      return candidate;
  }
}
