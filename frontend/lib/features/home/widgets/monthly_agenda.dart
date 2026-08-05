import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../../core/theme/app_theme.dart';
import '../../calendar/domain/occurrences.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/widgets/task_tile.dart';

/// The Home agenda, grouped **by month → by date**.
///
/// A pinned month jump-bar rides at the very top (Jun · Jul · Aug …). Tapping a
/// month scrolls straight to that section. Each month header sticks while you
/// scroll through its days, and within a month every day is its own labelled
/// sub-group. Unscheduled tasks (no date yet) collect in a final "No date yet"
/// section so nothing is lost.
///
/// It's a pure view: it takes already-expanded [MonthSection]s (recurring tasks
/// already fanned out into one occurrence per month) plus the leftover
/// [unscheduled] tasks, and calls back for tile interactions.
class MonthlyAgenda extends StatefulWidget {
  const MonthlyAgenda({
    super.key,
    required this.months,
    required this.unscheduled,
    required this.onToggle,
    required this.onOpenDetails,
    required this.onDelete,
    this.leading,
  });

  final List<MonthSection> months;
  final List<Task> unscheduled;

  final void Function(Task) onToggle;
  final void Function(Task) onOpenDetails;
  final void Function(Task) onDelete;

  /// Optional widget shown above the first month (e.g. the quick-add row).
  final Widget? leading;

  @override
  State<MonthlyAgenda> createState() => _MonthlyAgendaState();
}

class _MonthlyAgendaState extends State<MonthlyAgenda> {
  final _scrollController = ScrollController();

  // Each month section gets a GlobalKey so the jump-bar can scroll it into view.
  final _sectionKeys = <DateTime, GlobalKey>{};

  // Which month is currently "active" in the jump-bar (nearest the top).
  DateTime? _activeMonth;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.months.isNotEmpty) _activeMonth = widget.months.first.month;
  }

  @override
  void didUpdateWidget(MonthlyAgenda old) {
    super.didUpdateWidget(old);
    // Keep the active month valid if the data changed underneath us.
    final stillThere =
        widget.months.any((m) => m.month == _activeMonth);
    if (!stillThere && widget.months.isNotEmpty) {
      _activeMonth = widget.months.first.month;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Track which month header is nearest the top of the viewport and light up
  /// its chip. Cheap: reads each section's render box offset.
  void _onScroll() {
    if (!mounted || widget.months.isEmpty) return;
    DateTime? best;
    double bestDist = double.infinity;
    // Consider a header "reached" once its top passes ~120px from the top
    // (below the pinned jump-bar).
    const anchor = 130.0;
    for (final m in widget.months) {
      final key = _sectionKeys[m.month];
      final ctx = key?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      final dist = (dy - anchor).abs();
      // Prefer the last header at/above the anchor; fall back to nearest.
      if (dy <= anchor + 8 && dist < bestDist) {
        bestDist = dist;
        best = m.month;
      }
    }
    best ??= widget.months.first.month;
    if (best != _activeMonth) setState(() => _activeMonth = best);
  }

  Future<void> _jumpTo(DateTime month) async {
    setState(() => _activeMonth = month);
    final ctx = _sectionKeys[month]?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.0, // bring the header to the top
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fresh keys map each build so removed months don't leak keys.
    _sectionKeys
      ..clear()
      ..addEntries(widget.months.map((m) => MapEntry(m.month, GlobalKey())));

    return Column(
      children: [
        if (widget.months.length > 1)
          _MonthJumpBar(
            months: widget.months,
            active: _activeMonth,
            onTap: _jumpTo,
          ),
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (widget.leading != null)
                SliverToBoxAdapter(child: widget.leading),

              for (final month in widget.months)
                ..._monthSlivers(month),

              if (widget.unscheduled.isNotEmpty) ..._unscheduledSlivers(),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _monthSlivers(MonthSection month) {
    return [
      SliverStickyHeader(
        // KeyedSubtree carries the section key on the header so scroll-to works.
        header: KeyedSubtree(
          key: _sectionKeys[month.month],
          child: _MonthHeader(month: month.month, count: month.total),
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final day = month.days[i];
              return _DayGroup(
                date: day.date,
                child: Column(
                  children: [
                    for (final occ in day.occurrences)
                      TaskTile(
                        // A recurring task shows in many months; key by task+date
                        // so each occurrence animates independently.
                        key: ValueKey('${occ.task.id}@${occ.date.toIso8601String()}'),
                        task: occ.task,
                        occurrenceDate: occ.date,
                        onToggle: () => widget.onToggle(occ.task),
                        onOpenDetails: () => widget.onOpenDetails(occ.task),
                        onDelete: () => widget.onDelete(occ.task),
                      ),
                  ],
                ),
              );
            },
            childCount: month.days.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _unscheduledSlivers() {
    return [
      SliverStickyHeader(
        header: const _MonthHeader.custom(label: 'No date yet'),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final t = widget.unscheduled[i];
              return TaskTile(
                key: ValueKey('unscheduled-${t.id}'),
                task: t,
                onToggle: () => widget.onToggle(t),
                onOpenDetails: () => widget.onOpenDetails(t),
                onDelete: () => widget.onDelete(t),
              );
            },
            childCount: widget.unscheduled.length,
          ),
        ),
      ),
    ];
  }
}

/// The horizontal, pinned month jump-bar. Each chip shows a month; the active
/// one is filled. Tapping scrolls to that section.
class _MonthJumpBar extends StatelessWidget {
  const _MonthJumpBar({
    required this.months,
    required this.active,
    required this.onTap,
  });

  final List<MonthSection> months;
  final DateTime? active;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = months[i];
          final isActive = m.month == active;
          final thisYear = DateTime.now().year;
          final label = m.month.year == thisYear
              ? _monthShort[m.month.month - 1]
              : '${_monthShort[m.month.month - 1]} ’${m.month.year % 100}';
          return _MonthChip(
            label: label,
            count: m.total,
            active: isActive,
            onTap: () => onTap(m.month),
          );
        },
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.inkSoft,
              ),
            ),
            const SizedBox(width: 6),
            // A small count pill.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.bgTop,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticky month header — big month name + year, with a running count.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.count})
      : label = null;
  const _MonthHeader.custom({required this.label})
      : month = null,
        count = 0;

  final DateTime? month;
  final int count;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    final title = label ??
        (month!.year == thisYear
            ? _monthFull[month!.month - 1]
            : '${_monthFull[month!.month - 1]} ${month!.year}');
    return Container(
      // Opaque so list rows don't show through the pinned header.
      color: AppColors.bg,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          if (label == null) ...[
            const SizedBox(width: 10),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled day sub-group ("Fri · 12") above its tasks, with a faint rule.
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.date, required this.child});

  final DateTime date;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    final isToday = diff == 0;
    final isPast = date.isBefore(today);

    String rel;
    if (isToday) {
      rel = 'Today';
    } else if (diff == 1) {
      rel = 'Tomorrow';
    } else if (diff == -1) {
      rel = 'Yesterday';
    } else {
      rel = _weekdayShort[date.weekday - 1];
    }

    final accent = isToday
        ? AppColors.accent
        : (isPast ? const Color(0xFFE5484D) : AppColors.inkSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
          child: Row(
            children: [
              // Big day number.
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(height: 1, color: AppColors.hairline),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
