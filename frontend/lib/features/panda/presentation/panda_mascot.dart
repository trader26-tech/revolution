import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pip — the app's chubby, bubbly panda mascot.
///
/// Fully hand-drawn with a [CustomPainter], so there are **no image assets**
/// to load and it stays razor-sharp at any size / DPI. Every animation is
/// driven by [AnimationController]s and repainting is confined to a
/// [RepaintBoundary], so the surrounding UI never re-lays-out while Pip is
/// breathing, bobbing, and blinking — the paint runs on the GPU raster thread.
///
/// Pip has a small set of moods that map to reminder state:
///  * [PandaMood.happy]   — nothing due, chilled out.
///  * [PandaMood.excited] — a reminder is coming up soon (bouncy, sparkly).
///  * [PandaMood.sleepy]  — all caught up / quiet hours.
enum PandaMood { happy, excited, sleepy }

class PandaMascot extends StatefulWidget {
  const PandaMascot({
    super.key,
    this.size = 220,
    this.mood = PandaMood.happy,
    this.onTap,
  });

  /// Rendered width of the panda in logical pixels. Height follows the
  /// intrinsic aspect ratio so Pip is never squished.
  final double size;

  /// Drives the idle personality (see [PandaMood]).
  final PandaMood mood;

  /// Optional tap handler — gives Pip a springy squish when poked.
  final VoidCallback? onTap;

  @override
  State<PandaMascot> createState() => _PandaMascotState();
}

class _PandaMascotState extends State<PandaMascot>
    with TickerProviderStateMixin {
  // Slow, always-on "breathing" + gentle vertical bob.
  late final AnimationController _idle;
  // Blink is a separate short controller so it never fights the idle loop.
  late final AnimationController _blink;
  // Springy squish when tapped.
  late final AnimationController _poke;

  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _poke = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      lowerBound: 0,
      upperBound: 1,
    );

    _scheduleBlink();
  }

  /// Blink at pseudo-random intervals so Pip feels alive, not robotic.
  void _scheduleBlink() {
    final ms = 2200 + _rng.nextInt(2600);
    Future.delayed(Duration(milliseconds: ms), () async {
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
      // Occasional quick double-blink for extra charm.
      if (mounted && _rng.nextDouble() < 0.25) {
        await _blink.forward();
        await _blink.reverse();
      }
      _scheduleBlink();
    });
  }

  void _handleTap() {
    widget.onTap?.call();
    _poke
      ..stop()
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _blink.dispose();
    _poke.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.size * 1.14; // slightly taller than wide = chubby.
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: height,
          // A single Listenable driving one painter keeps the tree flat and
          // avoids rebuilding widgets — only the painter's paint() re-runs.
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _blink, _poke]),
            builder: (context, _) {
              return CustomPaint(
                painter: _PandaPainter(
                  idle: _idle.value,
                  blink: _blink.value,
                  poke: Curves.elasticOut.transform(_poke.value),
                  mood: widget.mood,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PandaPainter extends CustomPainter {
  _PandaPainter({
    required this.idle,
    required this.blink,
    required this.poke,
    required this.mood,
  });

  /// 0..1, ping-ponging — breathing / bob phase.
  final double idle;

  /// 0..1 — eyes closing amount.
  final double blink;

  /// 0..1 (elastic) — tap squish impulse, decays to 0.
  final double poke;

  final PandaMood mood;

  // ---- Palette --------------------------------------------------------------
  static const _furWhite = Color(0xFFFDFDFF);
  static const _furShadow = Color(0xFFE7E9F2);
  static const _black = Color(0xFF2B2B33);
  static const _blackSoft = Color(0xFF3A3A45);
  static const _blush = Color(0xFFFFB4C6);
  static const _happyGreen = Color(0xFF7CD9A6);
  static const _excitedYellow = Color(0xFFFFD466);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ---- Animation-derived transforms --------------------------------------
    final bob = math.sin(idle * math.pi) * (h * 0.018); // vertical bob
    final breathe = 1 + math.sin(idle * math.pi) * 0.02; // subtle in/out scale
    final excitedBounce = mood == PandaMood.excited
        ? math.sin(idle * math.pi * 2) * (h * 0.02)
        : 0.0;

    // Poke squish: wider + shorter briefly, then springs back (elasticOut).
    final squishX = 1 + poke * 0.08;
    final squishY = 1 - poke * 0.08;

    canvas.save();
    // Move origin to the panda's center, apply bob then squish + breathe.
    canvas.translate(w / 2, h / 2 + bob - excitedBounce);
    canvas.scale(squishX * breathe, squishY * breathe);
    canvas.translate(-w / 2, -h / 2);

    // Contact shadow on the "ground" grounds Pip so he isn't floating.
    _drawGroundShadow(canvas, w, h, bob + excitedBounce);

    // Geometry anchors (all relative to size so it scales cleanly).
    final headCenter = Offset(w * 0.5, h * 0.42);
    final headRadius = w * 0.40;

    _drawEars(canvas, headCenter, headRadius);
    _drawArms(canvas, w, h);
    _drawBody(canvas, w, h);
    _drawFeet(canvas, w, h);
    _drawHead(canvas, headCenter, headRadius);
    _drawFace(canvas, headCenter, headRadius);
    _drawMoodBadge(canvas, headCenter, headRadius, w, h);

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  void _drawGroundShadow(Canvas canvas, double w, double h, double lift) {
    // Shadow shrinks as Pip lifts up — reads as height.
    final t = (lift.abs() / (h * 0.04)).clamp(0.0, 1.0);
    final rx = w * (0.30 - t * 0.03);
    final paint = Paint()
      ..color = _black.withValues(alpha: 0.12 - t * 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.965),
        width: rx * 2,
        height: h * 0.05,
      ),
      paint,
    );
  }

  void _drawEars(Canvas canvas, Offset head, double r) {
    final earR = r * 0.42;
    // A tiny idle wiggle so the ears feel soft.
    final wiggle = math.sin(idle * math.pi) * 0.04;
    for (final sign in [-1.0, 1.0]) {
      final c = Offset(
        head.dx + sign * r * 0.72,
        head.dy - r * 0.62 + wiggle * r,
      );
      canvas.drawCircle(c, earR, Paint()..color = _black);
      // Inner ear highlight for a plush look.
      canvas.drawCircle(
        c.translate(sign * earR * 0.1, earR * 0.05),
        earR * 0.5,
        Paint()..color = _blackSoft,
      );
    }
  }

  void _drawBody(Canvas canvas, double w, double h) {
    // A rounded, egg-shaped chubby belly.
    final bodyRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.70),
      width: w * 0.72,
      height: h * 0.50,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.34)));

    // Soft vertical gradient gives roundness without heavy shading.
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_furWhite, _furShadow],
    ).createShader(bodyRect);
    canvas.drawPath(path, Paint()..shader = shader);

    // Belly patch — a warm cream oval for extra cuteness.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.72),
        width: w * 0.40,
        height: h * 0.30,
      ),
      Paint()..color = const Color(0xFFFFF6E9),
    );
  }

  void _drawArms(Canvas canvas, double w, double h) {
    // Excited mood raises the arms in a little cheer.
    final raise = mood == PandaMood.excited
        ? (math.sin(idle * math.pi * 2) * 0.5 + 0.5) * h * 0.06
        : 0.0;
    for (final sign in [-1.0, 1.0]) {
      final c = Offset(w * 0.5 + sign * w * 0.34, h * 0.66 - raise);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * 0.22, height: h * 0.20),
        Paint()..color = _black,
      );
    }
  }

  void _drawFeet(Canvas canvas, double w, double h) {
    for (final sign in [-1.0, 1.0]) {
      final c = Offset(w * 0.5 + sign * w * 0.18, h * 0.92);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * 0.24, height: h * 0.12),
        Paint()..color = _black,
      );
      // Little paw pad.
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -h * 0.005),
            width: w * 0.10, height: h * 0.05),
        Paint()..color = _blush.withValues(alpha: 0.85),
      );
    }
  }

  void _drawHead(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    final shader = const RadialGradient(
      center: Alignment(-0.2, -0.3),
      radius: 1.1,
      colors: [_furWhite, _furShadow],
    ).createShader(rect);
    canvas.drawCircle(c, r, Paint()..shader = shader);
  }

  void _drawFace(Canvas canvas, Offset c, double r) {
    final eyeDx = r * 0.42;
    final eyeDy = -r * 0.02;
    final leftEye = c.translate(-eyeDx, eyeDy);
    final rightEye = c.translate(eyeDx, eyeDy);

    // Signature black eye-patches (the panda look), gently tilted for charm.
    _drawEyePatch(canvas, leftEye, r, -1);
    _drawEyePatch(canvas, rightEye, r, 1);

    // Eyes themselves — open/closed driven by blink.
    _drawEye(canvas, leftEye, r);
    _drawEye(canvas, rightEye, r);

    // Blush cheeks.
    for (final sign in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(sign * r * 0.62, r * 0.30),
          width: r * 0.34,
          height: r * 0.22,
        ),
        Paint()
          ..color = _blush.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Nose.
    final nose = c.translate(0, r * 0.30);
    canvas.drawOval(
      Rect.fromCenter(center: nose, width: r * 0.22, height: r * 0.16),
      Paint()..color = _black,
    );
    // Nose shine.
    canvas.drawOval(
      Rect.fromCenter(
          center: nose.translate(-r * 0.04, -r * 0.03),
          width: r * 0.07,
          height: r * 0.05),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    _drawMouth(canvas, c, r);
  }

  void _drawEyePatch(Canvas canvas, Offset eye, double r, double sign) {
    final patch = Rect.fromCenter(
      center: eye.translate(sign * r * 0.02, r * 0.02),
      width: r * 0.52,
      height: r * 0.66,
    );
    canvas.save();
    canvas.translate(eye.dx, eye.dy);
    canvas.rotate(sign * 0.32); // tilt like a teardrop
    canvas.translate(-eye.dx, -eye.dy);
    canvas.drawOval(patch, Paint()..color = _black);
    canvas.restore();
  }

  void _drawEye(Canvas canvas, Offset eye, double r) {
    final openH = r * 0.24;
    final closed = blink; // 0 open .. 1 shut
    final currentH = openH * (1 - closed);

    if (mood == PandaMood.sleepy || closed > 0.85) {
      // Draw a cozy closed-eye arc.
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(eye.dx - r * 0.16, eye.dy)
        ..quadraticBezierTo(
            eye.dx, eye.dy + r * 0.14, eye.dx + r * 0.16, eye.dy);
      canvas.drawPath(path, paint);
      return;
    }

    // White of the eye.
    canvas.drawOval(
      Rect.fromCenter(
          center: eye, width: r * 0.22, height: currentH.clamp(0.5, openH)),
      Paint()..color = Colors.white,
    );
    // Pupil, glancing very slightly toward center.
    canvas.drawCircle(
      eye.translate(0, currentH * 0.05),
      (r * 0.10) * (1 - closed * 0.6),
      Paint()..color = _black,
    );
    // Catch-light sparkle.
    if (closed < 0.4) {
      canvas.drawCircle(
        eye.translate(-r * 0.03, -currentH * 0.25),
        r * 0.035,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawMouth(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = _black
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    final mouthTop = c.translate(0, r * 0.42);

    final path = Path()..moveTo(mouthTop.dx, mouthTop.dy);
    switch (mood) {
      case PandaMood.excited:
      case PandaMood.happy:
        // Wide happy "w"-ish smile.
        path
          ..quadraticBezierTo(c.dx - r * 0.14, mouthTop.dy + r * 0.14,
              c.dx - r * 0.02, mouthTop.dy + r * 0.02)
          ..moveTo(mouthTop.dx, mouthTop.dy)
          ..quadraticBezierTo(c.dx + r * 0.14, mouthTop.dy + r * 0.14,
              c.dx + r * 0.02, mouthTop.dy + r * 0.02);
      case PandaMood.sleepy:
        // Tiny content 'o'.
        canvas.drawCircle(
          mouthTop.translate(0, r * 0.04),
          r * 0.05,
          Paint()..color = _black,
        );
        return;
    }
    canvas.drawPath(path, paint);
  }

  /// A small floating badge near Pip's head that echoes the mood — a leaf when
  /// happy, a sparkle/star when excited, "z z" when sleepy.
  void _drawMoodBadge(
      Canvas canvas, Offset head, double r, double w, double h) {
    final float = math.sin(idle * math.pi * 2) * (r * 0.05);
    final anchor = head.translate(r * 0.95, -r * 0.85 + float);

    switch (mood) {
      case PandaMood.happy:
        // A little bamboo leaf.
        canvas.save();
        canvas.translate(anchor.dx, anchor.dy);
        canvas.rotate(-0.5 + math.sin(idle * math.pi) * 0.1);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(r * 0.18, -r * 0.10, r * 0.30, 0)
          ..quadraticBezierTo(r * 0.18, r * 0.10, 0, 0);
        canvas.drawPath(leaf, Paint()..color = _happyGreen);
        canvas.restore();
      case PandaMood.excited:
        _drawStar(canvas, anchor, r * 0.14, _excitedYellow);
        _drawStar(canvas, anchor.translate(r * 0.22, r * 0.30), r * 0.08,
            _excitedYellow.withValues(alpha: 0.8));
      case PandaMood.sleepy:
        final zPaint = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              color: _blackSoft.withValues(alpha: 0.7),
              fontSize: r * 0.28,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        zPaint.paint(canvas, anchor);
        zPaint.paint(canvas, anchor.translate(r * 0.22, -r * 0.20));
    }
  }

  void _drawStar(Canvas canvas, Offset c, double radius, Color color) {
    final path = Path();
    const points = 4;
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? radius : radius * 0.4;
      final a = (i / (points * 2)) * math.pi * 2 - math.pi / 2;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PandaPainter old) =>
      old.idle != idle ||
      old.blink != blink ||
      old.poke != poke ||
      old.mood != mood;
}
