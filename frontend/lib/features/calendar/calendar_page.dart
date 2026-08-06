import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../brand/data/brand_catalog.dart';
import '../brand/domain/brand.dart';
import '../brand/presentation/brand_logo.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import 'domain/money.dart';
import 'domain/occurrences.dart';

/// The Calendar — a real month grid of everything you're tracking.
///
/// The header shows the month with its total + upcoming spend. Each day is a
/// soft rounded tile carrying the brand logos of what's due that day. Today is
/// tinted; the selected day lifts a draggable sheet listing that day's items
/// with their next renewal + amount. Tap an item to edit it.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.store});

  final TaskStore store;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month; // first day of the visible month
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by);
        _selected = null; // dismiss the day sheet when changing month
      });

  Future<void> _edit(Task task) async {
    final updated = await showTaskDetailsSheet(context, task);
    if (updated != null) widget.store.update(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        // Expand occurrences across the visible month (+ padding so leading /
        // trailing days of adjacent months are covered too).
        final first = DateTime(_month.year, _month.month, 1);
        final last = DateTime(_month.year, _month.month + 1, 0);
        final monthOcc = expandOccurrences(
          widget.store.tasks,
          from: first,
          to: last,
        );
        final byDay = groupByDay(monthOcc);

        final selectedItems = _selected == null
            ? const <Occurrence>[]
            : (byDay[_selected!] ?? const <Occurrence>[]);

        return Stack(
          children: [
            // --- the scrollable calendar ---
            SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                children: [
                  _SpendHeader(
                    month: _month,
                    total: monthTotal(monthOcc),
                    upcoming: upcomingTotal(monthOcc),
                    onPrev: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                  ),
                  const SizedBox(height: 18),
                  _WeekdayRow(),
                  const SizedBox(height: 8),
                  _MonthGrid(
                    month: _month,
                    selected: _selected,
                    byDay: byDay,
                    onSelectDay: (d) => setState(() => _selected = d),
                  ),
                ],
              ),
            ),

            // --- the draggable day sheet, lifted when a day is selected ---
            if (_selected != null)
              _DaySheet(
                key: ValueKey(_selected),
                day: _selected!,
                items: selectedItems,
                onClose: () => setState(() => _selected = null),
                onTapItem: _edit,
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header: month name + Total / Upcoming
// ---------------------------------------------------------------------------
class _SpendHeader extends StatelessWidget {
  const _SpendHeader({
    required this.month,
    required this.total,
    required this.upcoming,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final MoneyTotal total;
  final MoneyTotal upcoming;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _names[month.month - 1],
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            _RoundBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
            const SizedBox(width: 8),
            _RoundBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
        const SizedBox(height: 6),
        // Total + Upcoming, each a "figure Label" pair.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _Figure(value: total.formatted, label: 'Total'),
            const SizedBox(width: 20),
            _Figure(
              value: upcoming.formatted,
              label: 'Upcoming',
              muted: upcoming.isZero,
            ),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.muted = false});
  final String value;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: muted ? AppColors.inkFaint : AppColors.ink,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.inkFaint,
          ),
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(side: BorderSide(color: AppColors.cardBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.ink, size: 22),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekday header row
// ---------------------------------------------------------------------------
class _WeekdayRow extends StatelessWidget {
  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final w in _labels)
          Expanded(
            child: Center(
              child: Text(
                w,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Month grid
// ---------------------------------------------------------------------------
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<DateTime, List<Occurrence>> byDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1; // Mon-first grid
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_DayCell(
        day: day,
        isToday: date == today,
        isSelected: selected != null && date == selected,
        items: byDay[date] ?? const [],
        onTap: () => onSelectDay(date),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 0.66,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.items,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final List<Occurrence> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selected wins visually; then today; then a plain soft tile.
    final Color fill;
    final Border? border;
    if (isSelected) {
      fill = AppColors.accent.withValues(alpha: 0.14);
      border = Border.all(color: AppColors.accent, width: 1.5);
    } else if (isToday) {
      fill = AppColors.accent.withValues(alpha: 0.07);
      border = null;
    } else {
      fill = AppColors.card;
      border = Border.all(color: AppColors.cardBorder);
    }

    final numberColor = isSelected || isToday ? AppColors.accentDeep : AppColors.ink;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: border,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                color: numberColor,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(child: _DayLogos(items: items)),
          ],
        ),
      ),
    );
  }
}

/// The logo (and "+N") shown under a date number.
class _DayLogos extends StatelessWidget {
  const _DayLogos({required this.items});
  final List<Occurrence> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // One prominent logo + a "+N" pill when there are more (matches the design:
    // the Spotify logo with "+20" beneath on a busy day).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(brand: _brandOf(items.first.task), size: 26, radius: 8),
        if (items.length > 1) ...[
          const SizedBox(height: 3),
          Text(
            '+${items.length - 1}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day sheet (draggable, lifted when a day is selected)
// ---------------------------------------------------------------------------
class _DaySheet extends StatelessWidget {
  const _DaySheet({
    super.key,
    required this.day,
    required this.items,
    required this.onClose,
    required this.onTapItem,
  });

  final DateTime day;
  final List<Occurrence> items;
  final VoidCallback onClose;
  final ValueChanged<Task> onTapItem;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final total = totalOf(items);
    final hasItems = items.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.20,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.42],
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Grabber.
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 10),
                  width: double.infinity,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header row: date + day total.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${day.day} ${_months[day.month - 1]} ${day.year}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (hasItems && !total.isZero) ...[
                      Text(
                        total.formatted,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairline),
              Expanded(
                child: hasItems
                    ? ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _DayItemRow(
                          occ: items[i],
                          onTap: () => onTapItem(items[i].task),
                        ),
                      )
                    : _EmptyDay(controller: controller),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: const [
        Icon(Icons.event_available_rounded,
            size: 44, color: AppColors.inkFaint),
        SizedBox(height: 14),
        Text(
          'Nothing due this day',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Days with subscriptions or reminders will show up here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

/// One item in the day sheet: logo, name, "Renews in N days · date", amount.
class _DayItemRow extends StatelessWidget {
  const _DayItemRow({required this.occ, required this.onTap});
  final Occurrence occ;
  final VoidCallback onTap;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final t = occ.task;
    final subtitle = _renewLine(occ);

    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BrandLogo(brand: _brandOf(t), size: 44, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _amountLabel(t),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 15.5,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// "Renews in N days · 3 Aug 2027" for a recurring item; "One-time" otherwise.
  String? _renewLine(Occurrence o) {
    final t = o.task;
    if (t.repeat == RepeatCadence.none) {
      return t.reminderOn ? 'One-time' : null;
    }
    final next = nextOccurrenceAfter(o.date, t.repeat);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = next.difference(today).inDays;
    final dateStr = '${next.day} ${_months[next.month - 1]} ${next.year}';
    final when = days <= 0
        ? 'Renews today'
        : days == 1
            ? 'Renews tomorrow'
            : 'Renews in $days days';
    return '$when · $dateStr';
  }

  String _amountLabel(Task t) {
    if (t.amount == null) return '—';
    return MoneyTotal(amount: t.amount!, currency: t.currency).formatted;
  }
}

/// Build a Brand for a task's logo. If the task has a domain, use it directly;
/// otherwise re-resolve the name (which also checks curated/custom logos), so
/// bucket logos and aliases show correctly on the calendar too.
Brand _brandOf(Task t) {
  final name = (t.iconName?.isNotEmpty ?? false) ? t.iconName! : t.title;
  final domain = t.iconDomain ?? '';
  if (domain.isNotEmpty) return Brand(name: name, domain: domain);
  return BrandCatalog.resolve(name);
}
