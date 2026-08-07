import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Revo — the app's mascot. A soft white blob with big black eyes and an
/// iridescent pastel wash (pink → mint → periwinkle) across its lower body,
/// wrapped in a gentle lavender glow.
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
            look: Offset(
              math.sin(t * 2 * math.pi + 1.2) * 0.35,
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

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.scale(1 + squash * 0.5, 1 - squash * 0.5);

    // Grounding contact shadow, so it floats over any surface.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.44),
        width: s * 0.56,
        height: s * 0.10,
      ),
      Paint()
        ..color = const Color(0x14000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );

    // The body: a blob just off-circular — a touch wider than tall, fuller at
    // the bottom, like a settled water drop.
    final body = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(0, s * 0.02),
          width: s * 0.90,
          height: s * 0.82,
        ),
      );

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
    wash.color = _pink.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(-s * 0.24, s * 0.26), s * 0.30, wash);
    wash.color = _mint.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(s * 0.02, s * 0.34), s * 0.30, wash);
    wash.color = _periwinkle.withValues(alpha: 0.80);
    canvas.drawCircle(Offset(s * 0.28, s * 0.16), s * 0.28, wash);
    // A whisper of lavender along the crown keeps the white from going flat.
    wash.color = _lavender.withValues(alpha: 0.30);
    canvas.drawCircle(Offset(s * 0.18, -s * 0.28), s * 0.22, wash);
    canvas.restore();

    // The eyes: two big black ovals. They travel with [look] and shut to a
    // sliver as [blink] rises — everything a face needs, nothing more.
    final eyePaint = Paint()..color = _eye;
    final open = (1 - blink * 0.94).clamp(0.06, 1.0);
    final eyeOffset = Offset(look.dx * s * 0.045, look.dy * s * 0.035);
    for (final dx in [-s * 0.115, s * 0.115]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dx, -s * 0.10 + blink * s * 0.02) + eyeOffset,
          width: s * 0.105,
          height: s * 0.185 * open,
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
