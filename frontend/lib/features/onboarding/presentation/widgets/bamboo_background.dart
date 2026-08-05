import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';

/// The warm, cozy backdrop shared by every onboarding screen — a cream world
/// with a scatter of soft paw prints drifting in the corners. (Class name kept
/// as [BambooBackground] for stability; the art is now the dog/cream theme.)
///
/// Everything is low-contrast so it never competes with the content.
class BambooBackground extends StatelessWidget {
  const BambooBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Bamboo.mist, Bamboo.cream, Bamboo.creamHi],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _PawPainter(),
        child: child,
      ),
    );
  }
}

class _PawPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // A scatter of soft paw prints (fixed positions — no RNG so it renders
    // identically every frame and in tests). [x, y, scale, rotation].
    const paws = [
      [0.14, 0.10, 1.0, 0.4],
      [0.86, 0.16, 0.8, -0.6],
      [0.10, 0.82, 1.1, 1.0],
      [0.90, 0.88, 0.9, -0.3],
      [0.78, 0.06, 0.7, 0.8],
      [0.22, 0.50, 0.6, -0.2],
    ];
    for (final p in paws) {
      _paw(canvas, Offset(w * p[0], h * p[1]), w * 0.05 * p[2], p[3]);
    }
  }

  /// One paw print: a main pad + four toe beans.
  void _paw(Canvas canvas, Offset center, double r, double rot) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    final paint = Paint()..color = Bamboo.greenDeep.withValues(alpha: 0.08);

    // Main pad — a rounded heart-ish oval.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.55), width: r * 1.4, height: r * 1.2),
      paint,
    );
    // Four toe beans arcing over the pad.
    const toes = [
      [-0.85, -0.55, 0.42],
      [-0.30, -0.95, 0.40],
      [0.30, -0.95, 0.40],
      [0.85, -0.55, 0.42],
    ];
    for (final t in toes) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(r * t[0], r * t[1]),
          width: r * t[2] * 2,
          height: r * t[2] * 2.3,
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
