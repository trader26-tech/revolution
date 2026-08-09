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
            height: 210,
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

// ── Up-Next card helpers ─────────────────────────────────────────────────────
//
// Everything below stays inside the Orbit palette — the single violet accent
// (AppColors.accent) plus the ink/card/glass neutrals. No per-category hues.
// Differentiation comes from LAYOUT, SIZE and derived COPY, not colour: a
// subscription card, a SIP card and an occasion card are each shaped and worded
// for what that thing actually is, so a glance tells you which is which.

int _daysUntil(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(d.year, d.month, d.day).difference(today).inDays;
}

/// "Today" / "Tomorrow" / "Fri" / "in 3 wk" — a compact, human due hint.
String _whenLabel(int days, DateTime due) {
  if (days <= 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 7) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return wd[due.weekday - 1];
  }
  if (days < 30) return 'in ${(days / 7).round()} wk';
  return 'in ${(days / 30).round()} mo';
}

/// A short "by Fri" / "by Aug 14" phrase for the SIP nudge sentence.
String _byLabel(int days, DateTime due) {
  if (days <= 0) return 'today';
  if (days == 1) return 'by tomorrow';
  if (days < 7) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'by ${wd[due.weekday - 1]}';
  }
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
    'Oct', 'Nov', 'Dec'];
  return 'by ${mo[due.month - 1]} ${due.day}';
}

/// The amount in its own currency, grouped Indian-style for INR.
String _amountStr(Task t) {
  final cur = currencyOf(t.currency);
  final a = t.amount!;
  final whole = a == a.roundToDouble();
  final body = whole
      ? formatAmount(a.round().toString(), cur.grouping)
      : a.toStringAsFixed(2);
  return '${cur.symbol}$body';
}

/// Age on the UPCOMING occasion (rolls to next year if this year's has passed).
int? _ageOnNext(Task t) {
  if (t.birthYear == null || t.dueAt == null) return null;
  final now = DateTime.now();
  final thisYears = DateTime(now.year, t.dueAt!.month, t.dueAt!.day);
  final year = thisYears.isBefore(DateTime(now.year, now.month, now.day))
      ? now.year + 1
      : now.year;
  return year - t.birthYear!;
}

/// The Up-Next card — routes to a layout tailored to the task's category, so
/// each kind of thing looks and reads differently at a glance.
class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.task, required this.onTap});
  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget inner = switch (task.category) {
      TaskCategory.investment => _SipCard(task: task),
      TaskCategory.birthday => _OccasionCard(task: task),
      TaskCategory.subscription => _SubscriptionCard(task: task),
      _ => _GenericCard(task: task),
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: inner,
    );
  }
}

/// Shared shell — the violet-tinted glass card every layout is poured into, so
/// the family reads as one system. [urgent] lifts the accent edge for ≤1 day.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.width,
    required this.child,
    this.urgent = false,
  });
  final double width;
  final Widget child;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    // Calm, solid surface — a faint accent wash only, so the hero animation and
    // the highlighted description carry the card, not a glowing background.
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: urgent ? 0.10 : 0.05),
            AppColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: urgent
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.glassBorder,
        ),
      ),
      child: child,
    );
  }
}

/// The WHEN-chip — the clearest "when is this happening" signal on the card.
/// A short countdown ("Today" / "Tomorrow" / "In 3 days"). Filled accent and
/// gently pulsing when it's ≤1 day out (urgent), quieter otherwise. It's the
/// one element on the card meant to catch the eye first.
class _WhenChip extends StatefulWidget {
  const _WhenChip({required this.days, required this.due});
  final int days;
  final DateTime due;

  @override
  State<_WhenChip> createState() => _WhenChipState();
}

class _WhenChipState extends State<_WhenChip>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  bool get _urgent => widget.days <= 1;

  @override
  void initState() {
    super.initState();
    if (_urgent) {
      _pulse = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  String _text() {
    final d = widget.days;
    if (d <= 0) return 'TODAY';
    if (d == 1) return 'TOMORROW';
    if (d < 7) return 'IN $d DAYS';
    if (d < 14) return 'NEXT WEEK';
    if (d < 30) return 'IN ${(d / 7).round()} WKS';
    return 'IN ${(d / 30).round()} MO';
  }

  @override
  Widget build(BuildContext context) {
    final chip = _urgent
        ? _filled(_text())
        : _outlined(_text());
    if (_pulse == null) return chip;
    return AnimatedBuilder(
      animation: _pulse!,
      builder: (context, child) {
        final g = 0.35 + 0.35 * _pulse!.value; // glow strength
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: g),
                blurRadius: 14,
              ),
            ],
          ),
          child: child,
        );
      },
      child: chip,
    );
  }

  // Filled accent pill — the urgent, high-visibility state.
  Widget _filled(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentDeep]),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: Colors.white,
              )),
        ],
      ),
    );
  }

  // Quiet outlined pill — the calmer, further-out state.
  Widget _outlined(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: AppColors.accent,
          )),
    );
  }
}

// Every rich card is HERO-LED, like the reference: a big animated centrepiece
// up top (the "41" burst, the amount, the logo), then the title, then the
// DESCRIPTION as the highlight. Cards are wide (~284) so nothing truncates and
// the horizontal space is actually used — you see ~1.3 cards, then scroll.

const double _kCardW = 284;

/// A punchy, benefit-framed line for a subscription — derived from the brand so
/// it says what the money PROTECTS, not just what it costs. This is the card's
/// HIGHLIGHT, so it can be a full phrase.
String _subscriptionPunch(Task t) {
  final s = '${t.title} ${t.iconName ?? ''}'.toLowerCase();
  bool has(List<String> keys) => keys.any(s.contains);

  if (has(['netflix', 'prime video', 'hotstar', 'disney', 'hbo', 'max '])) {
    return 'Keep it funded so your binge nights stay uninterrupted.';
  }
  if (has(['spotify', 'apple music', 'youtube music', 'gaana', 'wynk',
      'soundcloud'])) {
    return 'Keep it topped up so the music never stops.';
  }
  if (has(['chatgpt', 'openai', 'claude', 'gemini', 'copilot', 'midjourney',
      'perplexity', 'cursor', ' ai'])) {
    return 'Keep it live so your AI copilots keep flying.';
  }
  if (has(['icloud', 'google one', 'dropbox', 'onedrive', 'drive'])) {
    return 'Keep it paid so your files always have a home.';
  }
  if (has(['youtube', 'twitch'])) {
    return 'Keep it running so the watch-list keeps rolling.';
  }
  if (has(['gym', 'fitness', 'cult', 'peloton', 'strava'])) {
    return 'Keep it paid so your streak and your gains stay alive.';
  }
  if (has(['adobe', 'figma', 'notion', 'canva', 'office', 'microsoft 365'])) {
    return 'Keep it active so your workflow never skips a beat.';
  }
  if (has(['linkedin', 'medium', 'nyt', 'times', 'news'])) {
    return 'Keep it paid so your daily read never hits a paywall.';
  }
  if (has(['game', 'xbox', 'playstation', 'psn', 'steam', 'nintendo'])) {
    return 'Keep it topped up so game night stays online.';
  }
  return 'Keep it funded so it never blinks out on you.';
}

// ── Subscription card — logo hero + "what it keeps alive" highlight ───────────
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil(task.dueAt!);
    final priceLine = task.hasAmount
        ? '${_amountStr(task)} · ${frequencyLabel(task.repeat, task.repeatTimes).toLowerCase()}'
        : frequencyLabel(task.repeat, task.repeatTimes);

    return _HeroCard(
      days: days,
      due: task.dueAt!,
      hero: _SubHero(
        child: _Logo(task: task, size: 56, radius: 15),
      ),
      title: task.title,
      subtitle: priceLine,
      highlight: _subscriptionPunch(task),
      highlightIcon: Icons.favorite_rounded,
    );
  }
}

// ── SIP card — the amount is the hero, "keep it ready" is the highlight ───────
class _SipCard extends StatelessWidget {
  const _SipCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil(task.dueAt!);
    final has = task.hasAmount;
    final byWhen = _byLabel(days, task.dueAt!);

    return _HeroCard(
      days: days,
      due: task.dueAt!,
      hero: _SipHero(
        child: has
            ? FittedBox(
                child: Text(
                  _amountStr(task),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: AppColors.ink,
                  ),
                ),
              )
            : const Icon(Icons.trending_up_rounded,
                size: 50, color: AppColors.accent),
      ),
      title: task.title,
      subtitle: has ? 'SIP · every instalment' : 'SIP instalment',
      highlight: has
          ? 'Keep ${_amountStr(task)} in your bank $byWhen so your SIP goes through and your wealth keeps compounding.'
          : 'Fund your account $byWhen so your SIP goes through and your wealth keeps compounding.',
      highlightIcon: Icons.account_balance_wallet_rounded,
    );
  }
}

// ── Occasion card — the big age burst (the reference), warm highlight ─────────
class _OccasionCard extends StatelessWidget {
  const _OccasionCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil(task.dueAt!);
    final age = _ageOnNext(task);
    final type = task.subCategory ?? 'Occasion';
    final isBday = type.toLowerCase() == 'birthday';
    final first = task.title.trim().split(RegExp(r'\s+')).first;
    final whenText =
        days <= 0 ? 'today' : (days == 1 ? 'tomorrow' : 'in $days days');

    // Hero: the big age "41" with drifting confetti when we know it; otherwise
    // the person's face amid the same gentle confetti.
    final Widget hero = age != null
        ? _OccasionHeroFx(
            child: Text(
              '$age',
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: AppColors.ink,
              ),
            ),
          )
        : _OccasionHeroFx(child: _RoundFace(task: task, size: 56));

    final String highlight = age != null
        ? (isBday
            ? '$first turns $age $whenText — don’t miss the wish.'
            : '$age years and counting — mark the moment $whenText.')
        : 'A $type worth remembering — $whenText.';

    return _HeroCard(
      days: days,
      due: task.dueAt!,
      hero: hero,
      title: task.title,
      subtitle: type,
      highlight: highlight,
      highlightIcon:
          isBday ? Icons.emoji_events_rounded : Icons.celebration_rounded,
    );
  }
}

/// The shared HERO card layout — a big animated hero on top, then title +
/// subtitle, then the description as the highlighted line. One structure across
/// every category (consistent); the hero + copy each card passes in (unique).
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.days,
    required this.due,
    required this.hero,
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.highlightIcon,
  });
  final int days;
  final DateTime due;
  final Widget hero;
  final String title;
  final String subtitle;
  final String highlight;
  final IconData highlightIcon;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      width: _kCardW,
      urgent: days <= 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The hero sits in a fixed band, centred, with the due-chip floating
          // in the corner.
          SizedBox(
            height: 78,
            child: Stack(
              children: [
                Center(child: hero),
                Positioned(top: 0, right: 0, child: _WhenChip(days: days, due: due)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Title — allowed to wrap to two lines so nothing gets cut off.
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.ink)),
          const SizedBox(height: 1),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft)),
          const SizedBox(height: 9),
          // The DESCRIPTION — the highlight. Big, ink, up to two full lines.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(highlightIcon, size: 15, color: AppColors.accent),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  highlight,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The hero stage — a fixed 120×72 band that runs one slow loop and paints a
/// category-specific animation BEHIND the child. Each category passes its own
/// [painter] builder, so every card animates differently. Cheap by design: one
/// controller, a RepaintBoundary, painter-only, 3.4s period.
class _HeroStage extends StatefulWidget {
  const _HeroStage({required this.child, required this.painter});
  final Widget child;
  final CustomPainter Function(double t) painter;
  @override
  State<_HeroStage> createState() => _HeroStageState();
}

class _HeroStageState extends State<_HeroStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 120,
        height: 72,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            painter: widget.painter(_c.value),
            child: Center(child: child),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Category-specific heroes — same size + child slot, distinct motion.

/// Subscription → a renewing ring: an accent arc sweeps once around the logo
/// each loop (the "auto-renews" idea), over a faint full track.
class _SubHero extends StatelessWidget {
  const _SubHero({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      _HeroStage(painter: (t) => _RenewRingPainter(t), child: child);
}

class _RenewRingPainter extends CustomPainter {
  _RenewRingPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const r = 34.0;
    // Faint full track.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withValues(alpha: 0.14),
    );
    // The sweeping arc — a quarter-circle chasing around.
    final sweep = math.pi * 0.6;
    final start = t * 2 * math.pi - math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _RenewRingPainter old) => old.t != t;
}

/// SIP → coins stacking: three coin ellipses that rise and settle in sequence,
/// beneath the amount — money accumulating.
class _SipHero extends StatelessWidget {
  const _SipHero({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      _HeroStage(painter: (t) => _CoinsPainter(t), child: child);
}

class _CoinsPainter extends CustomPainter {
  _CoinsPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final baseX = size.width / 2;
    final baseY = size.height - 10;
    for (var i = 0; i < 3; i++) {
      // Each coin has its own phase; rises into place then holds.
      final phase = (t * 3 - i).clamp(0.0, 1.0);
      final ease = Curves.easeOut.transform(phase);
      final y = baseY - i * 8 - 6 * ease;
      final op = 0.30 + 0.5 * ease;
      final rect = Rect.fromCenter(
          center: Offset(baseX, y), width: 30, height: 9);
      canvas.drawOval(
        rect,
        Paint()..color = AppColors.accent.withValues(alpha: op * 0.5),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.accent.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoinsPainter old) => old.t != t;
}

/// Occasion → a birthday feel: a soft candle glow above the hero plus a few
/// confetti dots drifting down. Gentle, not flashy.
class _OccasionHeroFx extends StatelessWidget {
  const _OccasionHeroFx({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      _HeroStage(painter: (t) => _ConfettiPainter(t), child: child);
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;
  // Fixed confetti seeds (x fraction, colour pick, phase offset).
  static const _seeds = [
    [0.16, 0.0, 0.0],
    [0.34, 1.0, 0.45],
    [0.62, 0.0, 0.2],
    [0.80, 1.0, 0.7],
    [0.48, 1.0, 0.9],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _seeds) {
      final x = s[0] * size.width;
      final phase = (t + s[2]) % 1.0;
      final y = phase * size.height;
      final op = (math.sin(phase * math.pi)) * 0.7; // fade in then out
      final color =
          s[1] == 0.0 ? AppColors.accent : const Color(0xFFB9A8FF);
      canvas.drawCircle(
        Offset(x, y),
        2.2,
        Paint()..color = color.withValues(alpha: op.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Generic (bills / insurance / other) → a calm single ripple expanding out.
class _CalmHero extends StatelessWidget {
  const _CalmHero({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      _HeroStage(painter: (t) => _RipplePainter(t), child: child);
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1.0;
      final r = 26 + phase * 22;
      final op = (1 - phase) * 0.35;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = AppColors.accent.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}

// ── Generic card — insurance / bills / other ─────────────────────────────────
class _GenericCard extends StatelessWidget {
  const _GenericCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil(task.dueAt!);
    final byWhen = _byLabel(days, task.dueAt!);
    final (IconData icon, String subtitle, String highlight) =
        switch (task.category) {
      TaskCategory.bills => (
          Icons.receipt_long_rounded,
          task.hasAmount ? _amountStr(task) : 'Bill',
          task.hasAmount
              ? 'Clear ${_amountStr(task)} $byWhen so you dodge the late fee.'
              : 'Settle it $byWhen so you dodge the late fee.'
        ),
      TaskCategory.insurance => (
          Icons.shield_rounded,
          'Insurance',
          'Renew it $byWhen so your cover never lapses.'
        ),
      _ => (
          Icons.bolt_rounded,
          _whenLabel(days, task.dueAt!),
          days <= 1 ? 'This one’s up — knock it out today.' : 'On your radar $byWhen.'
        ),
    };

    return _HeroCard(
      days: days,
      due: task.dueAt!,
      hero: _CalmHero(child: _Logo(task: task, size: 54, radius: 15)),
      title: task.title,
      subtitle: subtitle,
      highlight: highlight,
      highlightIcon: icon,
    );
  }
}

/// A brand logo (with local-image override) — the recognisable mark of the item.
class _Logo extends StatelessWidget {
  const _Logo({required this.task, this.size = 40, this.radius = 12});
  final Task task;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (task.hasImage) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
        child: Image.file(File(task.imagePath!), fit: BoxFit.cover),
      );
    }
    return BrandLogo(
      brand: task.hasIcon
          ? Brand(name: task.iconName ?? task.title, domain: task.iconDomain ?? '')
          : Brand(name: task.title, domain: ''),
      size: size,
      radius: radius,
    );
  }
}

/// A round face for occasions — the person's photo, else a first-letter avatar
/// on the violet logo-tile (no off-palette colour).
class _RoundFace extends StatelessWidget {
  const _RoundFace({required this.task, this.size = 44});
  final Task task;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (task.hasImage) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Image.file(File(task.imagePath!), fit: BoxFit.cover),
      );
    }
    final letter =
        task.title.trim().isNotEmpty ? task.title.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.logoTile,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(letter,
          style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: AppColors.ink)),
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
    // Align today to the LEFT edge after first layout — the user sees today +
    // the days ahead by default; past days are a scroll-left away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _alignTodayLeft());
  }

  void _alignTodayLeft() {
    if (!_controller.hasClients) return;
    // Today is at index `daysBefore`; put its cell start at the strip's left.
    final todayStart = widget.daysBefore * (_cellW + _gap);
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(todayStart.clamp(0.0, max));
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
    // Always show every built-in category (even empty) so it's a launcher —
    // the user can add to any of them, including Important dates before they
    // have their first one.
    final live = kBrowseCategories;

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

// ── Add sheet — "Add to Revolution" (browse slides up from the bottom) ────────

/// Opens the add-browse bottom sheet: a slide-up list of the categories you can
/// add to (Subscription, Occasion, SIP…). Returns the chosen category, or null
/// if dismissed. The caller then opens that category's tailored add form.
Future<TaskCategory?> showAddBrowseSheet(BuildContext context) {
  return showModalBottomSheet<TaskCategory>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AddBrowseSheet(),
  );
}

class _AddBrowseSheet extends StatelessWidget {
  const _AddBrowseSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkFaint.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add to Revolution',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'What would you like to track?',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              for (final c in kBrowseCategories)
                _AddChoiceRow(
                  category: c,
                  onTap: () => Navigator.of(context).pop(c),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category to add — accent icon orb, name, "Add a …" hint, chevron.
class _AddChoiceRow extends StatelessWidget {
  const _AddChoiceRow({required this.category, required this.onTap});
  final TaskCategory category;
  final VoidCallback onTap;

  String get _hint => 'Add a ${category.singular}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.accent.withValues(alpha: 0.12),
              AppColors.card,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
              ),
              child: Icon(category.icon, color: AppColors.accent, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hint,
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
            Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppColors.inkFaint.withValues(alpha: 0.9)),
          ],
        ),
      ),
    );
  }
}
