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
  // The tapped day. Null by default — nothing is selected on launch, not even
  // today. A day only becomes selected when the user actually taps it.
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by);
        _selected = null; // clear any selection when changing month
      });

  void _jumpTo(DateTime monthYear) => setState(() {
        _month = DateTime(monthYear.year, monthYear.month);
        _selected = null;
      });

  Future<void> _edit(Task task) async {
    final updated = await showTaskDetailsSheet(context, task);
    if (updated != null) widget.store.update(updated);
  }

  /// Tapping a day selects it and — if it has items — opens the day sheet as a
  /// MODAL, so it overlays the app's bottom nav (the user dismisses it to get
  /// the nav back). Tapping an empty day just highlights it.
  void _onSelectDay(DateTime day, List<Occurrence> items) {
    setState(() => _selected = day);
    if (items.isEmpty) return;
    showDaySheet(
      context,
      day: day,
      items: items,
      onTapItem: _edit,
    ).whenComplete(() {
      // Clear the highlight once the sheet is dismissed.
      if (mounted) setState(() => _selected = null);
    });
  }

  Future<void> _pickMonthYear() async {
    final picked = await showMonthYearPicker(context, current: _month);
    if (picked != null) _jumpTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        // Expand occurrences across the visible month.
        final first = DateTime(_month.year, _month.month, 1);
        final last = DateTime(_month.year, _month.month + 1, 0);
        final monthOcc = expandOccurrences(
          widget.store.tasks,
          from: first,
          to: last,
        );
        final byDay = groupByDay(monthOcc);

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
            children: [
              // Month nav (tap the month → month+year picker).
              _MonthNav(
                month: _month,
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
                onTapMonth: _pickMonthYear,
              ),
              const SizedBox(height: 14),
              // A clean top summary of the month's spend.
              _MonthOverview(
                total: monthTotal(monthOcc),
                count: monthOcc.length,
              ),
              const SizedBox(height: 18),
              _WeekdayRow(),
              const SizedBox(height: 8),
              _MonthGrid(
                month: _month,
                selected: _selected,
                byDay: byDay,
                onSelectDay: (d) => _onSelectDay(d, byDay[d] ?? const []),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The month nav pill: ‹ prev · Month Year (tap → month+year picker) · next ›.
class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onTapMonth,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapMonth;

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _ArrowBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTapMonth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    '${_names[month.month - 1]} ${month.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _ArrowBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

/// The top month overview: how much is going out this month + item count. Shown
/// as one clean card. (Everything tracked is a cost, so there's no "coming in".)
class _MonthOverview extends StatelessWidget {
  const _MonthOverview({required this.total, required this.count});

  final MoneyTotal total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Going out this month',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total.isZero ? '—' : total.formatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          // Item count pill.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  count == 1 ? 'item' : 'items',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

/// A round arrow button inside the month nav pill.
class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      shape: const CircleBorder(),
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
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 0.86, // compact boxes — number + a count pill
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
    // Rounded SQUARE box per day.
    //  • SELECTED (user tapped)  → filled accent, white number.
    //  • TODAY (not selected)    → just a soft accent RING — not a filled dark
    //                              box (that looked "selected" when it wasn't).
    //  • has items               → faint card fill.
    //  • empty                   → plain hairline box.
    final bool hasItems = items.isNotEmpty;

    final Color boxFill;
    final Color boxBorder;
    double borderW = 1;
    if (isSelected) {
      boxFill = AppColors.accent;
      boxBorder = AppColors.accent;
      borderW = 1.4;
    } else if (isToday) {
      boxFill = AppColors.card;
      boxBorder = AppColors.accent;
      borderW = 1.6;
    } else if (hasItems) {
      boxFill = AppColors.card;
      boxBorder = AppColors.cardBorder;
    } else {
      boxFill = AppColors.bg;
      boxBorder = AppColors.hairline;
    }

    final Color numberColor = isSelected
        ? Colors.white
        : (isToday ? AppColors.accentDeep : AppColors.ink);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: boxFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: boxBorder, width: borderW),
        ),
        padding: const EdgeInsets.fromLTRB(2, 5, 2, 5),
        child: Column(
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight:
                    isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                color: numberColor,
              ),
            ),
            const SizedBox(height: 4),
            // A count badge (not logos) showing how many are scheduled that day.
            Expanded(
              child: _DayCount(count: items.length, onAccent: isSelected),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small pill showing how many tasks are on a day (no brand logos).
class _DayCount extends StatelessWidget {
  const _DayCount({required this.count, required this.onAccent});
  final int count;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    // On a selected (accent) cell, use a light-on-dark pill; otherwise accent.
    final bg = onAccent
        ? Colors.white.withValues(alpha: 0.25)
        : AppColors.accent.withValues(alpha: 0.14);
    final fg = onAccent ? Colors.white : AppColors.accentDeep;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Day sheet — a MODAL bottom sheet, so it overlays the app's bottom nav. The
// user drags it down (or taps the dimmed area / grabber) to dismiss and get the
// nav back — the nav never sits on top of the sheet.
// ---------------------------------------------------------------------------
Future<void> showDaySheet(
  BuildContext context, {
  required DateTime day,
  required List<Occurrence> items,
  required ValueChanged<Task> onTapItem,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (sheetContext) => _DaySheetContent(
      day: day,
      items: items,
      onTapItem: (t) {
        // Close the sheet first, then open the item's editor.
        Navigator.of(sheetContext).pop();
        onTapItem(t);
      },
    ),
  );
}

/// A content-sized day sheet: it's exactly as tall as its rows (short for a
/// couple of items, taller for many), capped at ~72% of the screen where the
/// list scrolls. No fixed half-height, so there's never dead space at the bottom.
class _DaySheetContent extends StatelessWidget {
  const _DaySheetContent({
    required this.day,
    required this.items,
    required this.onTapItem,
  });

  final DateTime day;
  final List<Occurrence> items;
  final ValueChanged<Task> onTapItem;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final total = totalOf(items);
    final maxHeight = MediaQuery.of(context).size.height * 0.72;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grabber.
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            width: double.infinity,
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
                if (!total.isZero) ...[
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
          // The rows — shrink-wrapped so the sheet is only as tall as needed,
          // and scrollable once they exceed the max height.
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _DayItemRow(
                occ: items[i],
                onTap: () => onTapItem(items[i].task),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Year picker — a modal grid of years so you can jump years quickly.
// ---------------------------------------------------------------------------
/// A combined MONTH + YEAR picker. Returns the chosen `DateTime` (first of the
/// month), or null if dismissed. Year steps with ‹ ›; months are a tappable grid.
Future<DateTime?> showMonthYearPicker(
  BuildContext context, {
  required DateTime current,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _MonthYearSheet(current: current),
  );
}

class _MonthYearSheet extends StatefulWidget {
  const _MonthYearSheet({required this.current});
  final DateTime current;

  @override
  State<_MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<_MonthYearSheet> {
  late int _year = widget.current.year;

  static const _short = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 14, 4, 12),
              child: Text('Jump to month',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            // Year stepper.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  _ArrowBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => setState(() => _year--),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('$_year',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                    ),
                  ),
                  _ArrowBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => setState(() => _year++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Month grid.
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                for (var m = 1; m <= 12; m++)
                  _MonthTile(
                    label: _short[m - 1],
                    isSelected:
                        _year == widget.current.year && m == widget.current.month,
                    isThisMonth: _year == now.year && m == now.month,
                    onTap: () => Navigator.of(context).pop(DateTime(_year, m)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.label,
    required this.isSelected,
    required this.isThisMonth,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isThisMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.accent : AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isThisMonth && !isSelected
                  ? AppColors.accent
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
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
