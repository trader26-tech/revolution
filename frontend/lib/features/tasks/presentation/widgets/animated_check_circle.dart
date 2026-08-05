import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A delightfully animated check circle for marking a task done.
///
/// Tapping animates: the ring fills with accent colour, a checkmark draws
/// itself stroke-by-stroke inside, and the whole thing gives a soft bounce.
/// Un-checking reverses it. All drawn in a single [CustomPainter] so it stays
/// crisp at any size.
class AnimatedCheckCircle extends StatefulWidget {
  const AnimatedCheckCircle({
    super.key,
    required this.checked,
    required this.onTap,
    this.size = 26,
  });

  final bool checked;
  final VoidCallback onTap;
  final double size;

  @override
  State<AnimatedCheckCircle> createState() => _AnimatedCheckCircleState();
}

class _AnimatedCheckCircleState extends State<AnimatedCheckCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: widget.checked ? 1 : 0,
  );

  // Fill grows first, then the tick draws, with a springy scale pop on top.
  late final Animation<double> _fill = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tick = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
  );
  // The radial burst: short rays fire outward and fade as the check completes
  // (0 → nothing, 1 → rays at full reach + faded). Fires only near the end.
  late final Animation<double> _burst = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
  );
  // A gentle overshoot bump that peaks mid-animation, giving a satisfying pop
  // without a lingering wobble.
  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45),
    TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55),
  ]).animate(_c);

  @override
  void didUpdateWidget(AnimatedCheckCircle old) {
    super.didUpdateWidget(old);
    if (widget.checked != old.checked) {
      widget.checked ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      // A little breathing room so the tap target stays comfortable.
      child: Padding(
        padding: const EdgeInsets.all(2),
        // The layout footprint stays `size`; the painter's canvas is larger so
        // the burst can spill outside the ring. OverflowBox lets it paint beyond
        // the box without pushing the row's other content around.
        child: SizedBox.square(
          dimension: widget.size,
          child: OverflowBox(
            maxWidth: widget.size * 1.9,
            maxHeight: widget.size * 1.9,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Transform.scale(
                  scale: _pop.value,
                  child: CustomPaint(
                    size: Size.square(widget.size * 1.9),
                    painter: _CheckPainter(
                      fill: _fill.value,
                      tick: _tick.value,
                      burst: _burst.value,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.fill, required this.tick, required this.burst});

  /// 0 → empty ring, 1 → fully filled accent disc.
  final double fill;

  /// 0 → no tick, 1 → fully drawn checkmark.
  final double tick;

  /// 0 → no burst, 1 → rays fully extended and faded out.
  final double burst;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // The ring itself occupies the inner ~52% of the oversized canvas, leaving
    // room around it for the burst rays.
    final radius = size.width * 0.263;
    final stroke = radius * 2 * 0.09;

    // The radial burst — short rays firing outward, fading as they reach full
    // extent. Drawn first (behind the disc) so the circle stays crisp on top.
    if (burst > 0 && burst < 1) {
      const rayCount = 8;
      final opacity = (1 - burst); // fade out as they travel
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.7
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: opacity * 0.9);
      final inner = radius * (1.15 + burst * 0.35);
      final outer = radius * (1.25 + burst * 0.85);
      for (var i = 0; i < rayCount; i++) {
        final a = (i / rayCount) * 2 * 3.1415926;
        final dx = math.cos(a), dy = math.sin(a);
        canvas.drawLine(
          center + Offset(dx * inner, dy * inner),
          center + Offset(dx * outer, dy * outer),
          rayPaint,
        );
      }
    }

    // 1) The empty ring — greys when unchecked, tints toward accent as it fills.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Color.lerp(AppColors.inkFaint, AppColors.accent, fill)!;
    canvas.drawCircle(center, radius - stroke / 2, ringPaint);

    // 2) The accent disc grows from the centre.
    if (fill > 0) {
      final discPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentDeep],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, (radius - stroke / 2) * fill, discPaint);
    }

    // 3) The checkmark draws itself along its path.
    if (tick > 0) {
      final p1 = Offset(size.width * 0.28, size.height * 0.52);
      final p2 = Offset(size.width * 0.44, size.height * 0.66);
      final p3 = Offset(size.width * 0.73, size.height * 0.36);

      final path = Path()..moveTo(p1.dx, p1.dy);
      // Two segments; draw them proportionally to `tick` for a live stroke.
      final seg1 = (p2 - p1).distance;
      final seg2 = (p3 - p2).distance;
      final total = seg1 + seg2;
      final drawLen = total * tick;

      if (drawLen <= seg1) {
        final t = drawLen / seg1;
        path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final t = ((drawLen - seg1) / seg2).clamp(0.0, 1.0);
        path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
      }

      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.15
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white;
      canvas.drawPath(path, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.fill != fill || old.tick != tick || old.burst != burst;
}
