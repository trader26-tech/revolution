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

  void _jumpToYear(int year) => setState(() {
        _month = DateTime(year, _month.month);
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

  Future<void> _pickYear() async {
    final year = await showYearPicker(context, current: _month.year);
    if (year != null) _jumpToYear(year);
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
              _SpendHeader(
                month: _month,
                total: monthTotal(monthOcc),
                upcoming: upcomingTotal(monthOcc),
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
                onTapYear: _pickYear,
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
    required this.onTapYear,
  });

  final DateTime month;
  final MoneyTotal total;
  final MoneyTotal upcoming;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapYear;

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
            // Month name + a tappable year chip. Tapping the year opens a picker
            // so you can jump years quickly.
            Flexible(
              child: Text(
                _names[month.month - 1],
                overflow: TextOverflow.ellipsis,
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _YearChip(year: month.year, onTap: onTapYear),
            const Spacer(),
            _RoundBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
            const SizedBox(width: 8),
            _RoundBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
        // Total + Upcoming — only when there's actually spend. With no data we
        // show nothing here (no "₹0.00 Total"), keeping the header clean.
        if (!total.isZero) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _Figure(value: total.formatted, label: 'Total'),
              if (!upcoming.isZero) ...[
                const SizedBox(width: 20),
                _Figure(value: upcoming.formatted, label: 'Upcoming'),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.ink,
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

/// The tappable year beside the month name — opens the year picker.
class _YearChip extends StatelessWidget {
  const _YearChip({required this.year, required this.onTap});
  final int year;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$year',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
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
      childAspectRatio: 0.62, // slightly taller cells → room for logo + "+N"
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
        padding: const EdgeInsets.fromLTRB(3, 6, 3, 5),
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
            const SizedBox(height: 4),
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

    final hasMore = items.length > 1;

    // One prominent logo + a "+N" label when there are more (e.g. the Spotify
    // logo with "+20" beneath on a busy day). We size everything from the height
    // the cell actually gives us, so the logo + "+N" always fit — never overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for the "+N" line when present, then size the logo to the
        // remaining height (clamped so it stays tidy on tall/short cells).
        const labelHeight = 13.0;
        const gap = 2.0;
        final avail = constraints.maxHeight;
        final forLogo = hasMore ? (avail - labelHeight - gap) : avail;
        final logoSize = forLogo.clamp(0.0, 26.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoSize > 6)
              BrandLogo(
                brand: _brandOf(items.first.task),
                size: logoSize,
                radius: logoSize * 0.3,
              ),
            if (hasMore) ...[
              const SizedBox(height: gap),
              SizedBox(
                height: labelHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+${items.length - 1}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
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
    builder: (_) => _DaySheetContent(
      day: day,
      items: items,
      onTapItem: (t) {
        // Close the sheet first, then open the item's editor.
        Navigator.of(context).pop();
        onTapItem(t);
      },
    ),
  );
}

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

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.5],
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Year picker — a modal grid of years so you can jump years quickly.
// ---------------------------------------------------------------------------
Future<int?> showYearPicker(BuildContext context, {required int current}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _YearPickerSheet(current: current),
  );
}

class _YearPickerSheet extends StatelessWidget {
  const _YearPickerSheet({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    // A generous, sensible span: a few years back through several ahead, so
    // subscriptions renewing years out are reachable.
    final start = now - 5;
    final years = List.generate(16, (i) => start + i);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Jump to year',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                for (final y in years)
                  _YearTile(
                    year: y,
                    isCurrent: y == current,
                    isThisYear: y == now,
                    onTap: () => Navigator.of(context).pop(y),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YearTile extends StatelessWidget {
  const _YearTile({
    required this.year,
    required this.isCurrent,
    required this.isThisYear,
    required this.onTap,
  });

  final int year;
  final bool isCurrent;
  final bool isThisYear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCurrent ? AppColors.accent : AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isThisYear && !isCurrent
                  ? AppColors.accent
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Text(
            '$year',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isCurrent ? Colors.white : AppColors.ink,
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
