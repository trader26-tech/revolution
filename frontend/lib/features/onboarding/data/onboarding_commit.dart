import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import '../presentation/widgets/reminder_confirm_sheet.dart';

/// Turns the onboarding drafts into real server tasks.
///
/// Called on Finish, BEFORE phone verification — the tasks are created under the
/// current (anonymous) owner id, so the finish screen's live Home preview shows
/// genuine saved data. On verify, [AuthStore.login] claims this anonymous
/// session onto the verified phone, so nothing is lost.
///
/// Best-effort per task: one failed create never aborts the rest.
///
/// Drafts are committed CONCURRENTLY — each draft's create+update chain runs in
/// parallel with the others — so the whole set costs about one round-trip of
/// latency instead of (2 × N) sequential ones. On a handful of picks this is the
/// difference between an instant finish and a multi-second wait.
Future<void> commitOnboardingDrafts(
  TaskStore store,
  Map<String, ReminderDraft> drafts, {
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  // Leave the "initial load" shimmer immediately: the finish screen's Home
  // preview renders the real list frame right away, and each reminder pops in as
  // its create lands below (instead of shimmering until a server fetch that
  // never happens on this path).
  store.markLoaded();
  await Future.wait(
    drafts.values.map((draft) async {
      try {
        final created = await store.add(draft.name);
        await store.update(
          created.copyWith(
            dueAt: _nextOccurrence(today, draft),
            repeat: draft.frequency,
          ),
        );
      } catch (_) {
        // Skip this one; keep going.
      }
    }),
  );
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
