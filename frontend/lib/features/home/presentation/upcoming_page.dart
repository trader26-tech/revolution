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

  /// Open a month/year/day picker so the user can jump anywhere — the calendar
  /// strip then scrolls to the chosen day and the list shows just that day.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Jump to a date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.card,
            onSurface: AppColors.ink,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgTop),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selected = _day(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sel = _day(_selected);

    // ONLY the selected day's scheduled, undone reminders — soonest first. The
    // calendar drives it, so picking a day shows exactly that day, nothing else.
    final upcoming = widget.tasks
        .where((t) => t.isScheduled && !t.done && _day(t.dueAt!) == sel)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    // A single group — the selected day.
    final keys = upcoming.isEmpty ? <DateTime>[] : [sel];
    final groups = {if (upcoming.isNotEmpty) sel: upcoming};

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      // Cap text scale so a large system font can't overflow the calendar cells
      // or the fixed-size row elements.
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Container(
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
              // Header: back + title + a month/year picker pill.
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
                    const Spacer(),
                    // The month/year pill — tap to jump to any date.
                    _MonthPill(
                      day: _selected,
                      onTap: _pickDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // The week-strip calendar — a wide window so the month picker can
              // jump anywhere within the year. Picking a day filters the list.
              WeekStripCalendar(
                tasks: widget.tasks,
                selected: _selected,
                onSelect: (d) => setState(() => _selected = _day(d)),
                daysBefore: 30,
                daysAhead: 365,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: upcoming.isEmpty
                    ? _NothingUpcoming(day: sel, now: now)
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
      ),
    );
  }
}

/// The month/year pill in the header — shows the selected month + year and
/// opens a date picker on tap, so any month is a couple of taps away.
class _MonthPill extends StatelessWidget {
  const _MonthPill({required this.day, required this.onTap});
  final DateTime day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 15, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              '${mo[day.month - 1]} ${day.year}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: AppColors.accent),
          ],
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
  const _NothingUpcoming({required this.day, required this.now});
  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    final label = day == today
        ? 'today'
        : '${wd[day.weekday - 1]} ${day.day} ${mo[day.month - 1]}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
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
            Text('Nothing on $label',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Pick another day from the calendar above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
