import 'package:flutter/material.dart';

/// A custom funnel (filter) icon drawn in code so the proportions — especially
/// a wider, better-balanced bottom stem — can be tuned, which the built-in
/// Material funnel doesn't allow.
class FunnelIcon extends StatelessWidget {
  const FunnelIcon({super.key, this.size = 22, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FunnelPainter(color),
    );
  }
}

class _FunnelPainter extends CustomPainter {
  const _FunnelPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Funnel geometry: a wide top mouth that tapers to a WIDER-than-usual stem.
    final topY = h * 0.16;
    final taperY = h * 0.52; // where the bowl meets the stem
    final bottomY = h * 0.86;

    final leftTop = w * 0.12;
    final rightTop = w * 0.88;

    // A comfortably wide stem (the part that used to look too thin/dark).
    final stemHalf = w * 0.15;
    final cx = w / 2;

    final path = Path()
      ..moveTo(leftTop, topY)
      ..lineTo(rightTop, topY)
      // right side of the bowl down to the stem's right edge
      ..lineTo(cx + stemHalf, taperY)
      // stem right edge down, with a softly rounded foot
      ..lineTo(cx + stemHalf, bottomY - stemHalf)
      ..quadraticBezierTo(
          cx + stemHalf, bottomY, cx + stemHalf * 0.35, bottomY)
      ..lineTo(cx - stemHalf * 0.35, bottomY)
      ..quadraticBezierTo(
          cx - stemHalf, bottomY, cx - stemHalf, bottomY - stemHalf)
      // stem left edge back up to the bowl
      ..lineTo(cx - stemHalf, taperY)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FunnelPainter old) => old.color != color;
}
