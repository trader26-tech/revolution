import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../../details/domain/currency.dart';
import '../../tasks/domain/task.dart';

/// The full upcoming list — every scheduled, unfinished reminder from [from]
/// onward, soonest first, grouped under a date header (Today / Tomorrow / a
/// weekday+date). Opened by the "Up next" right-arrow on Home.
class UpcomingPage extends StatelessWidget {
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

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = _day(from ?? now);

    // Scheduled, undone, on/after `start`, soonest first.
    final upcoming = tasks
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
                                padding:
                                    EdgeInsets.only(top: i == 0 ? 8 : 22, bottom: 10),
                                child: Text(
                                  _dateHeader(day, now),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              for (final t in items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _UpcomingRow(
                                      task: t, onTap: () => onTap(t)),
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

  String _dateHeader(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${wd[day.weekday - 1]} · ${day.day} ${mo[day.month - 1]}';
  }
}

Color _catColor(TaskCategory c) => switch (c) {
      TaskCategory.subscription => AppColors.accent,
      TaskCategory.birthday => const Color(0xFFFF6FB5),
      TaskCategory.insurance => const Color(0xFF34D399),
      TaskCategory.other => const Color(0xFFA5B4FC),
    };

IconData _catIcon(TaskCategory c) => switch (c) {
      TaskCategory.subscription => Icons.subscriptions_rounded,
      TaskCategory.birthday => Icons.cake_rounded,
      TaskCategory.insurance => Icons.shield_rounded,
      TaskCategory.other => Icons.push_pin_rounded,
    };

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
                        ? '${currencyOf(task.currency).symbol}${task.amount!.toStringAsFixed(task.amount == task.amount!.roundToDouble() ? 0 : 2)} · ${task.repeat.label}'
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
    if (task.hasIcon) {
      return BrandLogo(
        brand: Brand(
            name: task.iconName ?? task.title, domain: task.iconDomain ?? ''),
        size: 46,
        radius: 12,
      );
    }
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_catIcon(task.category), size: 23, color: tint),
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
