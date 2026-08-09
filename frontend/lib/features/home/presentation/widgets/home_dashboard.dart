import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../details/domain/currency.dart';
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/home_stats.dart';
import 'revo_hero.dart'
    show RevoMood, revoMoodFor, dueTodayCount, overdueCount;

// ── Category visuals ─────────────────────────────────────────────────────────
// Shared across the app — see category_visuals.dart.

IconData _catIcon(TaskCategory c) => c.icon;
Color _catColor(TaskCategory c) => c.color;

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

  /// A space-themed glyph for the time of day — sunrise/day/night, always tinted
  /// to the app accent (never a stock yellow emoji).
  IconData get _timeGlyph {
    final h = DateTime.now().hour;
    if (h < 12) return Icons.wb_twilight_rounded; // dawn
    if (h < 17) return Icons.wb_sunny_outlined; // day
    return Icons.nightlight_round; // night / space
  }

  /// A warm, mood-aware second line — welcoming, a little bit "mission control".
  String get _subline {
    final due = dueTodayCount(widget.tasks);
    final over = overdueCount(widget.tasks);
    if (over > 0) {
      return '$over overdue — let’s get you caught up.';
    }
    if (due > 0) {
      return due == 1
          ? '1 reminder needs you today.'
          : '$due reminders need you today.';
    }
    if (widget.tasks.isEmpty) {
      return 'Welcome aboard Revolution.';
    }
    return 'All clear — you’re on top of everything.';
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
                // A small themed eyebrow — a moon/day glyph tinted to the app,
                // never a stock yellow emoji — with the app wordmark.
                Row(
                  children: [
                    Icon(_timeGlyph, size: 13, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'REVOLUTION',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                        color: AppColors.accent.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // "Good evening, <name>" — big and warm, the name in a gradient.
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [AppColors.ink, Color(0xFFB9A8FF)],
                  ).createShader(r),
                  child: Text(
                    first == null ? _timeGreeting : '$_timeGreeting, $first',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: Colors.white, // masked by the gradient
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft.withValues(alpha: 0.95),
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

    late final Widget mascot;
    switch (mood) {
      case RevoMood.happy:
        final breath = math.sin(phase);
        mascot = Transform.translate(
          offset: Offset(0, breath * 1.6),
          child: Mascot(
            size: size,
            blink: blink(),
            look: Offset(-0.30 + math.sin(phase + 1) * 0.14,
                math.cos(phase * 2) * 0.1),
            squash: breath * 0.04,
            tilt: math.sin(phase + 2) * 0.03,
            glow: true,
          ),
        );
      case RevoMood.sad:
        final drift = math.sin(phase * 0.6);
        mascot = Transform.translate(
          offset: Offset(0, 3 + drift),
          child: Mascot(
            size: size * 0.95,
            blink: blink(),
            look: Offset(-0.1 + drift * 0.08, 0.5),
            tilt: -0.1,
            glow: false,
          ),
        );
      case RevoMood.panicking:
        // A GENTLE alert bob for the greeting — attentive, not frantic. (The
        // urgency read lives in the hero's numbers, not a shaking mascot.)
        mascot = Transform.translate(
          offset: Offset(0, math.sin(phase * 2) * 2.2),
          child: Mascot(
            size: size,
            look: Offset(-0.15 + math.sin(phase) * 0.18, -0.1),
            squash: math.sin(phase * 2) * 0.05,
            tilt: math.sin(phase) * 0.05,
            glow: true,
          ),
        );
    }
    // Revo is talking toward the greeting on his RIGHT, so his tail points LEFT
    // — mirror the base mascot (whose tail is bottom-right).
    return Transform.flip(flipX: true, child: mascot);
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
  const UpNextStrip({
    super.key,
    required this.items,
    required this.onTap,
    this.windowLabel = 'next 7 days',
    this.onSeeAll,
  });

  final List<Task> items;
  final void Function(Task) onTap;

  /// The little window hint next to the "Up next" title — reflects the anchor
  /// day ("next 7 days" for today, else "from `Wkd D`").
  final String windowLabel;

  /// Tapped the header → arrow opens the full upcoming list. Null hides it.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    // All items in the 7-day window from the anchor day, soonest first.
    final shown = items.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 12, 12),
          child: Row(
            children: [
              const Text('Up next',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.ink)),
              const SizedBox(width: 8),
              // Window hint — reflects the selected calendar day.
              Text(windowLabel,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkFaint.withValues(alpha: 0.9))),
              const Spacer(),
              if (onSeeAll != null)
                // The right-arrow → the full upcoming list, all of it.
                GestureDetector(
                  onTap: onSeeAll,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppColors.inkSoft),
                  ),
                ),
            ],
          ),
        ),
        if (shown.isEmpty)
          // Quiet window — keep the section (and its label) so tapping a calm
          // day still reads as a response, not a disappearance.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: AppColors.inkFaint.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Nothing in this window — you’re free.',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          )
        else
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
    // A local photo wins — a round face for birthdays, a rounded picture else.
    if (task.hasImage) {
      final circular = task.category == TaskCategory.birthday;
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(circular ? size : 11),
        ),
        child: Image.file(File(task.imagePath!), fit: BoxFit.cover),
      );
    }
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

// ── Compact week-strip calendar ──────────────────────────────────────────────

/// A small horizontal strip of dates (a scrollable running calendar). Today sits
/// in the CENTRE with a few past days to its left and future days to its right.
/// Days that have a reminder show an accent dot; the selected day is a filled
/// accent pill. Tapping a day calls [onSelect] — the Home then shows the
/// reminders from that day onward. Takes very little vertical space.
class WeekStripCalendar extends StatefulWidget {
  const WeekStripCalendar({
    super.key,
    required this.tasks,
    required this.selected,
    required this.onSelect,
    this.daysBefore = 7,
    this.daysAhead = 30,
  });

  final List<Task> tasks;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// Past days shown to the left of today.
  final int daysBefore;

  /// Future days shown to the right of today.
  final int daysAhead;

  @override
  State<WeekStripCalendar> createState() => _WeekStripCalendarState();
}

class _WeekStripCalendarState extends State<WeekStripCalendar> {
  final _controller = ScrollController();

  static const _wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Set of day-keys that have at least one scheduled, undone reminder.
  late Set<int> _busyDays;

  int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static const _cellW = 50.0;
  static const _gap = 8.0;

  @override
  void initState() {
    super.initState();
    _recompute();
    // Centre today after first layout: scroll so today's cell lands mid-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centreToday());
  }

  void _centreToday() {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    // Offset of today's cell start (today is at index `daysBefore`).
    final todayStart = widget.daysBefore * (_cellW + _gap);
    // Shift so the cell's centre aligns with the viewport centre.
    final target = todayStart + _cellW / 2 - viewport / 2;
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(target.clamp(0.0, max));
  }

  @override
  void didUpdateWidget(covariant WeekStripCalendar old) {
    super.didUpdateWidget(old);
    _recompute();
  }

  void _recompute() {
    _busyDays = {
      for (final t in widget.tasks)
        if (t.isScheduled && !t.done) _key(_dayOf(t.dueAt!)),
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _dayOf(DateTime.now());
    // Start `daysBefore` days ago so today sits mid-strip, past on the left.
    final start = today.subtract(Duration(days: widget.daysBefore));
    final count = widget.daysBefore + widget.daysAhead;
    final days = [
      for (var i = 0; i < count; i++) start.add(Duration(days: i)),
    ];
    final sel = _dayOf(widget.selected);

    return SizedBox(
      height: 78,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (_, i) {
          final d = days[i];
          final selected = _key(d) == _key(sel);
          final busy = _busyDays.contains(_key(d));
          final isToday = _key(d) == _key(today);
          final isPast = d.isBefore(today);
          // Month label appears on the 1st of a month (and the very first cell).
          final showMonth = i == 0 || d.day == 1;
          return GestureDetector(
            onTap: () => widget.onSelect(d),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _cellW,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accent, AppColors.accentDeep],
                      )
                    : null,
                // Today (when not the selected day) gets a tinted fill so it
                // stands apart from ordinary days at a glance.
                color: selected
                    ? null
                    : (isToday
                        ? AppColors.accent.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? AppColors.accent
                      : (isToday
                          ? AppColors.accent.withValues(alpha: 0.85)
                          : AppColors.glassBorder),
                  width: (isToday && !selected) ? 1.5 : 1,
                ),
                // A soft glow on today so the eye lands on it.
                boxShadow: (isToday && !selected)
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Opacity(
                // Past days are dimmed so today+future read as the focus.
                opacity: (isPast && !selected) ? 0.45 : 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      showMonth ? _mo[d.month - 1] : _wd[d.weekday - 1],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: selected ? Colors.white : AppColors.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Today shows a tiny "TODAY" tag; every other day keeps the
                    // reminder dot (hollow/white on the selected pill).
                    if (isToday)
                      Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 7.5,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: selected ? Colors.white : AppColors.accent,
                        ),
                      )
                    else
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: busy
                              ? (selected ? Colors.white : AppColors.accent)
                              : Colors.transparent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Browse grid — easy access to every product ───────────────────────────────

/// The heart of the Home screen: a grid of "product" tiles (Subscriptions,
/// Important dates, SIPs, Insurance, Bills) plus an "All" tile — each a glowing
/// orb, a name, and a live count. Tapping one opens that category's collection.
///
/// Space-themed: every tile is a dark glass panel with a category-tinted glow
/// orb (a little planet), consistent with the Orbit palette. Counts come from
/// the task list so the grid always reflects reality.
class BrowseGrid extends StatelessWidget {
  const BrowseGrid({
    super.key,
    required this.tasks,
    required this.onOpenCategory,
    required this.onOpenAll,
  });

  final List<Task> tasks;

  /// Tap a category row → open its collection page.
  final void Function(TaskCategory) onOpenCategory;

  /// Tap the "All" row → open the full collection.
  final VoidCallback onOpenAll;

  int _countFor(TaskCategory c) => tasks.where((t) => t.category == c).length;

  /// A category's info: the soonest upcoming item's name as a subtitle, plus a
  /// short "when" tag shown separately (so it never gets cut off). Returns a
  /// gentle prompt + no tag when there's nothing scheduled.
  (String, String?) _infoFor(TaskCategory c) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = tasks
        .where((t) => t.category == c && t.isScheduled)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    if (upcoming.isEmpty) {
      return (_countFor(c) == 0 ? 'Nothing yet' : 'No dates set', null);
    }
    final next = upcoming.firstWhere(
      (t) => !DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day)
          .isBefore(today),
      orElse: () => upcoming.first,
    );
    final d = DateTime(next.dueAt!.year, next.dueAt!.month, next.dueAt!.day);
    final days = d.difference(today).inDays;
    final when = days < 0
        ? 'soon'
        : days == 0
            ? 'today'
            : days == 1
                ? 'tomorrow'
                : days < 30
                    ? 'in ${days}d'
                    : 'in ${(days / 30).round()}mo';
    return ('Next: ${next.title}', when);
  }

  @override
  Widget build(BuildContext context) {
    // Only categories that have items — plus "All" — so the list stays useful
    // and quick to scan (no empty rows cluttering it).
    final live = [
      for (final c in kBrowseCategories)
        if (_countFor(c) > 0) c,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: Row(
            children: [
              const Text(
                'Browse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'your orbit',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkFaint.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        // A plain list — clean rows split by hairlines, no boxes.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < live.length; i++) ...[
                Builder(builder: (_) {
                  final (subtitle, whenTag) = _infoFor(live[i]);
                  return _BrowseRow(
                    icon: live[i].icon,
                    label: live[i].label,
                    subtitle: subtitle,
                    trailingWhen: whenTag,
                    count: _countFor(live[i]),
                    onTap: () => onOpenCategory(live[i]),
                  );
                }),
                const _BrowseDivider(),
              ],
              // The catch-all "All" row — every reminder in one place.
              _BrowseRow(
                icon: Icons.blur_on_rounded,
                label: 'All reminders',
                subtitle: tasks.isEmpty
                    ? 'Nothing yet'
                    : 'Everything in one place',
                count: tasks.length,
                onTap: onOpenAll,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One category as a plain LIST row (NO box) — an accent icon badge, the name +
/// an info line, and a right-aligned "when" chip so the timing is never cut off.
/// Reads as a fast, scannable launcher; a press subtly highlights it.
class _BrowseRow extends StatefulWidget {
  const _BrowseRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.trailingWhen,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  /// A short "when" tag (e.g. "in 2d") shown as a pill on the right; null hides
  /// it. Guaranteed visible — never truncated by the subtitle.
  final String? trailingWhen;

  @override
  State<_BrowseRow> createState() => _BrowseRowState();
}

class _BrowseRowState extends State<_BrowseRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _down
            ? AppColors.accent.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Accent icon badge.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Icon(widget.icon, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            // Name + info line.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Count in the accent, right after the name.
                      Text(
                        '${widget.count}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkFaint,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
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
            // The "when" pill — always fully visible.
            if (widget.trailingWhen != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.trailingWhen!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.inkFaint.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}

/// A hairline between browse rows.
class _BrowseDivider extends StatelessWidget {
  const _BrowseDivider();
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 58),
        color: AppColors.hairline,
      );
}
