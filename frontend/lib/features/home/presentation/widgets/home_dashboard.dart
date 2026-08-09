import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../details/domain/currency.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/home_stats.dart';
import 'revo_hero.dart' show RevoMood, revoMoodFor;

// ── Category visuals ─────────────────────────────────────────────────────────

IconData _catIcon(TaskCategory c) => switch (c) {
      TaskCategory.subscription => Icons.subscriptions_rounded,
      TaskCategory.birthday => Icons.cake_rounded,
      TaskCategory.insurance => Icons.shield_rounded,
      TaskCategory.other => Icons.push_pin_rounded,
    };

Color _catColor(TaskCategory c) => switch (c) {
      TaskCategory.subscription => AppColors.accent,
      TaskCategory.birthday => const Color(0xFFFF6FB5),
      TaskCategory.insurance => const Color(0xFF34D399),
      TaskCategory.other => const Color(0xFFA5B4FC),
    };

// ── 1 · Greeting with Revo ───────────────────────────────────────────────────

/// Revo, animated, saying "Good afternoon, [name]" with "Welcome to Revolution"
/// under it. He lives HERE (not inside the hero), tail pointing right toward the
/// words, his expression quietly reflecting the day's mood.
class GreetingRevo extends StatefulWidget {
  const GreetingRevo({super.key, required this.name, required this.tasks});

  final String name; // may be empty
  final List<Task> tasks;

  @override
  State<GreetingRevo> createState() => _GreetingRevoState();
}

class _GreetingRevoState extends State<GreetingRevo>
    with TickerProviderStateMixin { // two controllers → plural mixin
  late final AnimationController _in; // one-shot entrance
  late final AnimationController _idle; // perpetual life

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 720));
    // Slow, calm idle — a gentle breathing bob, not a jittery wobble. 5.6s per
    // loop reads as relaxed (matches the app's other mascots ~5.2s).
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 5600))
      ..repeat();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => mounted ? _in.forward() : null);
  }

  @override
  void dispose() {
    _in.dispose();
    _idle.dispose();
    super.dispose();
  }

  String get _timeGreeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final first =
        widget.name.trim().isEmpty ? null : widget.name.trim().split(' ').first;
    final mood = revoMoodFor(widget.tasks);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Revo — animated entrance + perpetual idle, expression from mood.
          SizedBox(
            width: 60,
            height: 60,
            child: AnimatedBuilder(
              animation: Listenable.merge([_in, _idle]),
              builder: (context, _) {
                final pop = Curves.easeOutBack.transform(_in.value);
                return Opacity(
                  opacity: Curves.easeOut.transform(_in.value.clamp(0, 1)),
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * pop,
                    child: _GreetMascot(t: _idle.value, mood: mood, size: 60),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  first == null ? _timeGreeting : '$_timeGreeting, $first',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome to Revolution',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent.withValues(alpha: 0.95),
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

/// A compact mascot for the greeting — tail pointing RIGHT toward the text,
/// gentle idle life, expression nudged by the day's [mood] (never a face swap:
/// a calm bob when happy, a low drift when sad, a light jitter when panicking).
class _GreetMascot extends StatelessWidget {
  const _GreetMascot(
      {required this.t, required this.mood, required this.size});
  final double t;
  final RevoMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final phase = t * 2 * math.pi;
    double blink() {
      final d = (t - 0.5).abs();
      return d > 0.02 ? 0 : 1 - d / 0.02;
    }

    switch (mood) {
      case RevoMood.happy:
        final breath = math.sin(phase);
        return Transform.translate(
          offset: Offset(0, breath * 1.6),
          child: Mascot(
            size: size,
            blink: blink(),
            look: Offset(0.30 + math.sin(phase + 1) * 0.14,
                math.cos(phase * 2) * 0.1),
            squash: breath * 0.04,
            tilt: math.sin(phase + 2) * 0.03,
            glow: true,
          ),
        );
      case RevoMood.sad:
        final drift = math.sin(phase * 0.6);
        return Transform.translate(
          offset: Offset(0, 3 + drift),
          child: Mascot(
            size: size * 0.95,
            blink: blink(),
            look: Offset(0.1 + drift * 0.08, 0.5),
            tilt: -0.1,
            glow: false,
          ),
        );
      case RevoMood.panicking:
        // A GENTLE alert bob for the greeting — attentive, not frantic. (The
        // urgency read lives in the hero's numbers, not a shaking mascot.)
        final phase = t * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, math.sin(phase * 2) * 2.2),
          child: Mascot(
            size: size,
            look: Offset(0.15 + math.sin(phase) * 0.18, -0.1),
            squash: math.sin(phase * 2) * 0.05,
            tilt: math.sin(phase) * 0.05,
            glow: true,
          ),
        );
    }
  }
}

// ── 2 · THE hero card (Suball-style) ─────────────────────────────────────────

/// The single hero — everything the user opens the app to see, in one rich card
/// (styled after the Suball reference): a header row, the big "This month" spend
/// figure with a MoM hint, a three-up sub-stat row (Due today · This month ·
/// Overdue), and a compact 6-month spend sparkline-bar chart.
class HeroMetricsCard extends StatelessWidget {
  const HeroMetricsCard({super.key, required this.stats});

  final HomeStats stats;

  String _money(double v, String sym) {
    if (v >= 100000) return '$sym${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) {
      final k = v / 1000;
      return '$sym${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)}k';
    }
    return '$sym${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final sym = currencyOf(stats.currency).symbol;
    final hasSpend = stats.monthSpend > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF251B47), Color(0xFF181025)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 34, offset: Offset(0, 16)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row.
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 7),
              Text(hasSpend ? 'Due this month' : 'Your reminders',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.1)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (stats.dueToday > 0
                          ? const Color(0xFFFFC66B)
                          : const Color(0xFF5FE3B3))
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stats.dueToday > 0 ? '${stats.dueToday} today' : 'On track',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: stats.dueToday > 0
                        ? const Color(0xFFFFC66B)
                        : const Color(0xFF5FE3B3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The big figure — spend if there is any, else the count of items due.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasSpend
                    ? _money(stats.monthSpend, sym)
                    : '${stats.dueThisMonth}',
                style: const TextStyle(
                    fontSize: 46,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                    color: AppColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  hasSpend ? 'this month' : 'due this month',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Three-up sub-stats, like Suball's Daily Avg / Paid / Pending.
          Row(
            children: [
              _SubStat(
                  value: '${stats.dueToday}',
                  label: 'Due today',
                  tint: stats.dueToday > 0
                      ? const Color(0xFFFFC66B)
                      : AppColors.inkSoft),
              _SubDivider(),
              _SubStat(
                  value: '${stats.dueThisMonth}',
                  label: 'This month',
                  tint: const Color(0xFFA5B4FC)),
              _SubDivider(),
              _SubStat(
                  value: '${stats.overdue}',
                  label: 'Overdue',
                  tint: stats.overdue > 0
                      ? const Color(0xFFFF7D93)
                      : AppColors.inkSoft),
            ],
          ),
          const SizedBox(height: 16),
          // Compact activity bar chart (reminders-due per month, last 6).
          _MiniBars(
            values: _monthlyCounts(stats),
            accent: AppColors.accent,
          ),
        ],
      ),
    );
  }

  /// Placeholder distribution for the mini chart — until we track history, show
  /// a gentle shape derived from the current counts so it reads as "activity".
  List<double> _monthlyCounts(HomeStats s) {
    final base = (s.total).clamp(1, 30).toDouble();
    return [
      base * 0.4,
      base * 0.6,
      base * 0.5,
      base * 0.8,
      base * 0.7,
      base.toDouble(),
    ];
  }
}

class _SubStat extends StatelessWidget {
  const _SubStat({required this.value, required this.label, required this.tint});
  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: tint,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkFaint)),
        ],
      ),
    );
  }
}

class _SubDivider extends StatelessWidget {
  const _SubDivider();
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 34, color: AppColors.glassBorder);
}

/// A tiny bar chart — soft violet bars, the last one emphasised. Purely visual.
class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values, required this.accent});
  final List<double> values;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(1, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: FractionallySizedBox(
                heightFactor: (values[i] / maxV).clamp(0.12, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: i == values.length - 1
                        ? accent
                        : accent.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
            if (i < values.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

// ── 3 · "Up Next" cards ──────────────────────────────────────────────────────

/// A horizontally-scrolling strip of the soonest reminders as cards (image 2).
class UpNextStrip extends StatelessWidget {
  const UpNextStrip({super.key, required this.items, required this.onTap});

  final List<Task> items;
  final void Function(Task) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: Text('Up next',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.ink)),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                _UpNextCard(task: shown[i], onTap: () => onTap(shown[i])),
          ),
        ),
      ],
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.task, required this.onTap});
  final Task task;
  final VoidCallback onTap;

  String _whenLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueAt!.year, task.dueAt!.month, task.dueAt!.day);
    final days = due.difference(today).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days < 7) return 'in $days days';
    if (days < 30) return 'in ${(days / 7).round()} wk';
    return 'in ${(days / 30).round()} mo';
  }

  @override
  Widget build(BuildContext context) {
    final cat = task.category;
    final tint = _catColor(cat);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueAt!.year, task.dueAt!.month, task.dueAt!.day);
    final urgent = !due.isAfter(today.add(const Duration(days: 1)));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 172,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tint.withValues(alpha: 0.16), AppColors.card],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: urgent
                  ? tint.withValues(alpha: 0.5)
                  : AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CardAvatar(task: task, tint: tint, size: 40),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgent
                        ? tint.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_whenLabel(),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: urgent ? tint : AppColors.inkSoft)),
                ),
              ],
            ),
            const Spacer(),
            Text(task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 2),
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
    );
  }
}

/// The item's avatar — brand logo when it has one, else a category-tinted icon.
class _CardAvatar extends StatelessWidget {
  const _CardAvatar({required this.task, required this.tint, this.size = 40});
  final Task task;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (task.hasIcon) {
      return BrandLogo(
        brand: Brand(
            name: task.iconName ?? task.title, domain: task.iconDomain ?? ''),
        size: size,
        radius: 11,
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(_catIcon(task.category), size: size * 0.5, color: tint),
    );
  }
}

// ── 4 · Category cards ───────────────────────────────────────────────────────

/// One rich card per category (image 3 vibe): big count, icon, and the next
/// item in that category as a preview line. Tapping filters/opens the category.
class CategoryCards extends StatelessWidget {
  const CategoryCards({
    super.key,
    required this.stats,
    required this.tasks,
    required this.onTapCategory,
  });

  final HomeStats stats;
  final List<Task> tasks;
  final void Function(TaskCategory) onTapCategory;

  // Display order.
  static const _order = [
    TaskCategory.subscription,
    TaskCategory.insurance,
    TaskCategory.birthday,
    TaskCategory.other,
  ];

  @override
  Widget build(BuildContext context) {
    final cats = _order.where((c) => (stats.byCategory[c] ?? 0) > 0).toList();
    if (cats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Text('Your reminders',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.ink)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.28,
            children: [
              for (final c in cats)
                _CategoryCard(
                  category: c,
                  count: stats.byCategory[c] ?? 0,
                  next: _nextIn(c),
                  onTap: () => onTapCategory(c),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Task? _nextIn(TaskCategory c) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = tasks
        .where((t) =>
            t.category == c &&
            t.isScheduled &&
            !t.done &&
            !DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day)
                .isBefore(today))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return list.isEmpty ? null : list.first;
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.next,
    required this.onTap,
  });
  final TaskCategory category;
  final int count;
  final Task? next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _catColor(category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tint.withValues(alpha: 0.18), AppColors.card],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_catIcon(category), size: 21, color: tint),
                ),
                const Spacer(),
                Text('$count',
                    style: TextStyle(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: tint,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            const Spacer(),
            Text(category.label,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(
              next == null
                  ? '$count ${count == 1 ? category.singular : category.label.toLowerCase()}'
                  : 'Next: ${next!.title}',
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
    );
  }
}

// ── Welcoming empty state (Revo greets a new user) ───────────────────────────

/// The Home when there's nothing yet — NOT a bare checkmark. A large, gently
/// floating Revo greets the user by name ("Good afternoon, [name]" / "Welcome
/// to Revolution") with a soft entrance, above one calm "Add your first
/// reminder" button. New users meet the character, not a blank screen.
class WelcomeEmpty extends StatefulWidget {
  const WelcomeEmpty({super.key, required this.name, required this.onAdd});

  final String name; // may be empty
  final VoidCallback onAdd;

  @override
  State<WelcomeEmpty> createState() => _WelcomeEmptyState();
}

class _WelcomeEmptyState extends State<WelcomeEmpty>
    with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 820));
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4200))
      ..repeat();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => mounted ? _in.forward() : null);
  }

  @override
  void dispose() {
    _in.dispose();
    _idle.dispose();
    super.dispose();
  }

  String get _timeGreeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final first =
        widget.name.trim().isEmpty ? null : widget.name.trim().split(' ').first;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Revo — big, floating, tail-left, with a soft scale-in entrance.
            SizedBox(
              width: 132,
              height: 132,
              child: AnimatedBuilder(
                animation: Listenable.merge([_in, _idle]),
                builder: (context, _) {
                  final pop = Curves.easeOutBack.transform(_in.value);
                  final phase = _idle.value * 2 * math.pi;
                  final breath = math.sin(phase);
                  return Opacity(
                    opacity: Curves.easeOut.transform(_in.value.clamp(0, 1)),
                    child: Transform.translate(
                      offset: Offset(0, breath * 4),
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * pop,
                        child: Mascot(
                          size: 132,
                          look: Offset(
                              -0.3 + math.sin(phase + 1) * 0.2, breath * 0.1),
                          squash: breath * 0.04,
                          tilt: math.sin(phase + 2) * 0.03,
                          glow: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            Text(
              first == null ? '$_timeGreeting!' : '$_timeGreeting, $first!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Welcome to Revolution — I’ll remember\nthe things you shouldn’t have to.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 26),
            // One calm primary action.
            GestureDetector(
              onTap: widget.onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDeep],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 18,
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
                      'Add your first reminder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
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
