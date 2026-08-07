import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Revo — the app's mascot. A perfect white circle with one small triangular
/// point on the right, big black eyes, and an iridescent pastel wash (pink →
/// mint → periwinkle) across its lower body, wrapped in a gentle lavender glow.
///
/// Drawn entirely in code (no image asset), so every part of it is a live
/// animation handle:
///   [blink]  0 → eyes open, 1 → eyes shut
///   [look]   where the eyes point, each axis −1..1
///   [squash] cartoon squash-and-stretch, −1..1 (positive = wider + shorter)
///   [tilt]   head tilt in radians
///
/// Use [Mascot] for a still pose you drive yourself, or [AnimatedMascot] for
/// the self-contained idle loop (breathing bob, wandering gaze, double-blinks)
/// used across the app.
class Mascot extends StatelessWidget {
  const Mascot({
    super.key,
    required this.size,
    this.blink = 0,
    this.look = Offset.zero,
    this.squash = 0,
    this.tilt = 0,
    this.glow = true,
  });

  final double size;
  final double blink;
  final Offset look;
  final double squash;
  final double tilt;

  /// The soft lavender halo. Turn off on busy backgrounds.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MascotPainter(
          blink: blink,
          look: look,
          squash: squash,
          tilt: tilt,
          glow: glow,
        ),
      ),
    );
  }
}

/// Revo's idle life: a slow breathing bob with matching squash, a gaze that
/// wanders, and the occasional quick double-blink. Drop it anywhere.
class AnimatedMascot extends StatefulWidget {
  const AnimatedMascot({super.key, required this.size, this.glow = true});

  final double size;
  final bool glow;

  @override
  State<AnimatedMascot> createState() => _AnimatedMascotState();
}

class _AnimatedMascotState extends State<AnimatedMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    // One loop carries everything; blink moments are fixed points inside it,
    // spaced unevenly so the rhythm never reads as mechanical.
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  /// A quick eye-close spike centred at loop-time [at].
  static double _blinkSpike(double t, double at) {
    final d = (t - at).abs();
    return d > 0.022 ? 0 : 1 - (d / 0.022);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (context, _) {
        final t = _idle.value;
        final breath = math.sin(t * 2 * math.pi);
        final blink = (_blinkSpike(t, 0.36) +
                _blinkSpike(t, 0.43) + // the double-blink
                _blinkSpike(t, 0.82))
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, breath * widget.size * 0.03),
          child: Mascot(
            size: widget.size,
            blink: blink,
            // Gaze rests toward the LEFT to counterbalance the tail at the
            // bottom-right — the eyes lean away from the point, which reads as
            // deliberate and balanced. The wander happens around that offset.
            look: Offset(
              -0.42 + math.sin(t * 2 * math.pi + 1.2) * 0.22,
              math.cos(t * 4 * math.pi + 0.4) * 0.15,
            ),
            squash: breath * 0.05,
            tilt: math.sin(t * 2 * math.pi + 2.1) * 0.03,
            glow: widget.glow,
          ),
        );
      },
    );
  }
}

// ── The drawing ──────────────────────────────────────────────────────────────

class _MascotPainter extends CustomPainter {
  const _MascotPainter({
    required this.blink,
    required this.look,
    required this.squash,
    required this.tilt,
    required this.glow,
  });

  final double blink;
  final Offset look;
  final double squash;
  final double tilt;
  final bool glow;

  // The image's palette: white body, pink / mint / periwinkle wash, lavender
  // glow, near-black eyes.
  static const _pink = Color(0xFFF7A8D8);
  static const _mint = Color(0xFF7FE8DA);
  static const _periwinkle = Color(0xFFA5B4FC);
  static const _lavender = Color(0xFFC4B5FD);
  static const _eye = Color(0xFF16181C);

  /// A perfect circle with one small triangular point at the bottom-right.
  ///
  /// We trace the full circle as an arc, but interrupt it over a short span on
  /// the bottom-right diagonal: instead of following the arc between two tangent
  /// angles, we run out to a (slightly rounded) tip along the 45° diagonal and
  /// back. Because the break points sit on the circle and the tip lies on the
  /// diagonal through the centre, the point reads as a natural tail growing out
  /// of an otherwise flawless round body — pulling the eye down-right.
  static Path _buildBody(double s) {
    final r = s * 0.40; // the head's radius — a true circle

    // The point is centred on the bottom-right diagonal (45° down from +x).
    const centre = math.pi / 4; // 45° → bottom-right corner
    const half = 0.32; // half-angle of the notch (radians) → base height

    // The two points where the point meets the circle, straddling the diagonal.
    final top = Offset(
      r * math.cos(centre - half),
      r * math.sin(centre - half),
    );
    final bot = Offset(
      r * math.cos(centre + half),
      r * math.sin(centre + half),
    );

    // The tip juts out along the diagonal, past the circle's edge.
    final reach = r + s * 0.12;
    final tip = Offset(reach * math.cos(centre), reach * math.sin(centre));

    // Two control shoulders just shy of the tip, offset perpendicular to the
    // diagonal, round the apex into a soft point rather than a needle.
    final nx = math.cos(centre), ny = math.sin(centre); // diagonal unit
    final px = -ny, py = nx; // perpendicular unit
    final back = Offset(tip.dx - nx * s * 0.02, tip.dy - ny * s * 0.02);
    final tipA = Offset(back.dx - px * s * 0.03, back.dy - py * s * 0.03);
    final tipB = Offset(back.dx + px * s * 0.03, back.dy + py * s * 0.03);

    return Path()
      // Start at the leading break point and sweep the long way around the
      // circle (counter-clockwise, the whole body) to the trailing break point.
      ..moveTo(top.dx, top.dy)
      ..arcToPoint(
        bot,
        radius: Radius.circular(r),
        clockwise: false,
        largeArc: true,
      )
      // Now the point: trailing break → rounded tip → leading break.
      ..lineTo(tipB.dx, tipB.dy)
      ..quadraticBezierTo(tip.dx, tip.dy, tipA.dx, tipA.dy)
      ..lineTo(top.dx, top.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.scale(1 + squash * 0.5, 1 - squash * 0.5);

    // Grounding contact shadow, so it floats over any surface.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.46),
        width: s * 0.44,
        height: s * 0.08,
      ),
      Paint()
        ..color = const Color(0x14000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );

    // The body: a PERFECT circle with one small, crisp triangular point on the
    // right — a clean, deliberate shape, not a wobbly cutout. The triangle is
    // spliced tangentially into the circle so the outline flows smoothly into
    // it and back out; its tip is softened by a hair so it reads as friendly,
    // not a sharp spike.
    final body = _buildBody(s);

    if (glow) {
      canvas.drawPath(
        body,
        Paint()
          ..color = _lavender.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.07),
      );
    }

    // White base…
    canvas.drawPath(body, Paint()..color = Colors.white);

    // …then the iridescent wash: three soft colour pools blurred into each
    // other across the lower body, clipped inside the blob. The top stays
    // white, exactly like the reference.
    canvas.save();
    canvas.clipPath(body);
    final wash = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.11);
    // Colour pools sit across the LOWER half of the circle (centre at origin,
    // radius ~0.40s) so the iridescent wash fills the bottom and the crown
    // stays white — matching the reference.
    wash.color = _pink.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(-s * 0.20, s * 0.20), s * 0.28, wash);
    wash.color = _mint.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(s * 0.03, s * 0.28), s * 0.28, wash);
    wash.color = _periwinkle.withValues(alpha: 0.80);
    canvas.drawCircle(Offset(s * 0.26, s * 0.12), s * 0.26, wash);
    // A whisper of lavender along the crown keeps the white from going flat.
    wash.color = _lavender.withValues(alpha: 0.30);
    canvas.drawCircle(Offset(s * 0.16, -s * 0.26), s * 0.20, wash);
    canvas.restore();

    // The eyes: two big black ovals. They travel with [look] and shut to a
    // sliver as [blink] rises — everything a face needs, nothing more.
    final eyePaint = Paint()..color = _eye;
    final open = (1 - blink * 0.94).clamp(0.06, 1.0);
    // A wider horizontal travel so a left-leaning gaze reads clearly (the tail
    // sits bottom-right, so the eyes look the other way).
    final eyeOffset = Offset(look.dx * s * 0.075, look.dy * s * 0.040);
    for (final dx in [-s * 0.125, s * 0.125]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dx, -s * 0.16 + blink * s * 0.02) + eyeOffset,
          width: s * 0.110,
          height: s * 0.195 * open,
        ),
        eyePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.blink != blink ||
      old.look != look ||
      old.squash != squash ||
      old.tilt != tilt ||
      old.glow != glow;
}
