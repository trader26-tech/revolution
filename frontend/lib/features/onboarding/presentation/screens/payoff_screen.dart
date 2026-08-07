import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_chip_catalog.dart';
import 'chip_select_screen.dart';

/// Screen 3 — the payoff, told as a STORY, not a statement.
///
/// The sequence is a little conversation with Revo, in order:
///   1. Revo floats in, alone in the sky.
///   2. A speech bubble pops above it: "That's [31] things to remember this
///      year…" — the number climbing live while Revo watches it stack up.
///   3. A beat. Then the second bubble lands: "But don't worry — Revo's got
///      you." and Revo does a happy double-hop, gaze dropping from the number
///      to YOU.
///   4. One muted closing line fades in under it all.
///
/// Chat-style bubbles (grouped messages, no comic tails) keep it modern; the
/// story structure — problem, beat, hero — is carried purely by timing and
/// Revo's body language.
class PayoffScreen extends StatefulWidget {
  const PayoffScreen({super.key, required this.picked, this.onDone});

  final Set<String> picked;

  /// Finish onboarding — the flow's "we're done" callback. The button lives on
  /// THIS screen (like the intro's) rather than in the flow's shared bottom
  /// bar, so no CTA can ever bleed onto the intro or wizard during a page
  /// transition. Null in previews/tests → the button hides.
  final VoidCallback? onDone;

  @override
  State<PayoffScreen> createState() => _PayoffScreenState();
}

class _PayoffScreenState extends State<PayoffScreen>
    with TickerProviderStateMixin {
  /// One-shot story timeline: Revo → bubble 1 + count → beat → bubble 2 +
  /// hop → closing line.
  late final AnimationController _c;

  /// Endless idle loop — breathing bob, wandering gaze, occasional blinks.
  late final AnimationController _idle;

  // Story beats (fractions of [_c]). The gap between the count settling and
  // bubble 2 is deliberate — the pause IS the "uh oh…" beat.
  static const _revoStart = 0.00;
  static const _bubble1Start = 0.18;
  static const _countStart = 0.28;
  static const _countEnd = 0.58;
  static const _bubble2Start = 0.72;
  static const _hopStart = 0.72;
  static const _hopEnd = 0.90;
  static const _promiseStart = 0.90;

  int _total = 0;

  @override
  void initState() {
    super.initState();
    _total = _countReminders();
    _c = AnimationController(vsync: this, duration: _duration)..forward();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant PayoffScreen old) {
    super.didUpdateWidget(old);
    // The parent rebuilds when the user lands here (and when picks change) —
    // recompute and replay so arriving always plays the story from the top.
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
      Duration(milliseconds: (2600 + _total * 5).clamp(2600, 4000));

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

  /// Linear progress through a timeline slice — safe for opacity.
  double _lin(double start, [double window = 0.22]) =>
      ((_c.value - start) / window).clamp(0.0, 1.0);

  /// Fade + slide-up reveal for a slice of the timeline.
  Widget _reveal(double start, Widget child, {double window = 0.22}) {
    final t = Curves.easeOutCubic.transform(_lin(start, window));
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 5),
              _bubble(
                start: _bubble1Start,
                child: _countLine(),
              ),
              const SizedBox(height: 10),
              _bubble(
                start: _bubble2Start,
                child: _reassuranceLine(),
              ),
              const SizedBox(height: 22),
              _revo(),
              const Spacer(flex: 3),
              _promise(),
              const SizedBox(height: 22),
              if (widget.onDone != null) _getStarted(),
              const Spacer(flex: 2),
            ],
          ),
        );
      },
    );
  }

  // ── The speech bubbles — grouped chat messages from Revo ────────────────────

  /// A message bubble that pops in (scale + fade, easeOutBack) at [start].
  /// It always occupies its space, so nothing below shifts when it appears.
  Widget _bubble({required double start, required Widget child}) {
    final raw = _lin(start, 0.12);
    final pop = Curves.easeOutBack.transform(raw);
    return Opacity(
      opacity: raw,
      child: Transform.scale(
        scale: 0.85 + 0.15 * pop,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Bubble 1 — the problem, with the number climbing live. It settles with a
  /// tiny pop the instant the count completes.
  Widget _countLine() {
    final settle = _lin(_countEnd, 0.10);
    final pop = math.sin(settle * math.pi) * 0.06;

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: "That's "),
          // Accent violet, heavier, tabular so the width doesn't jitter.
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.scale(
              scale: 1 + pop,
              child: Text(
                '$_running',
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.accent,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const TextSpan(text: ' things to remember this year…'),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 21,
        height: 1.35,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.ink,
      ),
    );
  }

  /// Bubble 2 — the turn of the story.
  Widget _reassuranceLine() {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: "But don't worry — "),
          TextSpan(
            text: "Revo's got you.",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.ink,
      ),
    );
  }

  // ── Revo — enters first, reacts to every beat ───────────────────────────────

  Widget _revo() {
    final raw = _lin(_revoStart, 0.16);
    final t = Curves.easeOutCubic.transform(raw);
    final entrancePop = Curves.easeOutBack.transform(raw);

    final idle = _idle.value;
    final breath = math.sin(idle * 2 * math.pi);

    // The happy double-hop when bubble 2 lands: two clean bumps, with a
    // cartoon stretch while airborne.
    final hopP = _lin(_hopStart, _hopEnd - _hopStart);
    final hop = math.sin(hopP * 2 * math.pi).abs() *
        (1 - Curves.easeInCubic.transform(hopP)) *
        14;
    final airborneStretch = -0.10 * math.sin(hopP * 2 * math.pi).abs();

    // Gaze: watching the number stack up above (story beat 1) → dropping to
    // look at YOU once Revo has your back (beat 2).
    final reassure = Curves.easeOutCubic.transform(_lin(_bubble2Start, 0.14));
    final look = Offset(
      math.sin(idle * 2 * math.pi + 1.2) * 0.16,
      -0.55 * (1 - reassure) +
          0.08 * reassure +
          math.cos(idle * 4 * math.pi) * 0.06,
    );

    // Occasional blinks on the idle clock, plus one deliberate blink right as
    // the reassurance lands — a slow, confident "trust me".
    final blink = (_blinkSpike(idle, 0.36) +
            _blinkSpike(idle, 0.43) +
            _blinkSpike(idle, 0.82) +
            math.sin(Curves.easeInOut.transform(_lin(_bubble2Start, 0.10)) *
                math.pi))
        .clamp(0.0, 1.0);

    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, breath * 4 - hop),
        child: Transform.scale(
          scale: 0.6 + 0.4 * entrancePop,
          child: Mascot(
            size: 132,
            blink: blink,
            look: look,
            squash: breath * 0.05 + airborneStretch,
            tilt: math.sin(idle * 2 * math.pi + 2.1) * 0.03,
          ),
        ),
      ),
    );
  }

  /// A quick eye-close spike centred at loop-time [at] (same shape as the
  /// mascot's own idle blinks).
  static double _blinkSpike(double t, double at) {
    final d = (t - at).abs();
    return d > 0.022 ? 0 : 1 - (d / 0.022);
  }

  // ── The closing line — quiet proof under the story ──────────────────────────

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
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.inkSoft,
        ),
      ),
      window: 0.10,
    );
  }

  /// The "Get started" CTA — the last beat of the story, landing just after the
  /// closing line. Full-width to match the app's primary buttons.
  Widget _getStarted() {
    return _reveal(
      _promiseStart + 0.06,
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.onDone,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Get started'),
          ),
        ),
      ),
      window: 0.10,
    );
  }
}
