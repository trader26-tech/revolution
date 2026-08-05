import 'dart:async';
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
  // The pending blink timer, held so it can be cancelled on dispose (otherwise
  // the self-rescheduling delay leaks a timer past teardown).
  Timer? _blinkTimer;

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
    _blinkTimer = Timer(Duration(milliseconds: ms), () async {
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
    _blinkTimer?.cancel();
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
  // Fur is a warm off-white so Pip never dissolves into a light background,
  // and a bold outline gives him a clean, mascot-style silhouette. The barely
  // cooler shadow tone reads as roundness. No soft blurs anywhere — every edge
  // is a crisp vector fill so it renders sharp on Android (Impeller) too.
  static const _furWhite = Color(0xFFFFFDF7);
  static const _furShadow = Color(0xFFF3EFE4);
  static const _black = Color(0xFF2B2B33);
  static const _blackSoft = Color(0xFF3A3A45);
  static const _blush = Color(0xFFFF9CB6);
  static const _happyGreen = Color(0xFF6FCF97);
  static const _excitedYellow = Color(0xFFFFC93C);

  /// Bold outline that wraps Pip's whole silhouette. Line width scales with the
  /// panda so it stays proportional at any [size].
  double _outlineW(double r) => r * 0.09;

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
    final headCenter = Offset(w * 0.5, h * 0.40);
    final headRadius = w * 0.44;

    // The whole white silhouette (body + arms + feet + head + ears) is built as
    // ONE union path. We stroke it once for a clean wrapping outline, then fill
    // it — so there are no internal seams and every outer edge is crisp.
    final silhouette = _buildSilhouette(w, h, headCenter, headRadius);
    final ow = _outlineW(headRadius);
    canvas.drawPath(
      silhouette,
      Paint()
        ..color = _black
        ..style = PaintingStyle.stroke
        ..strokeWidth = ow
        ..strokeJoin = StrokeJoin.round,
    );
    // Ears + limbs are black — draw them BEFORE the white fill so the white
    // head/body sit on top and read as fur over the black bits.
    _drawEars(canvas, headCenter, headRadius);
    _drawArms(canvas, w, h);
    _drawFeet(canvas, w, h);
    // White fur fill for head + body, with the faint roundness gradient.
    _fillFur(canvas, w, h, headCenter, headRadius);

    _drawFace(canvas, headCenter, headRadius);
    _drawMoodBadge(canvas, headCenter, headRadius, w, h);

    canvas.restore();
  }

  // ---- geometry (shared so silhouette + fills line up exactly) --------------
  Rect _bodyRect(double w, double h) => Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.71),
        width: w * 0.82,
        height: h * 0.54,
      );

  Offset _earCenter(Offset head, double r, double sign) {
    final wiggle = math.sin(idle * math.pi) * 0.04;
    return Offset(head.dx + sign * r * 0.72, head.dy - r * 0.62 + wiggle * r);
  }

  double _armRaise(double h) => mood == PandaMood.excited
      ? (math.sin(idle * math.pi * 2) * 0.5 + 0.5) * h * 0.06
      : 0.0;

  Offset _armCenter(double w, double h, double sign) =>
      Offset(w * 0.5 + sign * w * 0.38, h * 0.66 - _armRaise(h));

  Offset _footCenter(double w, double h, double sign) =>
      Offset(w * 0.5 + sign * w * 0.18, h * 0.92);

  // ---------------------------------------------------------------------------
  void _drawGroundShadow(Canvas canvas, double w, double h, double lift) {
    // Crisp solid oval (no blur — blur is what looked grainy on Android).
    final t = (lift.abs() / (h * 0.04)).clamp(0.0, 1.0);
    final rx = w * (0.26 - t * 0.03);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.965),
        width: rx * 2,
        height: h * 0.045,
      ),
      Paint()..color = const Color(0x14000000),
    );
  }

  /// Union of every white body part — head, body, ears, arms, feet — so the
  /// outline can wrap the outside in one clean stroke.
  Path _buildSilhouette(double w, double h, Offset head, double r) {
    Path p = Path()
      ..addRRect(RRect.fromRectAndRadius(
          _bodyRect(w, h), Radius.circular(w * 0.40)));
    p = Path.combine(PathOperation.union, p,
        Path()..addOval(Rect.fromCircle(center: head, radius: r)));
    final earR = r * 0.42;
    for (final s in [-1.0, 1.0]) {
      p = Path.combine(PathOperation.union, p,
          Path()..addOval(Rect.fromCircle(center: _earCenter(head, r, s), radius: earR)));
    }
    for (final s in [-1.0, 1.0]) {
      p = Path.combine(PathOperation.union, p,
          Path()..addOval(Rect.fromCenter(
              center: _armCenter(w, h, s), width: w * 0.24, height: h * 0.22)));
      p = Path.combine(PathOperation.union, p,
          Path()..addOval(Rect.fromCenter(
              center: _footCenter(w, h, s), width: w * 0.24, height: h * 0.12)));
    }
    return p;
  }

  void _drawEars(Canvas canvas, Offset head, double r) {
    final earR = r * 0.42;
    for (final sign in [-1.0, 1.0]) {
      final c = _earCenter(head, r, sign);
      canvas.drawCircle(c, earR, Paint()..color = _black);
      canvas.drawCircle(
        c.translate(sign * earR * 0.1, earR * 0.05),
        earR * 0.5,
        Paint()..color = _blackSoft,
      );
    }
  }

  void _drawArms(Canvas canvas, double w, double h) {
    for (final sign in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: _armCenter(w, h, sign), width: w * 0.24, height: h * 0.22),
        Paint()..color = _black,
      );
    }
  }

  void _drawFeet(Canvas canvas, double w, double h) {
    for (final sign in [-1.0, 1.0]) {
      final c = _footCenter(w, h, sign);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * 0.24, height: h * 0.12),
        Paint()..color = _black,
      );
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -h * 0.005),
            width: w * 0.10, height: h * 0.05),
        Paint()..color = _blush,
      );
    }
  }

  /// Fill the head + body in warm white with a faint roundness gradient.
  void _fillFur(Canvas canvas, double w, double h, Offset head, double r) {
    final bodyRect = _bodyRect(w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.40)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_furWhite, _furShadow],
        ).createShader(bodyRect),
    );
    final headRect = Rect.fromCircle(center: head, radius: r);
    canvas.drawCircle(
      head,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          radius: 1.1,
          colors: [_furWhite, _furShadow],
        ).createShader(headRect),
    );
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

    // Blush cheeks — crisp solid ovals (no blur, so they stay sharp).
    for (final sign in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(sign * r * 0.60, r * 0.32),
          width: r * 0.30,
          height: r * 0.20,
        ),
        Paint()..color = _blush.withValues(alpha: 0.85),
      );
    }

    // Nose — a rounded soft-triangle heart shape gives more character than a
    // plain oval, and reads clearly on the white muzzle.
    final nose = c.translate(0, r * 0.30);
    final nw = r * 0.13, nh = r * 0.11;
    final nosePath = Path()
      ..moveTo(nose.dx, nose.dy + nh)
      ..cubicTo(nose.dx - nw * 1.6, nose.dy + nh * 0.2, nose.dx - nw,
          nose.dy - nh, nose.dx, nose.dy - nh * 0.4)
      ..cubicTo(nose.dx + nw, nose.dy - nh, nose.dx + nw * 1.6,
          nose.dy + nh * 0.2, nose.dx, nose.dy + nh)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = _black);
    // Crisp nose shine.
    canvas.drawOval(
      Rect.fromCenter(
          center: nose.translate(-r * 0.03, -r * 0.03),
          width: r * 0.05,
          height: r * 0.035),
      Paint()..color = Colors.white,
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
    // Mouth sits just under the nose, connected by a soft little muzzle line.
    final mouthTop = c.translate(0, r * 0.40);

    switch (mood) {
      case PandaMood.sleepy:
        // Tiny content 'o' — sleepy and cozy.
        canvas.drawCircle(
          mouthTop.translate(0, r * 0.02),
          r * 0.05,
          Paint()..color = _black,
        );
        return;

      case PandaMood.happy:
      case PandaMood.excited:
        // A soft, filled open grin — the big charm upgrade. A rounded "D"
        // shape (flat-ish top, deeply curved bottom) reads as a warm, wide
        // smile instead of a stiff line.
        final halfW = r * 0.24; // wider = friendlier
        final depth = r * (mood == PandaMood.excited ? 0.30 : 0.24);
        final left = mouthTop.translate(-halfW, 0);
        final right = mouthTop.translate(halfW, 0);

        final smile = Path()
          ..moveTo(left.dx, left.dy)
          // gentle top lip, dipping just slightly in the middle
          ..quadraticBezierTo(
              c.dx, mouthTop.dy + r * 0.04, right.dx, right.dy)
          // full rounded lower lip — the happy curve
          ..quadraticBezierTo(
              c.dx, mouthTop.dy + depth, left.dx, left.dy)
          ..close();

        canvas.drawPath(smile, Paint()..color = _black);

        // A little tongue tucked at the bottom — instantly cute.
        final tongue = Path()
          ..moveTo(c.dx - halfW * 0.5, mouthTop.dy + depth * 0.45)
          ..quadraticBezierTo(c.dx, mouthTop.dy + depth * 1.05,
              c.dx + halfW * 0.5, mouthTop.dy + depth * 0.45)
          ..close();
        canvas.drawPath(tongue, Paint()..color = _blush);

        // A soft muzzle line up to the nose ties the face together, and two
        // short strokes curving gently DOWN into the smile corners give a warm,
        // dimpled grin (no flaring "whiskers").
        final line = Paint()
          ..color = _black
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..strokeCap = StrokeCap.round;
        // muzzle: nose bottom -> top of smile
        canvas.drawLine(
          c.translate(0, r * 0.30 + r * 0.08),
          mouthTop.translate(0, r * 0.02),
          line,
        );
        for (final s in [-1.0, 1.0]) {
          final tip = mouthTop.translate(s * halfW, 0);
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx - s * r * 0.06, tip.dy - r * 0.05)
              ..quadraticBezierTo(
                  tip.dx, tip.dy - r * 0.01, tip.dx, tip.dy + r * 0.01),
            line,
          );
        }
        return;
    }
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
