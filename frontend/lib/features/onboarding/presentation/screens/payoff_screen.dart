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
///   2. A speech bubble pops above it: "That's [31] things to remember
///      already…" — the number climbing live while Revo watches it stack up.
///      "already" is deliberate: it implies the count is only going to grow.
///   3. A beat. Then, inside the SAME bubble, the turn fades in: "But don't
///      worry — Revo's got you." and Revo does a happy double-hop, gaze
///      dropping from the number to YOU.
///   4. The story rests. Then, in the quiet aftermath, one muted closing line
///      fades in — a pause — and only then does the "Get started" CTA arrive,
///      each beat given room to breathe.
///
/// A single chat-style bubble (no comic tail) keeps it modern; the story
/// structure — problem, beat, hero — is carried purely by timing and Revo's
/// body language.
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

  /// The quiet aftermath, played only AFTER the story finishes: a pause, then
  /// the closing line fades in, another pause, then the "Get started" CTA. This
  /// lives on its own controller so each beat can breathe — the story sinks in
  /// first, then the proof, then the invitation to begin.
  late final AnimationController _tail;

  // Story beats (fractions of [_c]). The gap between the count settling and
  // bubble 2 is deliberate — the pause IS the "uh oh…" beat.
  static const _revoStart = 0.00;
  static const _bubble1Start = 0.16;
  static const _countStart = 0.24;
  static const _countEnd = 0.50;
  // A long, deliberate pause here — 0.50 → 0.66 — is the beat that lets the
  // number sink in before the reassurance turns the story.
  static const _bubble2Start = 0.66;
  static const _bubble2Window = 0.28;
  static const _hopStart = 0.66;
  static const _hopEnd = 0.86;
  // The story controller ends here; the closing line and CTA are handled
  // separately by the aftermath controller [_tail] (see below) so each gets its
  // own pause after the story, rather than being crammed into this timeline.

  // ── Aftermath beats (fractions of [_tail], which runs after the story) ──────
  // The two elements land one at a time with the SAME short interval between
  // them: story → (gap) → closing line → (same gap) → CTA. The gap equals
  // [_tailStep]; each reveal starts one step later than the last.
  static const _tailDuration = Duration(milliseconds: 2000);
  static const _tailLeadIn = 0.16; // the gap the story rests before beat 1
  static const _tailStep = 0.34; // the single, consistent interval thereafter
  static const _promiseTailStart = _tailLeadIn; //              0.16 — line
  static const _ctaTailStart = _tailLeadIn + _tailStep; //      0.50 — CTA
  static const _tailWindow = 0.22;

  int _total = 0;

  @override
  void initState() {
    super.initState();
    _total = _countReminders();
    _tail = AnimationController(vsync: this, duration: _tailDuration);
    _c = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener(_onStoryStatus)
      ..forward();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  /// When the story finishes, kick off the aftermath from the top.
  void _onStoryStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _tail.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant PayoffScreen old) {
    super.didUpdateWidget(old);
    // The parent rebuilds when the user lands here (and when picks change) —
    // recompute and replay so arriving always plays the story from the top.
    _total = _countReminders();
    _tail.reset();
    _c
      ..duration = _duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.removeStatusListener(_onStoryStatus);
    _c.dispose();
    _idle.dispose();
    _tail.dispose();
    super.dispose();
  }

  /// A touch more time for bigger years, so the climb stays readable, and a
  /// long, unhurried tail so the whole story sinks in — the count climbs
  /// slowly, then a real pause, then the reassurance fades in gently.
  Duration get _duration =>
      Duration(milliseconds: (5200 + _total * 6).clamp(5200, 7000));

  /// How many times a year one picked chip fires.
  static int _firesPerYear(RepeatCadence f) => switch (f) {
        RepeatCadence.minute => 365 * 24 * 60,
        RepeatCadence.hour => 365 * 24,
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

  /// Fade + slide-up reveal, driven by the aftermath controller [_tail] so the
  /// closing line and CTA each get their own unhurried beat once the story ends.
  Widget _tailReveal(double start, double window, Widget child) {
    final raw = ((_tail.value - start) / window).clamp(0.0, 1.0);
    final t = Curves.easeOutCubic.transform(raw);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Split by clock so the ENDLESS idle loop only rebuilds Revo — not the
    // static Column, the text bubble, or the button. Each piece listens to
    // exactly the controllers it animates:
    //   • bubble + paragraph → the story clock (_c), a one-shot
    //   • Revo              → story + idle (_c, _idle) — idle is the perpetual one
    //   • closing line/CTA  → the aftermath clock (_tail), a one-shot
    // Once _c and _tail finish, only Revo's subtree repaints on _idle's ticks.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 5),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _bubble(
              start: _bubble1Start,
              child: _storyParagraph(),
            ),
          ),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: Listenable.merge([_c, _idle]),
            builder: (context, _) => _revo(),
          ),
          const Spacer(flex: 3),
          AnimatedBuilder(
            animation: _tail,
            builder: (context, _) => _promise(),
          ),
          const SizedBox(height: 22),
          if (widget.onDone != null)
            AnimatedBuilder(
              animation: _tail,
              builder: (context, _) => _getStarted(),
            ),
          const Spacer(flex: 2),
        ],
      ),
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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

  /// The whole story as ONE continuous, left-aligned paragraph. The number
  /// climbs live and settles with a tiny pop; the reassurance clause is part of
  /// the same sentence and simply continues on — it just fades up on its own
  /// beat (its ink and accent both easing in from transparent) so the story
  /// still lands in two moments, but reads as one flowing block of text.
  Widget _storyParagraph() {
    final settle = _lin(_countEnd, 0.10);
    final pop = math.sin(settle * math.pi) * 0.06;

    // Reassurance clause reveal — a slow, deliberate fade so the reassurance
    // arrives in one calm go. The wide window (0.55 of the timeline) is what
    // keeps it unhurried.
    final reveal = Curves.easeOutCubic.transform(_lin(_bubble2Start, _bubble2Window));
    final ink = AppColors.ink.withValues(alpha: reveal);
    final accent = AppColors.accent.withValues(alpha: reveal);

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
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: AppColors.accent,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const TextSpan(text: ' things to remember already…'),
          // The turn of the story — same paragraph, same size, fading in
          // slowly on its own beat.
          TextSpan(
            text: "\nBut don't worry — ",
            style: TextStyle(color: ink),
          ),
          TextSpan(
            text: "Revo's got you.",
            style: TextStyle(fontWeight: FontWeight.w900, color: accent),
          ),
        ],
      ),
      textAlign: TextAlign.left,
      style: const TextStyle(
        fontSize: 24,
        height: 1.4,
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
    return _tailReveal(
      _promiseTailStart,
      _tailWindow,
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
    );
  }

  /// The "Get started" CTA — the final beat, landing after its own pause once
  /// the closing line has settled. Full-width to match the app's primary
  /// buttons.
  Widget _getStarted() {
    return _tailReveal(
      _ctaTailStart,
      _tailWindow,
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.onDone,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            // Leads into the schedule step (day + how often), not the app yet.
            child: Text('Set my reminders'),
          ),
        ),
      ),
    );
  }
}
