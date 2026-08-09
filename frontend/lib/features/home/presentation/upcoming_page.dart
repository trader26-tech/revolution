import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../../details/domain/currency.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';
import 'widgets/home_dashboard.dart' show WeekStripCalendar;

/// The full upcoming list — every scheduled, unfinished reminder from [from]
/// onward, soonest first, grouped under a date header (Today / Tomorrow / a
/// weekday+date). Opened by the "Up next" right-arrow on Home.
class UpcomingPage extends StatefulWidget {
  const UpcomingPage({
    super.key,
    required this.tasks,
    required this.onTap,
    this.from,
  });

  final List<Task> tasks;
  final void Function(Task) onTap;

  /// Start of the window (inclusive, by day). Defaults to today.
  final DateTime? from;

  @override
  State<UpcomingPage> createState() => _UpcomingPageState();
}

class _UpcomingPageState extends State<UpcomingPage> {
  late DateTime _selected;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _selected = _day(widget.from ?? DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = _day(_selected);

    // Scheduled, undone, on/after the SELECTED day, soonest first.
    final upcoming = widget.tasks
        .where((t) =>
            t.isScheduled && !t.done && !_day(t.dueAt!).isBefore(start))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    // Group into date buckets, preserving sort order.
    final groups = <DateTime, List<Task>>{};
    for (final t in upcoming) {
      groups.putIfAbsent(_day(t.dueAt!), () => []).add(t);
    }
    final keys = groups.keys.toList()..sort();

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: back + title.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Upcoming',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // The week-strip calendar — pick a day to jump the list to it.
              WeekStripCalendar(
                tasks: widget.tasks,
                selected: _selected,
                onSelect: (d) => setState(() => _selected = _day(d)),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: upcoming.isEmpty
                    ? const _NothingUpcoming()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        itemCount: keys.length,
                        itemBuilder: (_, i) {
                          final day = keys[i];
                          final items = groups[day]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                    top: i == 0 ? 8 : 24, bottom: 12),
                                child: _DayHeader(
                                    day: day, now: now, count: items.length),
                              ),
                              for (final t in items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _UpcomingRow(
                                      task: t, onTap: () => widget.onTap(t)),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// A day-column header in the vertical Upcoming list — the big day number, the
/// weekday + month, and a count of what's on that day. Only the current day is
/// called "Today"; every other day shows its exact date.
class _DayHeader extends StatelessWidget {
  const _DayHeader(
      {required this.day, required this.now, required this.count});
  final DateTime day;
  final DateTime now;
  final int count;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day == today;
    const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    final kicker = isToday ? 'TODAY' : wd[day.weekday - 1];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Big day number.
        Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: -1,
            color: isToday ? AppColors.accent : AppColors.ink,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kicker,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: isToday ? AppColors.accent : AppColors.inkFaint,
              ),
            ),
            Text(
              mo[day.month - 1],
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Count pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count ${count == 1 ? 'item' : 'items'}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

Color _catColor(TaskCategory c) => c.color;

/// One upcoming reminder as a full-width glass row.
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.task, required this.onTap});
  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = task.category;
    final tint = _catColor(cat);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            _Avatar(task: task, tint: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(
                    task.hasAmount
                        ? '${currencyOf(task.currency).symbol}${task.amount!.toStringAsFixed(task.amount == task.amount!.roundToDouble() ? 0 : 2)} · ${frequencyLabel(task.repeat, task.repeatTimes)}'
                        : cat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _timeLabel(task.dueAt!),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime d) {
    final h = d.hour, m = d.minute;
    if (h == 0 && m == 0) return '';
    final ap = h < 12 ? 'AM' : 'PM';
    final hh = h % 12 == 0 ? 12 : h % 12;
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm $ap';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.task, required this.tint});
  final Task task;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (task.hasImage) {
      final circular = task.category == TaskCategory.birthday;
      return Container(
        width: 46,
        height: 46,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(circular ? 46 : 12),
        ),
        child: Image.file(File(task.imagePath!), fit: BoxFit.cover),
      );
    }
    // A logo when there's one; otherwise the stylized first-letter avatar.
    return BrandLogo(
      brand: task.hasIcon
          ? Brand(name: task.iconName ?? task.title, domain: task.iconDomain ?? '')
          : Brand(name: task.title, domain: ''),
      size: 46,
      radius: 12,
    );
  }
}

class _NothingUpcoming extends StatelessWidget {
  const _NothingUpcoming();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 40, color: AppColors.accent),
          ),
          const SizedBox(height: 18),
          const Text('Nothing upcoming',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text('You’re all caught up.',
              style: TextStyle(color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
