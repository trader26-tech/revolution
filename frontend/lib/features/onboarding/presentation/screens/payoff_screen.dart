import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_chip_catalog.dart';
import 'chip_select_screen.dart';

/// Screen 3 — the payoff, as one calm, message-first statement.
///
/// The reference: a big centred headline with the number highlighted inline
/// ("That's **62** things to remember this year"), one softly glowing mascot
/// floating below, generous space, and a single muted promise line above the
/// CTA. No constellation, no clutter — the number is the whole point, so we let
/// it breathe.
///
/// The count still animates once on arrival (a quick, dignified climb to the
/// real total) so the number feels earned rather than printed, but the layout
/// stays fixed and centred the entire time.
class PayoffScreen extends StatefulWidget {
  const PayoffScreen({super.key, required this.picked});

  final Set<String> picked;

  @override
  State<PayoffScreen> createState() => _PayoffScreenState();
}

class _PayoffScreenState extends State<PayoffScreen>
    with TickerProviderStateMixin {
  /// One-shot entrance timeline: headline → count-up → mascot → promise.
  late final AnimationController _c;

  /// Endless idle loop — a whisper of breathing in the mascot's glow.
  late final AnimationController _idle;

  // Timeline stops (fractions of [_c]).
  static const _headlineStart = 0.00;
  static const _countStart = 0.14;
  static const _countEnd = 0.66;
  static const _mascotStart = 0.62;
  static const _promiseStart = 0.78;

  int _total = 0;

  @override
  void initState() {
    super.initState();
    _total = _countReminders();
    _c = AnimationController(vsync: this, duration: _duration)..forward();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant PayoffScreen old) {
    super.didUpdateWidget(old);
    // The parent rebuilds when the user lands here (and when picks change) —
    // recompute and replay so arriving always shows the reveal.
    _total = _countReminders();
    _c
      ..duration = _duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    _idle.dispose();
    super.dispose();
  }

  /// A touch more time for bigger years, so the climb stays readable.
  Duration get _duration =>
      Duration(milliseconds: (1500 + _total * 5).clamp(1500, 2800));

  /// How many times a year one picked chip fires.
  static int _firesPerYear(RepeatCadence f) => switch (f) {
        RepeatCadence.daily => 365,
        RepeatCadence.weekly => 52,
        RepeatCadence.monthly => 12,
        RepeatCadence.yearly => 1,
        RepeatCadence.none => 1,
      };

  /// Total reminders a year across everything the user picked.
  int _countReminders() {
    final picked =
        widget.picked.isNotEmpty ? widget.picked : preselectedChipKeys();
    var total = 0;
    for (final s in kOnboardingChipSections) {
      for (final item in s.items) {
        if (picked.contains(item.key)) {
          total += _firesPerYear(item.defaultFrequency);
        }
      }
    }
    return total;
  }

  /// The live running count, eased across the count window.
  int get _running {
    final t = ((_c.value - _countStart) / (_countEnd - _countStart))
        .clamp(0.0, 1.0);
    return (_total * Curves.easeOutCubic.transform(t)).round();
  }

  /// Fade + slide-up reveal for a slice of the timeline.
  Widget _reveal(double start, Widget child, {double window = 0.22}) {
    final t = Curves.easeOutCubic
        .transform(((_c.value - start) / window).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_c, _idle]),
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 5),
              _headline(),
              const Spacer(flex: 4),
              _mascot(),
              const Spacer(flex: 4),
              _promise(),
              const Spacer(flex: 2),
            ],
          ),
        );
      },
    );
  }

  // ── The headline — one sentence, the number carrying it ─────────────────────

  /// The big centred statement, with the running number highlighted in accent
  /// violet inline — exactly the reference's shape. The number settles with a
  /// tiny pop the instant the count completes.
  Widget _headline() {
    final settle = ((_c.value - _countEnd) / 0.10).clamp(0.0, 1.0);
    final pop = math.sin(settle * math.pi) * 0.04;

    return _reveal(
      _headlineStart,
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: "That's "),
            // The number: accent violet, a hair heavier, tabular so the width
            // doesn't jitter as it counts.
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.scale(
                scale: 1 + pop,
                child: Text(
                  '$_running',
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: AppColors.accent,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' things to remember this year'),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 34,
          height: 1.22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: AppColors.ink,
        ),
      ),
    );
  }

  // ── The mascot — one calm glow, floating ────────────────────────────────────

  Widget _mascot() {
    final raw =
        ((_c.value - _mascotStart) / 0.24).clamp(0.0, 1.0);
    final t = Curves.easeOutCubic.transform(raw);
    final pop = Curves.easeOutBack.transform(raw);
    // A slow breathing bob for the floating-in-space feel.
    final bob = math.sin(_idle.value * 2 * math.pi) * 5;

    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Transform.scale(
          scale: 0.7 + 0.3 * pop,
          child: const AnimatedMascot(size: 128),
        ),
      ),
    );
  }

  // ── The promise — one muted line above the CTA ──────────────────────────────

  Widget _promise() {
    return _reveal(
      _promiseStart,
      Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: 'Revolution remembers '),
            TextSpan(
              text: 'every single one.',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 17,
          height: 1.4,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}
