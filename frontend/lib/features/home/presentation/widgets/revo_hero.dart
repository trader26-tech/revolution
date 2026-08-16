import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../tasks/domain/task.dart';

/// How Revo feels about your task situation right now. Priority, most urgent
/// first: something due TODAY and not done outranks merely-overdue, which
/// outranks all-clear.
enum RevoMood { panicking, sad, happy }

/// Read the user's mood from their tasks. Simple, honest rules:
///   • panicking — at least one task due TODAY that isn't done yet.
///   • sad       — nothing due today undone, but something overdue is pending.
///   • happy     — everything's handled (or there's simply nothing due).
///
/// [now] is injectable for tests; defaults to the wall clock.
RevoMood revoMoodFor(List<Task> tasks, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());

  var dueTodayUndone = false;
  var overduePending = false;

  for (final t in tasks) {
    if (!t.isScheduled || t.done) continue;
    final day = _dayOf(t.dueAt!);
    if (day == today) {
      dueTodayUndone = true;
    } else if (day.isBefore(today)) {
      overduePending = true;
    }
  }

  if (dueTodayUndone) return RevoMood.panicking;
  if (overduePending) return RevoMood.sad;
  return RevoMood.happy;
}

/// How many tasks are due today and still undone (for the "1 due today" line).
int dueTodayCount(List<Task> tasks, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  return tasks
      .where((t) =>
          t.isScheduled && !t.done && _dayOf(t.dueAt!) == today)
      .length;
}

/// How many overdue tasks are still pending (for the "2 overdue" line).
int overdueCount(List<Task> tasks, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  return tasks
      .where((t) =>
          t.isScheduled && !t.done && _dayOf(t.dueAt!).isBefore(today))
      .length;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Home hero: Revo, alive and reacting to your day, beside a short line that
/// tells you where you stand. He's the same mouthless mascot as everywhere else
/// — his STATE reads purely through body language (gaze, bounce, tremble, tilt)
/// and his glow, never a face swap:
///   • happy     — calm gentle bob, warm glow, gaze wandering easily.
///   • sad       — dimmer, sinks a little, tilts down, gaze drifts low.
///   • panicking — a fast jittery tremble, wide alert eyes darting, hot glow.
class RevoHero extends StatefulWidget {
  const RevoHero({super.key, required this.tasks});

  final List<Task> tasks;

  @override
  State<RevoHero> createState() => _RevoHeroState();
}

class _RevoHeroState extends State<RevoHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    // One perpetual clock drives all the idle/panic motion.
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = revoMoodFor(widget.tasks);
    final (title, subtitle, tint) = _copyFor(mood);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.14),
            AppColors.card.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          // Revo — 66px, driven live by the mood.
          SizedBox(
            width: 66,
            height: 66,
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) => _MoodMascot(t: _loop.value, mood: mood),
            ),
          ),
          const SizedBox(width: 14),
          // The contextual line.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: tint,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Title, subtitle, and accent tint for each mood — real counts, warm words.
  (String, String, Color) _copyFor(RevoMood mood) {
    switch (mood) {
      case RevoMood.panicking:
        final n = dueTodayCount(widget.tasks);
        return (
          n == 1 ? '1 due today!' : '$n due today!',
          'Remo\'s on high alert — let\'s knock these out.',
          const Color(0xFFFFC66B), // warm amber
        );
      case RevoMood.sad:
        final n = overdueCount(widget.tasks);
        return (
          n == 1 ? '1 slipped by' : '$n slipped by',
          'Remo\'s a little down — tap to catch up.',
          const Color(0xFFA5B4FC), // periwinkle
        );
      case RevoMood.happy:
        return (
          'All clear',
          'Nothing due — Remo\'s happy and relaxed.',
          AppColors.accent,
        );
    }
  }
}

/// Draws the mouthless Revo mascot posed for a given [mood], animated by the
/// loop time [t] (0..1). Everything reads through gaze, motion, tilt, and glow.
class _MoodMascot extends StatelessWidget {
  const _MoodMascot({required this.t, required this.mood});

  final double t;
  final RevoMood mood;

  @override
  Widget build(BuildContext context) {
    final phase = t * 2 * math.pi;

    switch (mood) {
      case RevoMood.happy:
        // Calm breathing bob, easy wandering gaze, warm glow.
        final breath = math.sin(phase);
        return Transform.translate(
          offset: Offset(0, breath * 2.0),
          child: Mascot(
            size: 66,
            blink: _blink(t, 0.5),
            look: Offset(-0.35 + math.sin(phase + 1.0) * 0.22,
                math.cos(phase * 2) * 0.12),
            squash: breath * 0.04,
            tilt: math.sin(phase + 2.0) * 0.03,
            glow: true,
          ),
        );

      case RevoMood.sad:
        // Sinks, tilts down, dim, gaze drifts low and slow. Dimmer glow via a
        // slightly smaller, lower body — never a frown (there's no mouth).
        final drift = math.sin(phase * 0.6);
        return Opacity(
          opacity: 0.9,
          child: Transform.translate(
            offset: Offset(0, 4 + drift * 1.2), // sits low
            child: Mascot(
              size: 62, // a touch smaller — deflated
              blink: _blink(t, 0.4),
              look: Offset(-0.15 + drift * 0.1, 0.55), // looking down
              squash: -0.05, // slightly taller/drooped
              tilt: -0.12 + drift * 0.02, // head tips down
              glow: false, // dimmer — no halo
            ),
          ),
        );

      case RevoMood.panicking:
        // Fast jitter tremble, wide darting eyes, occasional startled blink,
        // hot glow. Urgency you feel at a glance.
        final jx = math.sin(t * 2 * math.pi * 9) * 1.6;
        final jy = math.cos(t * 2 * math.pi * 11) * 1.4;
        final dart = math.sin(t * 2 * math.pi * 6); // eyes flicking
        return Transform.translate(
          offset: Offset(jx, jy),
          child: Mascot(
            size: 68, // a hair bigger — puffed with alarm
            blink: _panicBlink(t),
            look: Offset(dart * 0.5, -0.2 + math.cos(t * 2 * math.pi * 7) * 0.2),
            squash: math.sin(t * 2 * math.pi * 9) * 0.06,
            tilt: math.sin(t * 2 * math.pi * 8) * 0.06,
            glow: true,
          ),
        );
    }
  }

  /// A gentle double-blink spike centred at loop-time [at].
  double _blink(double t, double at) {
    double spike(double c) {
      final d = (t - c).abs();
      return d > 0.02 ? 0 : 1 - d / 0.02;
    }

    return (spike(at) + spike(at + 0.05)).clamp(0.0, 1.0);
  }

  /// Panic blinks: quick, frequent, startled.
  double _panicBlink(double t) {
    final s = math.sin(t * 2 * math.pi * 5);
    return s > 0.9 ? (s - 0.9) / 0.1 : 0;
  }
}
