import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's deep-space backdrop: a still constellation of tiny stars, each
/// twinkling on its own slow rhythm.
///
/// This is the single starfield primitive — every onboarding/auth screen paints
/// the SAME sky behind its content, so moving between pages feels like moving
/// through one continuous space rather than swapping backgrounds.
///
/// Wrap a screen's body in it:
/// ```dart
/// Starfield(child: myContent)
/// ```
/// The stars are seeded, so they never jump between frames or rebuilds, and
/// the whole field is painted in a single [CustomPaint] — no per-star widgets.
class Starfield extends StatefulWidget {
  const Starfield({
    super.key,
    this.child,
    this.starCount = 90,
    this.seed = 7,
    this.intensity = 1.0,
  });

  /// Painted on top of the sky.
  final Widget? child;

  /// How many stars to scatter.
  final int starCount;

  /// Changing this gives a different (but still stable) constellation.
  final int seed;

  /// Overall brightness multiplier — dial down behind busy content.
  final double intensity;

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    // One slow, endless cycle — each star's own speed multiplies this, so the
    // twinkles never march in lockstep.
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => CustomPaint(
              painter: StarfieldPainter(
                t: _clock.value,
                stars: StarfieldPainter.starsFor(widget.starCount, widget.seed),
                intensity: widget.intensity,
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Paints a [Star] list at time [t] (0..1 of one cycle). Exposed so screens
/// that already run their own animation clock (e.g. the intro's orbits) can
/// drive the same sky without spinning up a second controller.
class StarfieldPainter extends CustomPainter {
  const StarfieldPainter({
    required this.t,
    required this.stars,
    this.intensity = 1.0,
  });

  final double t;
  final List<Star> stars;
  final double intensity;

  /// Seeded constellations, cached per (count, seed) so repeated builds and
  /// separate screens reuse one list instead of regenerating it.
  static final Map<(int, int), List<Star>> _cache = {};

  static List<Star> starsFor(int count, int seed) {
    return _cache.putIfAbsent((count, seed), () {
      final rnd = math.Random(seed);
      return List.generate(count, (_) {
        return Star(
          x: rnd.nextDouble(),
          y: rnd.nextDouble(),
          r: 0.6 + rnd.nextDouble() * 1.4,
          phase: rnd.nextDouble() * 2 * math.pi,
          speed: 2 + rnd.nextDouble() * 6,
          violet: rnd.nextDouble() < 0.4,
        );
      });
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final twinkle = 0.5 + 0.5 * math.sin(t * 2 * math.pi * s.speed + s.phase);
      final alpha = ((0.08 + 0.30 * twinkle) * intensity).clamp(0.0, 1.0);
      paint.color = (s.violet ? const Color(0xFF9F7BFF) : Colors.white)
          .withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter old) =>
      old.t != t || old.intensity != intensity || old.stars != stars;
}

/// One star: unit position, radius, twinkle phase/speed, and tint.
class Star {
  const Star({
    required this.x,
    required this.y,
    required this.r,
    required this.phase,
    required this.speed,
    required this.violet,
  });

  final double x, y, r, phase, speed;
  final bool violet;
}
