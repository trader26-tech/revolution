import 'package:flutter/material.dart';

import '../../../core/theme/bamboo_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../mascot/presentation/bobo_mascot.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/domain/streak.dart';
import '../../reminders/presentation/reminders_controller.dart';

/// The Calendar tab: a month grid of renewal due-dates with a Bobo streak
/// header. Days that have a renewal are dotted (colour = urgency); tapping a day
/// lists what's due. When nothing is overdue, Bobo is excited and a flame burns.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller});

  final RemindersController controller;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month; // first of the visible month
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int by) {
    setState(() {
      _month = DateTime(_month.year, _month.month + by);
    });
  }

  /// reminders keyed by their expiry day (date-only).
  Map<DateTime, List<Reminder>> _byDay(List<Reminder> reminders) {
    final map = <DateTime, List<Reminder>>{};
    for (final r in reminders) {
      final d = DateTime(
          r.expiryDate.year, r.expiryDate.month, r.expiryDate.day);
      map.putIfAbsent(d, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final reminders = widget.controller.reminders;
        final streak = widget.controller.streak;
        final byDay = _byDay(reminders);
        final selectedItems = _selected == null
            ? const <Reminder>[]
            : (byDay[_selected!] ?? const []);

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Bamboo.mist, Bamboo.cream, Bamboo.creamHi],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
              children: [
                _StreakHeader(streak: streak),
                const SizedBox(height: 12),
                _MonthCard(
                  month: _month,
                  selected: _selected,
                  byDay: byDay,
                  onPrev: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onSelectDay: (d) => setState(() => _selected = d),
                ),
                const SizedBox(height: 16),
                _DayDetail(day: _selected, items: selectedItems),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bobo + the flame streak, celebrating a clean run.
class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.streak});

  final StreakStatus streak;

  @override
  Widget build(BuildContext context) {
    final onStreak = streak.onStreak;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Bamboo.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: BoboMascot(
              size: 92,
              mood: onStreak ? BoboMood.excited : BoboMood.sad,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(onStreak ? '🔥' : '💤',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      onStreak ? streak.flameLabel : 'Streak paused',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Bamboo.ink,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  onStreak
                      ? "Nothing overdue — Bobo's proud of you. Keep it going!"
                      : "${streak.overdueCount} overdue. Clear ${streak.overdueCount == 1 ? 'it' : 'them'} to relight the flame.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Bamboo.inkSoft,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.onPrev,
    required this.onNext,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<DateTime, List<Reminder>> byDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDay;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    // Grid math: Dart weekday is 1=Mon..7=Sun, which matches a Mon-first grid.
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1; // 0..6
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final items = byDay[date] ?? const [];
      cells.add(_DayCell(
        day: day,
        isToday: date == todayDate,
        isSelected: selected != null && date == selected,
        urgency: _urgencyFor(items),
        onTap: () => onSelectDay(date),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Bamboo.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Bamboo.ink,
                      ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (final w in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        color: Bamboo.inkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
        ],
      ),
    );
  }

  _Urgency? _urgencyFor(List<Reminder> items) {
    if (items.isEmpty) return null;
    if (items.any((r) => r.isExpired)) return _Urgency.overdue;
    if (items.any((r) => r.isDueSoon)) return _Urgency.due;
    return _Urgency.upcoming;
  }
}

enum _Urgency { overdue, due, upcoming }

Color _urgencyColor(_Urgency u) => switch (u) {
      _Urgency.overdue => const Color(0xFFE5484D),
      _Urgency.due => const Color(0xFFFF8A3D),
      _Urgency.upcoming => Bamboo.green,
    };

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.urgency,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final _Urgency? urgency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isSelected
              ? Bamboo.green.withValues(alpha: 0.18)
              : isToday
                  ? Bamboo.sprout.withValues(alpha: 0.5)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Bamboo.green, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: Bamboo.ink,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 6,
              child: urgency == null
                  ? null
                  : Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _urgencyColor(urgency!),
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What's due on the tapped day.
class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day, required this.items});

  final DateTime? day;
  final List<Reminder> items;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Bamboo.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFmt.medium(day!),
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Bamboo.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Row(
              children: [
                const Text('🦴', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nothing due this day — enjoy the calm.',
                    style: text.bodyMedium?.copyWith(color: Bamboo.inkSoft),
                  ),
                ),
              ],
            )
          else
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _urgencyColor(
                          r.isExpired
                              ? _Urgency.overdue
                              : r.isDueSoon
                                  ? _Urgency.due
                                  : _Urgency.upcoming,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.title,
                        style: text.bodyMedium?.copyWith(
                          color: Bamboo.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      DateFmt.relativeDays(r.daysUntilExpiry),
                      style: text.bodySmall?.copyWith(color: Bamboo.inkSoft),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
