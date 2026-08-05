import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bobo — the app's cuddly puppy mascot.
///
/// Image-first: if an illustrated PNG exists for the current mood
/// (`assets/images/bobo_<mood>.png`), Bobo shows that professionally-drawn art
/// with a gentle breathing bob and a springy bounce when tapped. If the asset
/// isn't present yet, it gracefully falls back to the built-in code-drawn
/// [_BoboFallback] so the app never breaks.
///
/// Bobo's emotional states, each mapped to a real app situation so that a
/// glance at Bobo tells the user how things stand:
///  * [BoboMood.happy]      — content, nothing pressing.
///  * [BoboMood.excited]    — a reminder is coming up soon (waving, bouncy).
///  * [BoboMood.sleepy]     — all calm, nothing upcoming (relaxed).
///  * [BoboMood.scared]     — a deadline is very close (sweating, anxious).
///  * [BoboMood.sad]        — something was forgotten / is overdue.
///  * [BoboMood.writing]    — the user is entering details (noting it down).
///  * [BoboMood.celebrating]— a task was completed successfully.
///  * [BoboMood.waving]     — greeting the user (onboarding welcome).
enum BoboMood { happy, excited, sleepy, scared, sad, writing, celebrating, waving }

extension _BoboMoodAsset on BoboMood {
  /// The base filename (no extension) for this mood's illustrated art.
  String get _base => switch (this) {
        BoboMood.happy => 'bobo_happy',
        BoboMood.excited => 'bobo_excited',
        BoboMood.sleepy => 'bobo_sleepy',
        BoboMood.scared => 'bobo_scared',
        BoboMood.sad => 'bobo_sad',
        BoboMood.writing => 'bobo_writing',
        BoboMood.celebrating => 'bobo_celebrating',
        BoboMood.waving => 'bobo_waving',
      };

  /// Candidate asset paths in priority order: animated WebP first (best), then
  /// animated GIF, then a static PNG. The first that exists wins, so dropping in
  /// any one of them "just works". Flutter plays animated WebP/GIF natively.
  List<String> get assetCandidates => [
        'assets/images/$_base.webp',
        'assets/images/$_base.gif',
        'assets/images/$_base.png',
      ];

  /// Which of the three code-drawn base expressions to use when no art exists.
  /// The two "action" moods borrow the closest resting expression.
  BoboMood get fallbackBase => switch (this) {
        BoboMood.scared => BoboMood.excited, // alert/anxious ~ bouncy-alert
        BoboMood.sad => BoboMood.sleepy, // drooped ~ low-energy
        BoboMood.writing => BoboMood.happy,
        BoboMood.celebrating => BoboMood.excited,
        BoboMood.waving => BoboMood.excited, // waving ~ bouncy greeting
        final m => m, // happy / excited / sleepy draw themselves
      };
}

class BoboMascot extends StatefulWidget {
  const BoboMascot({
    super.key,
    this.size = 220,
    this.mood = BoboMood.happy,
    this.onTap,
  });

  final double size;
  final BoboMood mood;
  final VoidCallback? onTap;

  @override
  State<BoboMascot> createState() => _BoboMascotState();
}

class _BoboMascotState extends State<BoboMascot>
    with TickerProviderStateMixin {
  late final AnimationController _idle; // breathing + bob
  late final AnimationController _poke; // tap bounce

  // Per-mood: the resolved asset path that exists (webp/gif/png), or null if we
  // checked and none is bundled (→ code-drawn fallback). Absent = not checked.
  final Map<BoboMood, String?> _resolvedAsset = {};

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _poke = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _probe(widget.mood);
  }

  @override
  void didUpdateWidget(BoboMascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _probe(widget.mood);
  }

  /// Find which illustrated asset (if any) is bundled for [mood], trying WebP →
  /// GIF → PNG in order. Resolves once per mood and caches the result. Uses the
  /// asset bundle so a missing file cleanly flips us to the code-drawn fallback
  /// instead of showing a broken-image box.
  Future<void> _probe(BoboMood mood) async {
    if (_resolvedAsset.containsKey(mood)) return;
    for (final path in mood.assetCandidates) {
      try {
        await DefaultAssetBundle.of(context).load(path);
        if (mounted) setState(() => _resolvedAsset[mood] = path);
        return; // first hit wins
      } catch (_) {
        // try the next candidate
      }
    }
    if (mounted) setState(() => _resolvedAsset[mood] = null);
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
    _poke.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.size * 1.06;
    final resolved = _resolvedAsset[widget.mood];

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: height,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _poke]),
            builder: (context, child) {
              // Gentle breathing bob + tap bounce, applied to whichever art we
              // show. Kept on the raster thread via the RepaintBoundary above.
              final bob = math.sin(_idle.value * math.pi) * (height * 0.02);
              final pokeT = Curves.elasticOut.transform(_poke.value);
              final scale = 1 + math.sin(_idle.value * math.pi) * 0.015;
              return Transform.translate(
                offset: Offset(0, bob - pokeT * height * 0.04),
                child: Transform.scale(
                  scale: scale * (1 + pokeT * 0.05),
                  child: child,
                ),
              );
            },
            // The child is built once (not every tick) — just the art.
            // Illustrated (webp/gif/png) if bundled, else the code-drawn Bobo
            // using the closest resting expression for this mood.
            child: resolved != null
                ? Image.asset(
                    resolved,
                    width: widget.size,
                    height: height,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )
                : _BoboFallback(mood: widget.mood.fallbackBase),
          ),
        ),
      ),
    );
  }
}

/// The built-in code-drawn Bobo, shown until illustrated PNGs are added. Runs
/// its own idle/blink/wag animation.
class _BoboFallback extends StatefulWidget {
  const _BoboFallback({required this.mood});
  final BoboMood mood;

  @override
  State<_BoboFallback> createState() => _BoboFallbackState();
}

class _BoboFallbackState extends State<_BoboFallback>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _wag;
  late final AnimationController _blink;

  final math.Random _rng = math.Random();
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
      duration: const Duration(milliseconds: 150),
    );
    _scheduleBlink();
  }

  void _scheduleBlink() {
    final ms = 2200 + _rng.nextInt(2600);
    _blinkTimer = Timer(Duration(milliseconds: ms), () async {
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
      if (mounted && _rng.nextDouble() < 0.25) {
        await _blink.forward();
        await _blink.reverse();
      }
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _wag.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _wag, _blink]),
      builder: (context, _) {
        return CustomPaint(
          painter: _BoboPainter(
            idle: _idle.value,
            wag: _wag.value,
            blink: _blink.value,
            poke: 0, // tap bounce handled by the parent wrapper
            mood: widget.mood,
          ),
        );
      },
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

  final double idle;
  final double wag;
  final double blink;
  final double poke;
  final BoboMood mood;

  // ---- Palette --------------------------------------------------------------
  static const _coat = Color(0xFFFFF3DE); // warm cream fur
  static const _coatShade = Color(0xFFF4E4C6); // faint roundness
  static const _ear = Color(0xFF9C6B3B); // caramel ears
  static const _earShade = Color(0xFF7E5227); // deeper ear tone
  static const _patch = Color(0xFFB07E4C); // soft eye-patch
  static const _ink = Color(0xFF2E2A26); // outline / features
  static const _blush = Color(0xFFFFA8BF);
  static const _excitedYellow = Color(0xFFFFC93C);
  static const _bone = Color(0xFFF3E7D2);

  double _ow(double r) => r * 0.085; // outline width

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bob = math.sin(idle * math.pi) * (h * 0.015);
    final breathe = 1 + math.sin(idle * math.pi) * 0.018;
    final excitedBounce = mood == BoboMood.excited
        ? math.sin(idle * math.pi * 2) * (h * 0.018)
        : 0.0;
    final squishX = 1 + poke * 0.07;
    final squishY = 1 - poke * 0.07;

    canvas.save();
    canvas.translate(w / 2, h / 2 + bob - excitedBounce);
    canvas.scale(squishX * breathe, squishY * breathe);
    canvas.translate(-w / 2, -h / 2);

    _groundShadow(canvas, w, h, bob + excitedBounce);

    // BIG head dominates; small body tuft below.
    final head = Offset(w * 0.5, h * 0.44);
    final headR = w * 0.40;

    _tail(canvas, w, h, headR);
    _body(canvas, w, h, head, headR);
    _headShape(canvas, head, headR);
    // Ears drawn AFTER the head so they sit on top and frame the face.
    _ears(canvas, head, headR);
    _face(canvas, head, headR);
    _moodBadge(canvas, head, headR);

    canvas.restore();
  }

  void _groundShadow(Canvas canvas, double w, double h, double lift) {
    final t = (lift.abs() / (h * 0.04)).clamp(0.0, 1.0);
    final rx = w * (0.24 - t * 0.03);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.97), width: rx * 2, height: h * 0.04),
      Paint()..color = const Color(0x12000000),
    );
  }

  /// Small rounded body tuft peeking below the big head.
  void _body(Canvas canvas, double w, double h, Offset head, double r) {
    final rect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.82), width: w * 0.50, height: h * 0.34);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(w * 0.24)));
    // Two little front paws.
    for (final s in [-1.0, 1.0]) {
      path.addOval(Rect.fromCenter(
          center: Offset(w * 0.5 + s * w * 0.14, h * 0.95),
          width: w * 0.17,
          height: h * 0.10));
    }
    _strokeFill(canvas, path, _coat, r);
    // paw pad hints
    for (final s in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5 + s * w * 0.14, h * 0.965),
            width: w * 0.06,
            height: h * 0.03),
        Paint()..color = _blush.withValues(alpha: 0.55),
      );
    }
  }

  /// Wagging tail behind the body.
  void _tail(Canvas canvas, double w, double h, double r) {
    final amp = switch (mood) {
      BoboMood.excited => 0.12,
      BoboMood.sleepy => 0.03,
      _ => 0.18, // happy and any action-mood fall through to a lively wag
    };
    final swing = (wag - 0.5) * 2 * amp;
    canvas.save();
    canvas.translate(w * 0.72, h * 0.80);
    canvas.rotate(-0.7 + swing);
    final tail = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w * 0.10, -h * 0.02, w * 0.14, -h * 0.09)
      ..quadraticBezierTo(w * 0.18, -h * 0.02, w * 0.05, h * 0.02)
      ..close();
    _strokeFill(canvas, tail, _coat, r * 0.9);
    canvas.restore();
  }

  /// Two big, soft, fluffy ears that sit on the upper-outer head and drape down
  /// the sides, framing the face. Each is a plump rounded lobe (wider at the
  /// bottom) that sways gently.
  void _ears(Canvas canvas, Offset head, double r) {
    final sway = math.sin(idle * math.pi) * (r * 0.04) +
        (mood == BoboMood.excited
            ? math.sin(idle * math.pi * 2) * (r * 0.04)
            : 0);
    for (final s in [-1.0, 1.0]) {
      canvas.save();
      // Sit the ear over the top-outer edge of the head, pushed outward so it
      // frames the face rather than covering the eyes.
      final anchor = head.translate(s * r * 0.92, -r * 0.52);
      canvas.translate(anchor.dx, anchor.dy);
      canvas.rotate(s * 0.42);

      // Plump lobe: starts narrow at the top attachment, bulges wide, and
      // rounds off at a soft drooping tip beside the cheek.
      final w = r * 0.66; // ear width
      final len = r * 1.12; // ear length
      final lobe = Path()
        ..moveTo(0, 0)
        // outer edge bows out then curves in to the tip
        ..cubicTo(s * w * 0.95, len * 0.12, s * w * 0.92, len * 0.78,
            s * w * 0.40, len + sway)
        // rounded fluffy tip
        ..cubicTo(s * w * 0.10, len * 1.08 + sway, -s * w * 0.28, len * 0.98 + sway,
            -s * w * 0.30, len * 0.72 + sway)
        // inner edge back up to the attachment, hugging the head
        ..cubicTo(-s * w * 0.32, len * 0.34, -s * w * 0.10, len * 0.10,
            0, 0)
        ..close();

      canvas.drawPath(
          lobe,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = _ow(r) * 0.95
            ..strokeJoin = StrokeJoin.round);
      canvas.drawPath(lobe, Paint()..color = _ear);

      // Inner-ear shade, a smaller nested lobe for soft depth.
      final inner = Path()
        ..moveTo(s * w * 0.06, len * 0.14)
        ..cubicTo(s * w * 0.62, len * 0.26, s * w * 0.58, len * 0.72,
            s * w * 0.26, len * 0.86 + sway)
        ..cubicTo(s * w * 0.06, len * 0.92 + sway, -s * w * 0.10, len * 0.74 + sway,
            -s * w * 0.10, len * 0.44)
        ..cubicTo(-s * w * 0.08, len * 0.26, s * w * 0.0, len * 0.18,
            s * w * 0.06, len * 0.14)
        ..close();
      canvas.drawPath(inner, Paint()..color = _earShade);
      canvas.restore();
    }
  }

  void _headShape(Canvas canvas, Offset head, double r) {
    // Slightly wide, soft head — a rounded superellipse-ish blob.
    final rect = Rect.fromCenter(
        center: head, width: r * 2.1, height: r * 1.95);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.95)));
    _strokeFill(canvas, path, _coat, r, gradientCenter: const Alignment(-0.2, -0.35));
  }

  void _face(Canvas canvas, Offset c, double r) {
    final eyeDx = r * 0.44;
    final eyeY = c.dy + r * 0.02;
    final leftEye = Offset(c.dx - eyeDx, eyeY);
    final rightEye = Offset(c.dx + eyeDx, eyeY);

    // One soft eye-patch (left) — cute asymmetric marking.
    canvas.save();
    canvas.translate(leftEye.dx, leftEye.dy);
    canvas.rotate(-0.2);
    canvas.translate(-leftEye.dx, -leftEye.dy);
    canvas.drawOval(
      Rect.fromCenter(
          center: leftEye.translate(-r * 0.02, r * 0.04),
          width: r * 0.52,
          height: r * 0.62),
      Paint()..color = _patch.withValues(alpha: 0.9),
    );
    canvas.restore();

    _eye(canvas, leftEye, r);
    _eye(canvas, rightEye, r);

    // Blush.
    for (final s in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(s * r * 0.70, r * 0.34),
            width: r * 0.30,
            height: r * 0.18),
        Paint()..color = _blush.withValues(alpha: 0.8),
      );
    }

    _snout(canvas, c, r);
  }

  void _eye(Canvas canvas, Offset eye, double r) {
    final openH = r * 0.34; // big Duo-style eyes
    final closed = blink;
    final curH = openH * (1 - closed);

    if (mood == BoboMood.sleepy || closed > 0.9) {
      canvas.drawPath(
        Path()
          ..moveTo(eye.dx - r * 0.17, eye.dy)
          ..quadraticBezierTo(
              eye.dx, eye.dy + r * 0.15, eye.dx + r * 0.17, eye.dy),
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    // Big glossy eye.
    canvas.drawOval(
      Rect.fromCenter(
          center: eye, width: r * 0.30, height: curH.clamp(0.5, openH)),
      Paint()..color = _ink,
    );
    if (closed < 0.4) {
      canvas.drawCircle(eye.translate(-r * 0.05, -r * 0.07), r * 0.06,
          Paint()..color = Colors.white);
      canvas.drawCircle(eye.translate(r * 0.05, r * 0.04), r * 0.028,
          Paint()..color = Colors.white.withValues(alpha: 0.75));
    }
  }

  /// Nose + a small, clean, closed happy smile (no lolling tongue).
  void _snout(Canvas canvas, Offset c, double r) {
    final nose = c.translate(0, r * 0.34);
    final nw = r * 0.16, nh = r * 0.12;
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
          width: r * 0.06,
          height: r * 0.04),
      Paint()..color = Colors.white,
    );

    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (mood == BoboMood.sleepy) {
      // tiny content mouth
      final m = nose.translate(0, r * 0.16);
      canvas.drawLine(nose.translate(0, nh), m, line);
      canvas.drawArc(
          Rect.fromCenter(center: m, width: r * 0.12, height: r * 0.08),
          0, math.pi, false, line);
      return;
    }

    // Happy/excited: gentle muzzle line into a soft "w" smile — the classic
    // cute-dog mouth, closed (no tongue).
    final top = nose.translate(0, nh);
    final mid = nose.translate(0, r * 0.14);
    canvas.drawLine(top, mid, line);
    final spread = r * (mood == BoboMood.excited ? 0.26 : 0.22);
    final drop = r * (mood == BoboMood.excited ? 0.14 : 0.11);
    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(mid.dx, mid.dy)
          ..quadraticBezierTo(
              mid.dx + s * spread * 0.5, mid.dy + drop,
              mid.dx + s * spread, mid.dy + drop * 0.15),
        line,
      );
    }
  }

  void _moodBadge(Canvas canvas, Offset head, double r) {
    final float = math.sin(idle * math.pi * 2) * (r * 0.05);
    final anchor = head.translate(r * 1.05, -r * 0.95 + float);
    switch (mood) {
      case BoboMood.happy:
        _boneBadge(canvas, anchor, r * 0.30);
      case BoboMood.excited:
        _star(canvas, anchor, r * 0.14, _excitedYellow);
        _star(canvas, anchor.translate(r * 0.22, r * 0.30), r * 0.08,
            _excitedYellow.withValues(alpha: 0.85));
      case BoboMood.sleepy:
        final tp = TextPainter(
          text: TextSpan(
              text: 'z',
              style: TextStyle(
                  color: _ink.withValues(alpha: 0.6),
                  fontSize: r * 0.28,
                  fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, anchor);
        tp.paint(canvas, anchor.translate(r * 0.22, -r * 0.20));
      default:
        // Action moods resolve to a base expression before reaching the
        // fallback painter, so this is unreachable — draw the happy badge.
        _boneBadge(canvas, anchor, r * 0.30);
    }
  }

  void _boneBadge(Canvas canvas, Offset c, double len) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.5 + math.sin(idle * math.pi) * 0.1);
    final fill = Paint()..color = _bone;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = len * 0.09;
    final knob = len * 0.17;
    final shaft = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: len, height: len * 0.24),
        Radius.circular(len * 0.12));
    canvas.drawRRect(shaft, fill);
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(sx * len * 0.5, sy * knob * 0.9), knob, fill);
      }
    }
    canvas.drawRRect(shaft, line);
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(sx * len * 0.5, sy * knob * 0.9), knob, line);
      }
    }
    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double radius, Color color) {
    final path = Path();
    const pts = 4;
    for (var i = 0; i < pts * 2; i++) {
      final rr = i.isEven ? radius : radius * 0.4;
      final a = (i / (pts * 2)) * math.pi * 2 - math.pi / 2;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Stroke a bold outline then fill with the cream coat + faint roundness.
  void _strokeFill(Canvas canvas, Path path, Color fill, double r,
      {Alignment gradientCenter = Alignment.topCenter}) {
    canvas.drawPath(
        path,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ow(r)
          ..strokeJoin = StrokeJoin.round);
    final b = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: gradientCenter,
          radius: 1.1,
          colors: const [_coat, _coatShade],
        ).createShader(b),
    );
  }

  @override
  bool shouldRepaint(_BoboPainter old) =>
      old.idle != idle ||
      old.wag != wag ||
      old.blink != blink ||
      old.poke != poke ||
      old.mood != mood;
}
