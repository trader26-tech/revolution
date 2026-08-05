import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small, hand-painted flame that gently flickers. Fully vector (no emoji,
/// no assets) so it renders identically on iOS and Android and scales crisply.
///
/// Pass [lit] = false for a "cold" grey flame when the streak is broken.
class AnimatedFlame extends StatefulWidget {
  const AnimatedFlame({super.key, this.size = 22, this.lit = true});

  final double size;
  final bool lit;

  @override
  State<AnimatedFlame> createState() => _AnimatedFlameState();
}

class _AnimatedFlameState extends State<AnimatedFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.25,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _FlamePainter(t: _c.value, lit: widget.lit),
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.t, required this.lit});

  /// 0..1 loop phase.
  final double t;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Flicker: a subtle horizontal sway + vertical stretch on a sine loop.
    final phase = t * 2 * math.pi;
    final sway = math.sin(phase) * w * 0.05;
    final stretch = 1 + math.sin(phase * 1.3) * 0.06;

    Path flame(double scale) {
      final cx = w / 2 + sway * scale;
      final top = h * (0.06 / stretch);
      final bottom = h * 0.98;
      final width = w * 0.42 * scale;
      return Path()
        ..moveTo(cx, top)
        // right side down to the rounded base
        ..cubicTo(cx + width, h * 0.34, cx + width, h * 0.72, cx, bottom)
        // left side back up
        ..cubicTo(cx - width, h * 0.72, cx - width, h * 0.34, cx, top)
        ..close();
    }

    if (lit) {
      // Outer warm flame.
      canvas.drawPath(
        flame(1.0),
        Paint()..color = const Color(0xFFFF9F1C),
      );
      // Inner brighter core.
      canvas.drawPath(
        flame(0.58),
        Paint()..color = const Color(0xFFFFD166),
      );
    } else {
      // Cold / broken streak — muted grey flame.
      canvas.drawPath(flame(1.0), Paint()..color = const Color(0xFFBDB6AC));
      canvas.drawPath(flame(0.58), Paint()..color = const Color(0xFFD9D3C8));
    }
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) =>
      old.t != t || old.lit != lit;
}
