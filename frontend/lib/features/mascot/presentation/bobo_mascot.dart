import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bobo — the app's chubby, cuddly puppy mascot.
///
/// Fully hand-drawn with a [CustomPainter], so there are **no image assets**
/// to load and it stays razor-sharp at any size / DPI. A bold outline wraps the
/// whole silhouette so Bobo pops against a light background and reads like a
/// designed mascot; every edge is a crisp vector fill (no blurs), so it renders
/// sharp on Android (Impeller) too. All animation is driven by
/// [AnimationController]s and repainting is confined to a [RepaintBoundary], so
/// the surrounding UI never re-lays-out while Bobo breathes, wags, and blinks —
/// the paint runs on the GPU raster thread.
///
/// Bobo has a small set of moods that map to reminder state:
///  * [BoboMood.happy]   — nothing due, tail wagging, chilled out.
///  * [BoboMood.excited] — a reminder is coming up soon (bouncy, sparkly).
///  * [BoboMood.sleepy]  — all caught up / quiet hours.
enum BoboMood { happy, excited, sleepy }

class BoboMascot extends StatefulWidget {
  const BoboMascot({
    super.key,
    this.size = 220,
    this.mood = BoboMood.happy,
    this.onTap,
  });

  /// Rendered width of the mascot in logical pixels. Height follows the
  /// intrinsic aspect ratio so Bobo is never squished.
  final double size;

  /// Drives the idle personality (see [BoboMood]).
  final BoboMood mood;

  /// Optional tap handler — gives Bobo a springy squish when poked.
  final VoidCallback? onTap;

  @override
  State<BoboMascot> createState() => _BoboMascotState();
}

class _BoboMascotState extends State<BoboMascot>
    with TickerProviderStateMixin {
  // Slow, always-on "breathing" + gentle vertical bob + ear/tail sway.
  late final AnimationController _idle;
  // A faster loop just for the tail wag (happy dogs wag quickly).
  late final AnimationController _wag;
  // Blink is a separate short controller so it never fights the idle loop.
  late final AnimationController _blink;
  // Springy squish when tapped.
  late final AnimationController _poke;

  final math.Random _rng = math.Random();
  // Pending blink timer, cancelled on dispose so it doesn't leak past teardown.
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();

    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _wag = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
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

  /// Blink at pseudo-random intervals so Bobo feels alive, not robotic.
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
    _wag.dispose();
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
            animation: Listenable.merge([_idle, _wag, _blink, _poke]),
            builder: (context, _) {
              return CustomPaint(
                painter: _BoboPainter(
                  idle: _idle.value,
                  wag: _wag.value,
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

class _BoboPainter extends CustomPainter {
  _BoboPainter({
    required this.idle,
    required this.wag,
    required this.blink,
    required this.poke,
    required this.mood,
  });

  /// 0..1, ping-ponging — breathing / bob phase.
  final double idle;

  /// 0..1, ping-ponging (fast) — tail wag phase.
  final double wag;

  /// 0..1 — eyes closing amount.
  final double blink;

  /// 0..1 (elastic) — tap squish impulse, decays to 0.
  final double poke;

  final BoboMood mood;

  // ---- Palette --------------------------------------------------------------
  // Warm cream coat so Bobo never dissolves into a light background, a bold
  // outline for a clean mascot silhouette, and rich browns for the puppy
  // markings (ears + eye patch). No soft blurs anywhere — every edge is a crisp
  // vector fill, so it stays sharp on Android too.
  static const _coat = Color(0xFFFFF3DE); // warm cream fur
  static const _coatShadow = Color(0xFFF3E4C4); // faint roundness tone
  static const _brown = Color(0xFF8A5A2B); // ears / eye-patch
  static const _brownDark = Color(0xFF6E441E); // inner ear
  static const _ink = Color(0xFF2B2B33); // outline / nose / eyes
  static const _blush = Color(0xFFFF9CB6);
  static const _tongue = Color(0xFFFF7E9D);
  static const _happyBone = Color(0xFFF4E9D8);
  static const _excitedYellow = Color(0xFFFFC93C);

  /// Bold outline that wraps Bobo's whole silhouette. Scales with the mascot.
  double _outlineW(double r) => r * 0.09;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ---- Animation-derived transforms --------------------------------------
    final bob = math.sin(idle * math.pi) * (h * 0.018);
    final breathe = 1 + math.sin(idle * math.pi) * 0.02;
    final excitedBounce = mood == BoboMood.excited
        ? math.sin(idle * math.pi * 2) * (h * 0.02)
        : 0.0;

    final squishX = 1 + poke * 0.08;
    final squishY = 1 - poke * 0.08;

    canvas.save();
    canvas.translate(w / 2, h / 2 + bob - excitedBounce);
    canvas.scale(squishX * breathe, squishY * breathe);
    canvas.translate(-w / 2, -h / 2);

    _drawGroundShadow(canvas, w, h, bob + excitedBounce);

    final headCenter = Offset(w * 0.5, h * 0.40);
    final headRadius = w * 0.42;

    // Tail is drawn first (behind the body) so it peeks out and wags.
    _drawTail(canvas, w, h);

    // Whole cream silhouette (body + legs + head) as ONE union path: stroke
    // once for a clean wrapping outline, then fill — no internal seams.
    final silhouette = _buildSilhouette(w, h, headCenter, headRadius);
    canvas.drawPath(
      silhouette,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _outlineW(headRadius)
        ..strokeJoin = StrokeJoin.round,
    );
    _drawLegs(canvas, w, h);
    _fillCoat(canvas, w, h, headCenter, headRadius);

    // Floppy ears sit on top of the head sides, outlined too.
    _drawEars(canvas, headCenter, headRadius);
    _drawFace(canvas, headCenter, headRadius);
    _drawMoodBadge(canvas, headCenter, headRadius, w, h);

    canvas.restore();
  }

  // ---- geometry (shared so silhouette + fills line up exactly) --------------
  Rect _bodyRect(double w, double h) => Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.72),
        width: w * 0.78,
        height: h * 0.52,
      );

  Offset _legCenter(double w, double h, double sign) =>
      Offset(w * 0.5 + sign * w * 0.20, h * 0.93);

  // ---------------------------------------------------------------------------
  void _drawGroundShadow(Canvas canvas, double w, double h, double lift) {
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

  /// Union of the cream body parts (body + head + front legs) so the outline
  /// wraps the outside in one clean stroke.
  Path _buildSilhouette(double w, double h, Offset head, double r) {
    Path p = Path()
      ..addRRect(RRect.fromRectAndRadius(
          _bodyRect(w, h), Radius.circular(w * 0.38)));
    p = Path.combine(PathOperation.union, p,
        Path()..addOval(Rect.fromCircle(center: head, radius: r)));
    for (final s in [-1.0, 1.0]) {
      p = Path.combine(
          PathOperation.union,
          p,
          Path()
            ..addRRect(RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: _legCenter(w, h, s),
                    width: w * 0.22,
                    height: h * 0.14),
                Radius.circular(w * 0.11))));
    }
    return p;
  }

  /// The tail — a curved teardrop behind the body that wags side to side.
  void _drawTail(Canvas canvas, double w, double h) {
    // Happy dogs wag hard; excited a touch; sleepy barely.
    final amp = switch (mood) {
      BoboMood.happy => 0.16,
      BoboMood.excited => 0.10,
      BoboMood.sleepy => 0.03,
    };
    final swing = (wag - 0.5) * 2 * amp; // -amp..amp
    final base = Offset(w * 0.5 + w * 0.34, h * 0.66);

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(-0.5 + swing); // upward, wagging
    final tail = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w * 0.10, -h * 0.02, w * 0.16, -h * 0.10)
      ..quadraticBezierTo(w * 0.20, -h * 0.02, w * 0.06, h * 0.02)
      ..close();
    // Outline then fill for the same crisp look as the body.
    canvas.drawPath(
        tail,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.03
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(tail, Paint()..color = _coat);
    canvas.restore();
  }

  void _drawLegs(Canvas canvas, double w, double h) {
    for (final s in [-1.0, 1.0]) {
      final c = _legCenter(w, h, s);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: w * 0.22, height: h * 0.14),
          Radius.circular(w * 0.11),
        ),
        Paint()..color = _coat,
      );
      // Little paw pad.
      canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(0, h * 0.015), width: w * 0.09, height: h * 0.04),
        Paint()..color = _blush.withValues(alpha: 0.7),
      );
    }
  }

  /// Fill head + body in warm cream with a faint roundness gradient.
  void _fillCoat(Canvas canvas, double w, double h, Offset head, double r) {
    final bodyRect = _bodyRect(w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.38)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_coat, _coatShadow],
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
          colors: [_coat, _coatShadow],
        ).createShader(headRect),
    );
    // A soft cream belly patch, slightly lighter, for depth.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.76), width: w * 0.42, height: h * 0.28),
      Paint()..color = const Color(0xFFFFFBF0),
    );
  }

  /// Two big floppy ears hanging down the sides — the signature "dog" cue.
  void _drawEars(Canvas canvas, Offset head, double r) {
    // Gentle idle flop, plus a bit of extra bounce when excited.
    final flop = math.sin(idle * math.pi) * 0.06 +
        (mood == BoboMood.excited ? math.sin(idle * math.pi * 2) * 0.05 : 0);
    for (final sign in [-1.0, 1.0]) {
      canvas.save();
      // Anchor further out on the head and higher up, so the ears frame the
      // face and hang at the sides instead of covering the eyes.
      final anchor = head.translate(sign * r * 0.88, -r * 0.42);
      canvas.translate(anchor.dx, anchor.dy);
      canvas.rotate(sign * (0.55 + flop)); // more outward tilt
      // A slimmer, shorter rounded flap.
      final ear = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, r * 0.40), width: r * 0.40, height: r * 0.82),
        Radius.circular(r * 0.20),
      );
      canvas.drawRRect(
          ear,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = _outlineW(r) * 0.8);
      canvas.drawRRect(ear, Paint()..color = _brown);
      // Inner ear.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(0, r * 0.44), width: r * 0.22, height: r * 0.56),
          Radius.circular(r * 0.12),
        ),
        Paint()..color = _brownDark,
      );
      canvas.restore();
    }
  }

  void _drawFace(Canvas canvas, Offset c, double r) {
    // A brown patch over Bobo's left eye — classic cute-puppy marking, and it
    // gives the face character without going full panda.
    final leftEye = c.translate(-r * 0.38, -r * 0.04);
    final rightEye = c.translate(r * 0.38, -r * 0.04);
    _drawEyePatch(canvas, leftEye, r);

    _drawEye(canvas, leftEye, r);
    _drawEye(canvas, rightEye, r);

    // Blush cheeks — crisp solid ovals.
    for (final sign in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(sign * r * 0.58, r * 0.30),
          width: r * 0.28,
          height: r * 0.18,
        ),
        Paint()..color = _blush.withValues(alpha: 0.85),
      );
    }

    _drawSnout(canvas, c, r);
  }

  /// The brown eye-patch (only over the left eye).
  void _drawEyePatch(Canvas canvas, Offset eye, double r) {
    canvas.save();
    canvas.translate(eye.dx, eye.dy);
    canvas.rotate(-0.25);
    canvas.translate(-eye.dx, -eye.dy);
    canvas.drawOval(
      Rect.fromCenter(
          center: eye.translate(-r * 0.02, r * 0.02),
          width: r * 0.46,
          height: r * 0.58),
      Paint()..color = _brown,
    );
    canvas.restore();
  }

  void _drawEye(Canvas canvas, Offset eye, double r) {
    final openH = r * 0.26;
    final closed = blink;
    final currentH = openH * (1 - closed);

    if (mood == BoboMood.sleepy || closed > 0.85) {
      // Cozy closed-eye arc, dark so it reads on the cream coat.
      final paint = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(eye.dx - r * 0.15, eye.dy)
          ..quadraticBezierTo(
              eye.dx, eye.dy + r * 0.13, eye.dx + r * 0.15, eye.dy),
        paint,
      );
      return;
    }

    // Big round dark eye.
    canvas.drawOval(
      Rect.fromCenter(
          center: eye,
          width: r * 0.24,
          height: currentH.clamp(0.5, openH) + r * 0.02),
      Paint()..color = _ink,
    );
    // Catch-light sparkle.
    if (closed < 0.4) {
      canvas.drawCircle(
        eye.translate(-r * 0.04, -r * 0.05),
        r * 0.045,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        eye.translate(r * 0.03, r * 0.03),
        r * 0.02,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  /// A raised muzzle with a black nose, mouth, and tongue.
  void _drawSnout(Canvas canvas, Offset c, double r) {
    // Lighter muzzle bump so the snout reads as raised.
    final muzzle = Offset(c.dx, c.dy + r * 0.34);
    canvas.drawOval(
      Rect.fromCenter(
          center: muzzle, width: r * 0.62, height: r * 0.48),
      Paint()..color = const Color(0xFFFFFBF0),
    );

    // Nose — rounded soft triangle.
    final nose = c.translate(0, r * 0.20);
    final nw = r * 0.15, nh = r * 0.12;
    final nosePath = Path()
      ..moveTo(nose.dx, nose.dy + nh)
      ..cubicTo(nose.dx - nw * 1.6, nose.dy + nh * 0.2, nose.dx - nw,
          nose.dy - nh, nose.dx, nose.dy - nh * 0.4)
      ..cubicTo(nose.dx + nw, nose.dy - nh, nose.dx + nw * 1.6,
          nose.dy + nh * 0.2, nose.dx, nose.dy + nh)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = _ink);
    canvas.drawOval(
      Rect.fromCenter(
          center: nose.translate(-r * 0.04, -r * 0.035),
          width: r * 0.055,
          height: r * 0.04),
      Paint()..color = Colors.white,
    );

    _drawMouth(canvas, nose, r);
  }

  void _drawMouth(Canvas canvas, Offset nose, double r) {
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Muzzle line down from the nose.
    final chin = nose.translate(0, r * 0.20);
    canvas.drawLine(nose.translate(0, r * 0.11), chin, line);

    switch (mood) {
      case BoboMood.sleepy:
        // Small content mouth — two tiny curves.
        for (final s in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(chin.dx, chin.dy)
              ..quadraticBezierTo(chin.dx + s * r * 0.10, chin.dy + r * 0.02,
                  chin.dx + s * r * 0.13, chin.dy - r * 0.04),
            line,
          );
        }
        return;

      case BoboMood.happy:
      case BoboMood.excited:
        // Open happy grin: two upward curves from the chin forming a smile,
        // with a tongue lolling out — very puppy.
        final wide = r * (mood == BoboMood.excited ? 0.20 : 0.16);
        final drop = r * (mood == BoboMood.excited ? 0.16 : 0.12);
        final smile = Path()
          ..moveTo(chin.dx - wide, chin.dy - drop * 0.2)
          ..quadraticBezierTo(
              chin.dx, chin.dy + drop, chin.dx + wide, chin.dy - drop * 0.2);
        canvas.drawPath(smile, line);

        // Tongue lolling out at the bottom of the smile.
        final tongueTop = chin.translate(0, drop * 0.35);
        final tongue = Path()
          ..moveTo(tongueTop.dx - wide * 0.42, tongueTop.dy)
          ..quadraticBezierTo(tongueTop.dx - wide * 0.5,
              tongueTop.dy + drop * 1.1, tongueTop.dx, tongueTop.dy + drop * 1.2)
          ..quadraticBezierTo(tongueTop.dx + wide * 0.5,
              tongueTop.dy + drop * 1.1, tongueTop.dx + wide * 0.42, tongueTop.dy)
          ..close();
        canvas.drawPath(tongue, Paint()..color = _tongue);
        // Center crease on the tongue.
        canvas.drawLine(
          tongueTop.translate(0, drop * 0.15),
          tongueTop.translate(0, drop * 1.0),
          Paint()
            ..color = _ink.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.02
            ..strokeCap = StrokeCap.round,
        );
        return;
    }
  }

  /// A small floating badge near Bobo's head that echoes the mood — a bone when
  /// happy, sparkles when excited, "z z" when sleepy.
  void _drawMoodBadge(
      Canvas canvas, Offset head, double r, double w, double h) {
    final float = math.sin(idle * math.pi * 2) * (r * 0.05);
    final anchor = head.translate(r * 1.0, -r * 0.85 + float);

    switch (mood) {
      case BoboMood.happy:
        _drawBone(canvas, anchor, r * 0.30);
      case BoboMood.excited:
        _drawStar(canvas, anchor, r * 0.14, _excitedYellow);
        _drawStar(canvas, anchor.translate(r * 0.22, r * 0.30), r * 0.08,
            _excitedYellow.withValues(alpha: 0.8));
      case BoboMood.sleepy:
        final zPaint = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              color: _ink.withValues(alpha: 0.6),
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

  void _drawBone(Canvas canvas, Offset c, double len) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.5 + math.sin(idle * math.pi) * 0.1);
    final bonePaint = Paint()..color = _happyBone;
    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = len * 0.08;
    final knob = len * 0.16;
    // Shaft.
    final shaft = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: len, height: len * 0.22),
      Radius.circular(len * 0.11),
    );
    canvas.drawRRect(shaft, bonePaint);
    // Four knobs at the ends.
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawCircle(
            Offset(sx * len * 0.5, sy * knob * 0.9), knob, bonePaint);
      }
    }
    canvas.drawRRect(shaft, outline);
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawCircle(
            Offset(sx * len * 0.5, sy * knob * 0.9), knob, outline);
      }
    }
    canvas.restore();
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
  bool shouldRepaint(_BoboPainter old) =>
      old.idle != idle ||
      old.wag != wag ||
      old.blink != blink ||
      old.poke != poke ||
      old.mood != mood;
}
