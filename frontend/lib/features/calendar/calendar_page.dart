import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../brand/data/brand_catalog.dart';
import '../brand/domain/brand.dart';
import '../brand/presentation/brand_logo.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import 'domain/occurrences.dart';

/// The Calendar — a real month grid. Every task's due date (and each future
/// occurrence of a recurring task) is placed on its day, shown with the task's
/// brand logo. Tap a day to see everything due that day; tap a task to edit it.
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

  void _shiftMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  Future<void> _edit(Task task) async {
    final updated = await showTaskDetailsSheet(context, task);
    if (updated != null) widget.store.update(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          // Expand occurrences across the visible month (plus a little padding
          // so trailing/leading days of adjacent months are covered).
          final first = DateTime(_month.year, _month.month, 1);
          final last = DateTime(_month.year, _month.month + 1, 0);
          final occ = expandOccurrences(
            widget.store.tasks,
            from: first.subtract(const Duration(days: 7)),
            to: last.add(const Duration(days: 7)),
          );
          final byDay = groupByDay(occ);
          final selectedItems =
              _selected == null ? const <Occurrence>[] : (byDay[_selected!] ?? const []);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              _MonthHeader(
                month: _month,
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              const SizedBox(height: 12),
              _MonthGrid(
                month: _month,
                selected: _selected,
                byDay: byDay,
                onSelectDay: (d) => setState(() => _selected = d),
              ),
              const SizedBox(height: 16),
              _DayAgenda(
                day: _selected,
                items: selectedItems,
                onTapTask: _edit,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${_names[month.month - 1]} ${month.year}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
        ),
        const Spacer(),
        _RoundBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
        const SizedBox(width: 8),
        _RoundBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
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
          child: Icon(icon, color: AppColors.ink),
        ),
      ),
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

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: const TextStyle(
                            color: AppColors.inkFaint,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.72,
            children: cells,
          ),
        ],
      ),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.accent, width: 1.4)
              : null,
        ),
        child: Column(
          children: [
            const SizedBox(height: 4),
            // The date number — a filled dot for today.
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isToday ? AppColors.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? Colors.white : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Up to two logos, with a "+N" when there are more.
            Expanded(child: _DayLogos(items: items)),
          ],
        ),
      ),
    );
  }
}

/// The little stack of logos under a date number.
class _DayLogos extends StatelessWidget {
  const _DayLogos({required this.items});
  final List<Occurrence> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(2).toList();
    final extra = items.length - shown.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final o in shown)
            BrandLogo(brand: _brandOf(o.task), size: 16, radius: 5),
          if (extra > 0)
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('+$extra',
                  style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day agenda (below the grid)
// ---------------------------------------------------------------------------
class _DayAgenda extends StatelessWidget {
  const _DayAgenda({
    required this.day,
    required this.items,
    required this.onTapTask,
  });

  final DateTime? day;
  final List<Occurrence> items;
  final ValueChanged<Task> onTapTask;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final d = day!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${d.day} ${_months[d.month - 1]} ${d.year}',
              style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    size: 18, color: AppColors.inkFaint),
                const SizedBox(width: 8),
                Text('Nothing due this day',
                    style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              ],
            )
          else
            for (final o in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AgendaRow(occ: o, onTap: () => onTapTask(o.task)),
              ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.occ, required this.onTap});
  final Occurrence occ;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = occ.task;
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              BrandLogo(brand: _brandOf(t), size: 36, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontSize: 15)),
                    if (t.repeat != RepeatCadence.none)
                      Text(t.repeat.label,
                          style: const TextStyle(
                              color: AppColors.inkFaint, fontSize: 12)),
                  ],
                ),
              ),
              if (t.dueAt != null)
                Text(_time(t.dueAt!),
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? "AM" : "PM"}';
  }
}

/// Build a Brand for a task's logo. If the task has a domain, use it directly;
/// otherwise re-resolve the name (which also checks the curated/custom logos),
/// so bucket logos and aliases show correctly on the calendar too.
Brand _brandOf(Task t) {
  final name = (t.iconName?.isNotEmpty ?? false) ? t.iconName! : t.title;
  final domain = t.iconDomain ?? '';
  if (domain.isNotEmpty) return Brand(name: name, domain: domain);
  return BrandCatalog.resolve(name);
}
