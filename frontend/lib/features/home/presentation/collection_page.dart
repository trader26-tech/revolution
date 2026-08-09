import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../add/presentation/open_add_flow.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../../details/domain/currency.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_details_sheet.dart';

/// The task's NEXT occurrence on/after [from] (date-only). A recurring item
/// whose stored date is in the past is rolled forward by its cadence, so we
/// never show a "past" renewal — there's no completion, dates just recur.
DateTime nextOccurrence(Task t, {required DateTime from}) {
  var d = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
  if (!d.isBefore(from)) return d;
  switch (t.repeat) {
    case RepeatCadence.none:
      // A one-off in the past has no future occurrence; keep its date.
      return d;
    case RepeatCadence.daily:
      final days = from.difference(d).inDays;
      return d.add(Duration(days: days));
    case RepeatCadence.weekly:
      final weeks = (from.difference(d).inDays / 7).ceil();
      return d.add(Duration(days: weeks * 7));
    case RepeatCadence.monthly:
      while (d.isBefore(from)) {
        d = DateTime(d.year, d.month + 1, d.day);
      }
      return d;
    case RepeatCadence.yearly:
      while (d.isBefore(from)) {
        d = DateTime(d.year + 1, d.month, d.day);
      }
      return d;
  }
}

/// A full-screen "tab" for ONE product — e.g. all Subscriptions, all SIPs. Its
/// own header (category icon + name + count), a "+" that jumps straight into
/// that category's add form, and the items as glass rows. Pass [category] =
/// null for the "All" collection (every reminder).
///
/// Rebuilds live off the [store] so adds/edits/deletes reflect immediately.
class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key, required this.store, this.category});

  final TaskStore store;

  /// The category to show, or null for "All".
  final TaskCategory? category;

  String get _title => category?.label ?? 'All reminders';
  IconData get _icon => category?.icon ?? Icons.blur_on_rounded;
  // ONE constant accent everywhere — categories differ by icon, not colour.
  Color get _accent => AppColors.accent;

  List<Task> _items() {
    final list = category == null
        ? store.tasks.toList()
        : store.tasks.where((t) => t.category == category).toList();
    // Scheduled first (soonest), then unscheduled — a stable, scannable order.
    list.sort((a, b) {
      if (a.isScheduled && b.isScheduled) return a.dueAt!.compareTo(b.dueAt!);
      if (a.isScheduled) return -1;
      if (b.isScheduled) return 1;
      return 0;
    });
    return list;
  }

  /// Group the items into time windows so the page reads as a clear overview of
  /// what's coming and when: This week · This month · Later · No date. Past
  /// dates are rolled forward to their next occurrence (nothing is "overdue" —
  /// we never mark items complete, so a past date just means it recurred).
  List<_Section> _grouped(List<Task> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));
    final monthEnd = today.add(const Duration(days: 30));

    final week = <Task>[];
    final month = <Task>[];
    final later = <Task>[];
    final undated = <Task>[];

    for (final t in items) {
      if (!t.isScheduled) {
        undated.add(t);
        continue;
      }
      final d = nextOccurrence(t, from: today);
      if (d.isBefore(weekEnd)) {
        week.add(t);
      } else if (d.isBefore(monthEnd)) {
        month.add(t);
      } else {
        later.add(t);
      }
    }

    // Sort each bucket by its (rolled-forward) next occurrence.
    int byNext(Task a, Task b) =>
        nextOccurrence(a, from: today).compareTo(nextOccurrence(b, from: today));
    week.sort(byNext);
    month.sort(byNext);
    later.sort(byNext);

    return [
      if (week.isNotEmpty) _Section('This week', week),
      if (month.isNotEmpty) _Section('This month', month),
      if (later.isNotEmpty) _Section('Later', later),
      if (undated.isNotEmpty) _Section('No date yet', undated),
    ];
  }

  /// Everything the hero shows, computed in one pass.
  _HeroStats _heroStats(List<Task> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    final spend = <String, double>{}; // currency → summed amount (as billed)
    var monthlyEq = 0.0; // ₹-equivalent normalised to /month (INR amounts only)
    var dueThisWeek = 0;
    DateTime? nextDate;

    for (final t in items) {
      if (t.hasAmount) {
        spend.update(t.currency, (v) => v + t.amount!, ifAbsent: () => t.amount!);
        // Monthly-equivalent only mixes same-currency (INR) amounts to stay
        // meaningful; other currencies are shown separately in `spend`.
        if (t.currency == 'INR') monthlyEq += _toMonthly(t.amount!, t.repeat);
      }
      if (t.isScheduled) {
        final d = nextOccurrence(t, from: today); // rolled forward, never past
        if (d.isBefore(weekEnd)) dueThisWeek++;
        if (nextDate == null || d.isBefore(nextDate)) nextDate = d;
      }
    }

    return _HeroStats(
      total: items.length,
      spend: spend,
      monthlyEqInr: monthlyEq,
      dueThisWeek: dueThisWeek,
      nextDate: nextDate,
    );
  }

  static double _toMonthly(double amount, RepeatCadence r) => switch (r) {
        RepeatCadence.daily => amount * 30,
        RepeatCadence.weekly => amount * 52 / 12,
        RepeatCadence.monthly => amount,
        RepeatCadence.yearly => amount / 12,
        RepeatCadence.none => amount, // treat a one-off as its face value
      };

  Future<void> _add(BuildContext context) async {
    final result = await openCategoryForm(
      context,
      store,
      category ?? TaskCategory.other,
    );
    await persistAddResult(store, result);
  }

  Future<void> _edit(BuildContext context, Task task) async {
    final updated = await showTaskDetailsSheet(context, task);
    if (updated != null) store.update(updated);
  }

  @override
  Widget build(BuildContext context) {
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
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final items = _items();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Slim nav bar: just back · add. The title lives BIG in the
                  // hero below, so no redundant title text here.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 16, 6),
                    child: Row(
                      children: [
                        GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        GlassIconButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Add',
                          accent: true,
                          onTap: () => _add(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? _EmptyCollection(
                            icon: _icon,
                            accent: _accent,
                            title: _title,
                            onAdd: () => _add(context),
                          )
                        : _GroupedList(
                            sections: _grouped(items),
                            hero: _heroStats(items),
                            icon: _icon,
                            title: _title,
                            onTap: (t) => _edit(context, t),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

}

/// A time-window section: a label and the items that fall in it.
class _Section {
  const _Section(this.label, this.items);
  final String label;
  final List<Task> items;
}

/// The grouped list — the orbit hero card up top, then time-window sections,
/// each with a header and its rows. Reads as a clean "what's coming, and when".
class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.sections,
    required this.hero,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final List<_Section> sections;
  final _HeroStats hero;
  final IconData icon;
  final String title;
  final void Function(Task) onTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _CategoryHero(stats: hero, icon: icon, title: title),
    ];
    for (final s in sections) {
      children.add(_SectionHeader(label: s.label, count: s.items.length));
      for (final t in s.items) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CollectionRow(
            task: t,
            accent: AppColors.accent,
            onTap: () => onTap(t),
          ),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
      children: children,
    );
  }
}

/// Everything the hero shows.
class _HeroStats {
  const _HeroStats({
    required this.total,
    required this.spend,
    required this.monthlyEqInr,
    required this.dueThisWeek,
    required this.nextDate,
  });
  final int total;
  final Map<String, double> spend; // currency → total (as billed)
  final double monthlyEqInr; // INR items normalised to /month
  final int dueThisWeek;
  final DateTime? nextDate; // next occurrence across all items (rolled forward)
}

/// The orbit-themed hero — an at-a-glance overview of everything about this
/// category: the big category name, the headline monthly spend (with a little
/// orbiting planet), and a three-up sub-stat row.
class _CategoryHero extends StatelessWidget {
  const _CategoryHero({
    required this.stats,
    required this.icon,
    required this.title,
  });

  final _HeroStats stats;
  final IconData icon;
  final String title;

  String _fmt(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

  /// The headline figure — INR monthly-equivalent if any INR items exist, else
  /// the first currency's raw total. Returns (symbol, value, caption).
  (String, String, String) _headline() {
    if (stats.monthlyEqInr > 0) {
      return ('₹', _fmt(stats.monthlyEqInr), 'per month');
    }
    if (stats.spend.isNotEmpty) {
      final e = stats.spend.entries.first;
      return (currencyOf(e.key).symbol, _fmt(e.value), 'total');
    }
    return ('', '—', 'no prices yet');
  }

  @override
  Widget build(BuildContext context) {
    final (sym, value, caption) = _headline();
    // Other-currency chips (anything beyond the INR headline).
    final others = stats.spend.entries
        .where((e) => !(e.key == 'INR' && stats.monthlyEqInr > 0))
        .map((e) => '${currencyOf(e.key).symbol}${_fmt(e.value)}')
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241A44), Color(0xFF1A1330)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: the BIG category name (this card's identity) + the
          // orbiting planet motif.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stats.total == 1
                          ? '1 tracked'
                          : '${stats.total} tracked',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.accent.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _OrbitBadge(icon: icon),
            ],
          ),
          const SizedBox(height: 18),

          // Headline spend figure.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                sym,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 2),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [AppColors.ink, Color(0xFFB9A8FF)],
                ).createShader(r),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '+ ${others.join('  ·  ')} in other currencies',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.inkFaint,
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Three-up sub-stats.
          Row(
            children: [
              _HeroStat(
                value: '${stats.total}',
                label: 'active',
              ),
              _statDivider(),
              _HeroStat(
                value: '${stats.dueThisWeek}',
                label: 'due this week',
                highlight: stats.dueThisWeek > 0,
              ),
              _statDivider(),
              _HeroStat(
                value: stats.nextDate == null
                    ? '—'
                    : '${_days(stats.nextDate!)}d',
                label: 'to next',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 30,
        color: Colors.white.withValues(alpha: 0.08),
      );

  int _days(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(due.year, due.month, due.day);
    return d.difference(today).inDays;
  }
}

/// The little orbiting-planet emblem — a category icon with a ring + a moon,
/// echoing the app's orbit identity.
class _OrbitBadge extends StatelessWidget {
  const _OrbitBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orbit ring.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
          ),
          // The planet.
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [AppColors.accent, AppColors.accentDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          // A tiny moon on the ring.
          Positioned(
            top: 1,
            right: 6,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.ink.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    this.highlight = false,
  });
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: highlight ? AppColors.accent : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section label + a count pill.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 12),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkFaint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.hairline,
            ),
          ),
        ],
      ),
    );
  }
}

/// One item as a full-width glass row (photo/logo · title · sub · when).
class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.task,
    required this.accent,
    required this.onTap,
  });
  final Task task;
  final Color accent;
  final VoidCallback onTap;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final urgent = _daysAway() != null && _daysAway()! <= 3;
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
            _Avatar(task: task, tint: accent),
            const SizedBox(width: 14),
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
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _priceLine(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // The DATE, made explicit — the NEXT occurrence (rolled forward, so
            // never "overdue"): exact day on top, relative below.
            if (task.isScheduled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _dateLabel(_next()),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgent
                          ? accent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _relLabel(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: urgent ? accent : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'No date',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  DateTime _next() =>
      nextOccurrence(task, from: _today());

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _priceLine() {
    if (task.hasAmount) {
      final sym = currencyOf(task.currency).symbol;
      final amt = task.amount!.toStringAsFixed(
          task.amount == task.amount!.roundToDouble() ? 0 : 2);
      return '$sym$amt · ${task.repeat.label}';
    }
    return task.repeat.label == 'Never' ? 'One-time' : task.repeat.label;
  }

  String _dateLabel(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  int? _daysAway() {
    if (!task.isScheduled) return null;
    return _next().difference(_today()).inDays;
  }

  String _relLabel() {
    final days = _daysAway()!;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days < 7) return 'in $days days';
    if (days < 30) return 'in ${(days / 7).round()} wk';
    return 'in ${(days / 30).round()} mo';
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
      child: Icon(task.category.icon, size: 23, color: tint),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({
    required this.icon,
    required this.accent,
    required this.title,
    required this.onAdd,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: accent),
            ),
            const SizedBox(height: 18),
            Text(
              'No ${title.toLowerCase()} yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.75)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add one',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
