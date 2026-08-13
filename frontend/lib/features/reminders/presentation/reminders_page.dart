import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../calendar/domain/occurrences.dart';
import '../../details/domain/currency.dart';
import '../../settings/data/profile_store.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';

/// The "Reminders" screen — a place to always refer back to what's been and
/// what's coming. Lists every reminder occurrence with the exact time it fires
/// (or fired), grouped by day: UPCOMING first (soonest at the top), then EARLIER
/// (recently passed). Each reminder shows at its OWN time — the task's time when
/// set, else the default reminder time from Settings — matching what actually
/// gets sent.
class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key, required this.store});

  final TaskStore store;

  /// How far back / forward we list occurrences.
  static const _pastDays = 14;
  static const _futureDays = 45;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final from = today.subtract(const Duration(days: _pastDays));
            final to = today.add(const Duration(days: _futureDays));

            // Same expansion the scheduler uses, so this list agrees with what
            // actually fires. Skip done + reminder-off items.
            final eligible = store.tasks
                .where((t) => t.reminderOn && !t.done)
                .toList(growable: false);
            final occ = expandOccurrences(eligible, from: from, to: to);

            // Attach each occurrence's real fire moment, then split by now.
            final defMin = ProfileStore.instance.defaultReminderMin;
            final entries = [
              for (final o in occ)
                _Entry(task: o.task, fireAt: _fireAt(o.task, o.date, defMin)),
            ]..sort((a, b) => a.fireAt.compareTo(b.fireAt));

            final upcoming =
                entries.where((e) => e.fireAt.isAfter(now)).toList();
            final past = entries
                .where((e) => !e.fireAt.isAfter(now))
                .toList()
              ..sort((a, b) => b.fireAt.compareTo(a.fireAt)); // most recent first

            return Column(
              children: [
                _TopBar(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: (upcoming.isEmpty && past.isEmpty)
                      ? const _Empty()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          children: [
                            if (upcoming.isNotEmpty) ...[
                              const _SectionLabel('Upcoming'),
                              ..._grouped(upcoming, now),
                            ],
                            if (past.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const _SectionLabel('Earlier'),
                              ..._grouped(past, now, past: true),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Day-header + rows for a run of entries, grouped by calendar day.
  List<Widget> _grouped(List<_Entry> entries, DateTime now,
      {bool past = false}) {
    final out = <Widget>[];
    DateTime? lastDay;
    for (final e in entries) {
      final day = DateTime(e.fireAt.year, e.fireAt.month, e.fireAt.day);
      if (lastDay == null || day != lastDay) {
        out.add(Padding(
          padding: EdgeInsets.only(top: lastDay == null ? 6 : 16, bottom: 8, left: 4),
          child: Text(
            _dayLabel(day, now),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.inkSoft,
            ),
          ),
        ));
        lastDay = day;
      }
      out.add(_ReminderRow(entry: e, past: past));
    }
    return out;
  }

  static DateTime _fireAt(Task task, DateTime date, int defaultMin) {
    final due = task.dueAt;
    final hasTime = due != null && !(due.hour == 0 && due.minute == 0);
    final minutes = hasTime ? due.hour * 60 + due.minute : defaultMin;
    return DateTime(
        date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  }

  static String _dayLabel(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff == -1) return 'YESTERDAY';
    const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    return '${wd[day.weekday - 1]} · ${day.day} ${mo[day.month - 1]}';
  }
}

class _Entry {
  const _Entry({required this.task, required this.fireAt});
  final Task task;
  final DateTime fireAt;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onTap: onBack,
          ),
          const SizedBox(width: 6),
          const Text(
            'Reminders',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// One reminder occurrence: icon + name + supporting line, with the exact fire
/// time on the right. Past ones are dimmed with a small "sent" check.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.entry, required this.past});
  final _Entry entry;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Opacity(
        opacity: past ? 0.6 : 1.0,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(task.category.icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(task),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _time(entry.fireAt),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: past ? AppColors.inkSoft : AppColors.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (past) ...[
                  const SizedBox(height: 3),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 12, color: AppColors.inkFaint),
                      SizedBox(width: 2),
                      Text('sent',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkFaint)),
                    ],
                  ),
                ] else
                  const SizedBox(height: 3),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Task task) {
    if (task.hasAmount) {
      final cur = currencyOf(task.currency);
      final a = task.amount!;
      final body =
          a == a.roundToDouble() ? a.round().toString() : a.toStringAsFixed(2);
      final base = '${cur.symbol}$body';
      return task.repeat == RepeatCadence.none
          ? base
          : '$base · ${frequencyLabel(task.repeat, task.repeatTimes).toLowerCase()}';
    }
    final note = (task.note ?? '').trim();
    if (note.isNotEmpty) return note;
    return task.repeat == RepeatCadence.none
        ? task.category.label
        : frequencyLabel(task.repeat, task.repeatTimes);
  }

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 38, color: AppColors.accent),
            ),
            const SizedBox(height: 18),
            const Text(
              'No reminders yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add a reminder with a date and it will show up here, with the exact time it fires.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
