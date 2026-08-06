import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The Revolution brandmark — a custom orbit motif: a bold ring with a bright
/// "comet" node sweeping around it, over a deep gradient badge. Drawn in code so
/// it's razor-sharp at any size and feels designed, not defaulted.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final r = size * 0.30;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6FB1FF), Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.40),
            blurRadius: size * 0.36,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft top-light for a glassy, dimensional badge.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: 0.26),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: size * 0.62,
              height: size * 0.62,
              child: CustomPaint(painter: _OrbitPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width * 0.40;
    final stroke = size.width * 0.12;

    // The orbit ring, with a gap (an open, dynamic "revolution").
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -math.pi * 0.62, // start
      math.pi * 1.7, // sweep (leaves a clean gap)
      false,
      ring,
    );

    // The comet node riding the ring at the gap's leading edge.
    final a = -math.pi * 0.62 + math.pi * 1.7;
    final nodeC = Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
    canvas.drawCircle(
        nodeC, stroke * 0.95, Paint()..color = Colors.white);
    // A tiny inner dot for a crisp core.
    final core = Paint()..color = const Color(0xFF1D4ED8);
    canvas.drawCircle(nodeC, stroke * 0.42, core);

    // A small centre pip anchors the mark.
    canvas.drawCircle(c, stroke * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_) => false;
}
