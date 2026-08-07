import 'dart:convert';

import '../../calendar/domain/occurrences.dart';
import '../../details/domain/currency.dart';
import '../../tasks/domain/task.dart';

/// Everything the daily notification needs for one day, precomputed at
/// schedule time: the headline, one line per item, and the task ids the
/// notification actions operate on. Pure Dart — no plugin imports — so it's
/// unit-testable and usable from the background isolate.
class DailyDigest {
  const DailyDigest({
    required this.date,
    required this.title,
    required this.lines,
    required this.oneOffIds,
    required this.recurringIds,
  });

  /// The day this digest covers (date-only).
  final DateTime date;

  /// Headline, e.g. "3 things due today".
  final String title;

  /// One line per item, e.g. "Netflix — ₹649".
  final List<String> lines;

  /// Ids the "Mark all done" action completes. Only one-offs: completing a
  /// recurring task would end its whole series, which is never what a
  /// notification tap means.
  final List<String> oneOffIds;

  /// Ids of recurring items due this day (shown, but not bulk-completed).
  final List<String> recurringIds;

  int get count => lines.length;

  /// Collapsed one-line body: "Netflix, Gym rent and 2 more".
  String get summaryLine {
    final titles = lines;
    if (titles.isEmpty) return '';
    if (titles.length == 1) return titles.first;
    if (titles.length == 2) return '${titles[0]}  ·  ${titles[1]}';
    return '${titles[0]}  ·  ${titles[1]}  ·  +${titles.length - 2} more';
  }

  /// Expanded multi-line body (iOS long-press / Android big text fallback).
  String get expandedBody => lines.join('\n');

  // The payload travels on the notification and comes back when the user taps
  // an action, possibly days later in a background isolate with no app state —
  // so it carries everything the action handler needs.
  String toPayload() => jsonEncode({
        'date': date.toIso8601String(),
        'title': title,
        'lines': lines,
        'one_off_ids': oneOffIds,
        'recurring_ids': recurringIds,
      });

  static DailyDigest? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final j = jsonDecode(payload) as Map<String, dynamic>;
      return DailyDigest(
        date: DateTime.parse(j['date'] as String),
        title: j['title'] as String? ?? '',
        lines: (j['lines'] as List? ?? const []).cast<String>(),
        oneOffIds: (j['one_off_ids'] as List? ?? const []).cast<String>(),
        recurringIds:
            (j['recurring_ids'] as List? ?? const []).cast<String>(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Builds the single digest for [day] from the user's tasks, or null when
/// nothing is due (no notification that day — silence over noise).
///
/// Includes tasks with an active reminder that aren't already done; recurring
/// tasks are expanded through the same [expandOccurrences] the calendar uses,
/// so the notification always agrees with what the app shows.
DailyDigest? buildDailyDigest(List<Task> tasks, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final eligible =
      tasks.where((t) => t.reminderOn && !t.done).toList(growable: false);
  final occ = expandOccurrences(eligible, from: d, to: d);
  if (occ.isEmpty) return null;

  final lines = <String>[];
  final oneOffIds = <String>[];
  final recurringIds = <String>[];
  for (final o in occ) {
    final t = o.task;
    lines.add(t.hasAmount ? '${t.title} — ${_money(t)}' : t.title);
    (t.repeat == RepeatCadence.none ? oneOffIds : recurringIds).add(t.id);
  }

  final title = occ.length == 1
      ? 'Due today: ${occ.first.task.title}'
      : '${occ.length} things due today';

  return DailyDigest(
    date: d,
    title: title,
    lines: lines,
    oneOffIds: oneOffIds,
    recurringIds: recurringIds,
  );
}

/// "₹1,22,484" — currency-grouped, decimals only when the amount has them.
String _money(Task t) {
  final c = currencyOf(t.currency);
  final amount = t.amount!;
  final whole = amount == amount.roundToDouble();
  final fixed = amount.toStringAsFixed(whole ? 0 : c.decimals);
  return '${c.symbol}${formatAmount(fixed, c.grouping)}';
}
