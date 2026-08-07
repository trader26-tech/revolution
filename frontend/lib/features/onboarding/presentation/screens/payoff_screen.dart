import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_chip_catalog.dart';
import 'chip_select_screen.dart';

/// Screen 3 — the payoff, as one unforgettable number and a sky of dots.
///
/// Every chip the user picked fires on its own clock (Netflix monthly, LIC
/// yearly…). We add up how many times a year they ALL fire and count the
/// total up live — and as the number climbs, a constellation blooms beneath
/// it: one glowing dot per reminder, coloured by the life area it comes from.
/// No pills, no math on screen — you just watch a year's worth of "don't
/// forget" fill the page. Then the landing: don't worry — Revolution has got
/// you covered.
class PayoffScreen extends StatefulWidget {
  const PayoffScreen({super.key, required this.picked});

  final Set<String> picked;

  @override
  State<PayoffScreen> createState() => _PayoffScreenState();
}

class _PayoffScreenState extends State<PayoffScreen>
    with TickerProviderStateMixin {
  /// One-shot timeline: headline → count-up + bloom → settle → promise.
  late final AnimationController _c;

  /// Endless idle loop that keeps the constellation drifting.
  late final AnimationController _float;

  static const _countStart = 0.08;
  static const _countEnd = 0.66;
  static const _promiseStart = 0.80;

  int _total = 0;
  List<_Dot> _dots = const [];

  @override
  void initState() {
    super.initState();
    _rebuildDots();
    _c = AnimationController(vsync: this, duration: _duration)..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant PayoffScreen old) {
    super.didUpdateWidget(old);
    // The parent rebuilds when the user lands on this page (and when picks
    // change) — recompute and replay so arriving always shows the reveal.
    _rebuildDots();
    _c
      ..duration = _duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    _float.dispose();
    super.dispose();
  }

  /// A touch more time for bigger years, so the climb stays readable.
  Duration get _duration =>
      Duration(milliseconds: (1400 + _total * 6).clamp(1400, 3000));

  /// How many times a year one picked chip fires.
  static int _firesPerYear(RepeatCadence f) => switch (f) {
        RepeatCadence.daily => 365,
        RepeatCadence.weekly => 52,
        RepeatCadence.monthly => 12,
        RepeatCadence.yearly => 1,
        RepeatCadence.none => 1,
      };

  /// One dot per reminder-per-year, coloured by its section. Layout jitter is
  /// seeded so the constellation is organic but stable across rebuilds.
  void _rebuildDots() {
    final picked =
        widget.picked.isNotEmpty ? widget.picked : preselectedChipKeys();
    final rnd = math.Random(42);
    final dots = <_Dot>[];
    for (final s in kOnboardingChipSections) {
      for (final item in s.items) {
        if (!picked.contains(item.key)) continue;
        final fires = _firesPerYear(item.defaultFrequency);
        for (var f = 0; f < fires; f++) {
          dots.add(_Dot(
            color: s.color,
            radius: 2.4 + rnd.nextDouble() * 1.7,
            glow: rnd.nextDouble() < 0.16,
            phase: rnd.nextDouble() * 2 * math.pi,
            amp: 1.2 + rnd.nextDouble() * 1.8,
            jitterAngle: (rnd.nextDouble() - 0.5) * 0.9,
            jitterRadius: (rnd.nextDouble() - 0.5) * 0.10,
          ));
        }
      }
    }
    // Shuffle (seeded) so colours mingle instead of arriving in blocks.
    dots.shuffle(math.Random(7));
    _total = dots.length;
    _dots = dots;
  }

  /// The live running count, eased across the count window.
  double get _running {
    final t = ((_c.value - _countStart) / (_countEnd - _countStart))
        .clamp(0.0, 1.0);
    return _total * Curves.easeOutCubic.transform(t);
  }

  /// Fade + slide-up reveal for a slice of the timeline.
  Widget _reveal(double start, Widget child, {double window = 0.20}) {
    final t = Curves.easeOutCubic
        .transform(((_c.value - start) / window).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: Listenable.merge([_c, _float]),
      builder: (context, _) {
        final settle = ((_c.value - _countEnd) / 0.10).clamp(0.0, 1.0);
        return Column(
          children: [
            const Spacer(flex: 2),
            _reveal(
              0.0,
              Text(
                "That's",
                style: text.headlineSmall?.copyWith(color: AppColors.inkSoft),
              ),
            ),
            _bigNumber(_running.round(), settle),
            _reveal(
              0.04,
              Text(
                'deadlines a year,',
                style: text.headlineMedium?.copyWith(color: AppColors.ink),
              ),
            ),
            _reveal(
              0.08,
              const Text(
                'living rent-free in your head.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // The sting: what forgetting actually costs — lands on settle.
            _reveal(
              _countEnd,
              Column(
                children: [
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(text: 'Forgetting them costs people '),
                        TextSpan(
                          text: '₹1,20,000',
                          style: TextStyle(color: AppColors.accentDeep),
                        ),
                        TextSpan(text: ' a year —'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'and Mom never forgets that you forgot.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            // The sky: one dot per reminder, blooming as the number climbs.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _DotSkyPainter(
                    dots: _dots,
                    running: _running,
                    floatT: _float.value,
                    settle: settle,
                  ),
                ),
              ),
            ),
            _promise(),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ── The number — the whole point of the page ───────────────────────────────

  Widget _bigNumber(int value, double settle) {
    // A quick settle-pop the moment the count completes.
    final pop = math.sin(settle * math.pi) * 0.05;
    return SizedBox(
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Soft accent halo so the number glows off the page.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.12),
                  AppColors.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Transform.scale(
            scale: 1 + pop,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.accent, AppColors.accentDeep],
                ).createShader(r),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 116,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -4,
                    height: 1.0,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── The landing: the promise, as plain confident words ─────────────────────

  Widget _promise() {
    final t = Curves.easeOutCubic.transform(
        ((_c.value - _promiseStart) / (1 - _promiseStart)).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - t)),
        child: Column(
          children: [
            const Text(
              'Don’t worry.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Revolution',
                    style: TextStyle(color: AppColors.accentDeep),
                  ),
                  TextSpan(text: ' remembers every single one for you.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One reminder in the sky: its colour, size, sparkle and idle-drift motion.
class _Dot {
  const _Dot({
    required this.color,
    required this.radius,
    required this.glow,
    required this.phase,
    required this.amp,
    required this.jitterAngle,
    required this.jitterRadius,
  });

  final Color color;
  final double radius;

  /// A few dots get a soft halo, so the sky sparkles instead of tiling.
  final bool glow;

  final double phase;
  final double amp;
  final double jitterAngle;
  final double jitterRadius;
}

/// Paints the constellation: dots laid out on a phyllotaxis spiral (sunflower
/// packing — organic, even, no clumps), blooming centre-out as the count
/// climbs, then breathing once on settle and drifting forever after.
class _DotSkyPainter extends CustomPainter {
  _DotSkyPainter({
    required this.dots,
    required this.running,
    required this.floatT,
    required this.settle,
  });

  final List<_Dot> dots;
  final double running;
  final double floatT;
  final double settle;

  static const _goldenAngle = 2.39996;

  @override
  void paint(Canvas canvas, Size size) {
    if (dots.isEmpty || size.isEmpty) return;
    final center = size.center(Offset.zero);
    final rx = size.width * 0.46;
    final ry = size.height * 0.46;
    // One collective breath the moment the count lands.
    final breathe = 1 + math.sin(settle * math.pi) * 0.04;
    final paint = Paint();

    for (var i = 0; i < dots.length; i++) {
      // Dot i exists once the running count has passed it; it pops over the
      // next ~3 counts so arrivals overlap into a continuous bloom.
      final t = ((running - i) / 3).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final d = dots[i];
      final pop = Curves.easeOutBack.transform(t);

      final f = math.sqrt((i + 0.5) / dots.length) + d.jitterRadius;
      final angle = i * _goldenAngle + d.jitterAngle;
      final bob = Offset(
        math.sin(floatT * 2 * math.pi + d.phase) * d.amp,
        math.cos(floatT * 2 * math.pi + d.phase * 1.3) * d.amp * 0.8,
      );
      final pos = center +
          Offset(
            rx * f * math.cos(angle) * breathe,
            ry * f * math.sin(angle) * breathe,
          ) +
          bob;

      if (d.glow) {
        paint.color = d.color.withValues(alpha: 0.16 * t);
        canvas.drawCircle(pos, d.radius * pop * 2.8, paint);
      }
      paint.color = d.color.withValues(alpha: 0.92 * t);
      canvas.drawCircle(pos, d.radius * pop, paint);
    }
  }

  @override
  bool shouldRepaint(_DotSkyPainter old) =>
      old.running != running ||
      old.floatT != floatT ||
      old.settle != settle ||
      old.dots != dots;
}
