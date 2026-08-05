import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';

/// The calm bamboo backdrop shared by every onboarding screen — our answer to
/// Orbit's starfield, but a warm, natural light world.
///
/// A soft green mist at the top fades into cream paper, a few faint bamboo
/// canes rise along the edges, and scattered leaves drift in the corners.
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
        painter: _BambooPainter(),
        child: child,
      ),
    );
  }
}

class _BambooPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Two faint bamboo canes, one on each side, rising off-screen.
    _cane(canvas, Offset(w * 0.06, h), h * 0.9, w * 0.045);
    _cane(canvas, Offset(w * 0.95, h * 1.02), h * 0.8, w * 0.05);

    // A scatter of soft leaves in the corners (fixed positions — no RNG so it
    // renders identically every frame and in tests).
    const leaves = [
      [0.14, 0.10, 0.5],
      [0.86, 0.16, -0.7],
      [0.10, 0.82, 1.1],
      [0.90, 0.88, -0.3],
      [0.78, 0.06, 0.9],
    ];
    for (final l in leaves) {
      _leaf(canvas, Offset(w * l[0], h * l[1]), w * 0.055, l[2]);
    }
  }

  void _cane(Canvas canvas, Offset base, double length, double width) {
    final paint = Paint()
      ..color = Bamboo.sprout.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final top = base.translate(0, -length);
    canvas.drawLine(base, top, paint);

    // Node rings up the cane.
    final ring = Paint()
      ..color = Bamboo.leaf.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.5;
    for (var i = 1; i <= 4; i++) {
      final y = base.dy - length * (i / 5);
      canvas.drawLine(
        Offset(base.dx - width * 0.7, y),
        Offset(base.dx + width * 0.7, y),
        ring,
      );
    }
  }

  void _leaf(Canvas canvas, Offset center, double r, double rot) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    final path = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r * 0.7, -r * 0.2, 0, r)
      ..quadraticBezierTo(-r * 0.7, -r * 0.2, 0, -r)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Bamboo.leaf.withValues(alpha: 0.14),
    );
    // Center vein.
    canvas.drawLine(
      Offset(0, -r * 0.9),
      Offset(0, r * 0.9),
      Paint()
        ..color = Bamboo.greenDeep.withValues(alpha: 0.10)
        ..strokeWidth = r * 0.05,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
