import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// An animated check circle for marking a task done, matching the reference:
///
///   1. the accent fill RISES from the bottom to the top of the ring (like the
///      circle filling with liquid),
///   2. once full, a subtle, slightly-slanted burst flashes around it,
///   3. then a short, clean white tick draws itself — sized to sit comfortably
///      inside the circle, never overflowing.
///
/// Un-checking reverses it. Everything is drawn in one [CustomPainter] centred
/// in an oversized canvas so the burst can flash outside the ring without
/// affecting layout.
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
  // How much bigger the paint canvas is than the ring, to give the burst room.
  static const double _canvasScale = 1.7;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: widget.checked ? 1 : 0,
  );

  // Phase 1 — fill rises bottom→up.
  late final Animation<double> _fill = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
  );
  // Phase 2 — the burst flashes right after the fill completes, then fades.
  late final Animation<double> _burst = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.48, 0.82, curve: Curves.easeOut),
  );
  // Phase 3 — the tick draws itself last.
  late final Animation<double> _tick = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
  );
  // A restrained pop — small, so it reads as premium, not bouncy.
  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50),
    TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50),
  ]).animate(CurvedAnimation(
    parent: _c,
    curve: const Interval(0.4, 0.9, curve: Curves.linear),
  ));

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
    final canvas = widget.size * _canvasScale;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        // Layout footprint stays `size`; the painter's canvas is larger so the
        // burst can flash outside the ring without moving other content.
        child: SizedBox.square(
          dimension: widget.size,
          child: OverflowBox(
            maxWidth: canvas,
            maxHeight: canvas,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Transform.scale(
                  scale: _pop.value,
                  child: CustomPaint(
                    size: Size.square(canvas),
                    painter: _CheckPainter(
                      ringDiameter: widget.size,
                      fill: _fill.value,
                      burst: _burst.value,
                      tick: _tick.value,
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
  _CheckPainter({
    required this.ringDiameter,
    required this.fill,
    required this.burst,
    required this.tick,
  });

  /// The actual ring diameter (the painter centres it in the larger canvas).
  final double ringDiameter;

  /// 0 → empty, 1 → filled to the top (rises from the bottom).
  final double fill;

  /// 0 → no burst, 1 → rays fully out and faded.
  final double burst;

  /// 0 → no tick, 1 → fully drawn.
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = ringDiameter / 2;
    final stroke = ringDiameter * 0.085;
    final rInner = radius - stroke / 2;

    // --- 2) burst — behind the disc, subtle + slightly slanted -------------
    if (burst > 0 && burst < 1) {
      const rayCount = 7;
      // Offset the whole spray by a small angle so rays sit slanted, not axis-
      // aligned/straight — matches the reference's off-kilter flash.
      const tilt = 0.32;
      final reach = radius * (0.28 + burst * 0.55); // short rays
      final gap = radius * (0.16 + burst * 0.30);
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.55
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: (1 - burst) * 0.7);
      for (var i = 0; i < rayCount; i++) {
        final a = tilt + (i / rayCount) * 2 * math.pi;
        final dx = math.cos(a), dy = math.sin(a);
        canvas.drawLine(
          center + Offset(dx * (radius + gap), dy * (radius + gap)),
          center + Offset(dx * (radius + gap + reach), dy * (radius + gap + reach)),
          rayPaint,
        );
      }
    }

    // --- 1) ring + rising fill ---------------------------------------------
    // The ring: greys when empty, tints to accent as it fills.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Color.lerp(AppColors.inkFaint, AppColors.accent, fill.clamp(0, 1))!;
    canvas.drawCircle(center, rInner, ringPaint);

    // The accent disc, revealed bottom→up by clipping to a rising rectangle.
    if (fill > 0) {
      canvas.save();
      // A rectangle whose TOP edge rises from the circle's bottom to its top.
      final fillTop = center.dy + rInner - (2 * rInner) * fill;
      canvas.clipRect(Rect.fromLTRB(
        center.dx - rInner,
        fillTop,
        center.dx + rInner,
        center.dy + rInner,
      ));
      final discPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent, AppColors.accentDeep],
        ).createShader(Rect.fromCircle(center: center, radius: rInner));
      canvas.drawCircle(center, rInner, discPaint);
      canvas.restore();
    }

    // --- 3) the tick — short, centred, contained ---------------------------
    if (tick > 0) {
      // A compact check: left-down start, low elbow just below centre, then up
      // to the right. All offsets are fractions of the RADIUS, so the tick is
      // always well inside the circle — never overflowing.
      final a = center + Offset(-radius * 0.34, radius * 0.02); // start (upper-left)
      final b = center + Offset(-radius * 0.06, radius * 0.28); // elbow (low-centre)
      final c = center + Offset(radius * 0.38, -radius * 0.24); // end (upper-right)

      final seg1 = (b - a).distance;
      final seg2 = (c - b).distance;
      final drawn = (seg1 + seg2) * tick;

      final path = Path()..moveTo(a.dx, a.dy);
      if (drawn <= seg1) {
        final t = drawn / seg1;
        path.lineTo(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
      } else {
        path.lineTo(b.dx, b.dy);
        final t = ((drawn - seg1) / seg2).clamp(0.0, 1.0);
        path.lineTo(b.dx + (c.dx - b.dx) * t, b.dy + (c.dy - b.dy) * t);
      }

      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.05
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
