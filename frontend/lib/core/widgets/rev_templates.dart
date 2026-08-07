import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mascot.dart';

/// Rev's pose/mood template library.
///
/// The base [Mascot] gives us the character and its live handles (blink, look,
/// squash, tilt). This file turns those handles into a set of ready-to-use,
/// fully-animated POSES — drop one anywhere with:
///
/// ```dart
/// Rev(pose: RevPose.notes, size: 220)                       // taking notes
/// Rev(pose: RevPose.happy, size: 160, facing: RevFacing.left)
/// ```
///
/// Every pose loops forever on its own; nothing else to wire up. `facing`
/// mirrors him so he can sit on the left or right edge of a layout and lean
/// into the content.
enum RevPose {
  /// The default life: breathing, wandering gaze, double-blinks.
  idle,

  /// Scribbling on a little floating notepad — "I'm writing this down for you."
  /// Great beside forms, onboarding capture steps, or while saving.
  notes,

  /// Bouncy, smiling-eyed joy. For success moments and warm greetings.
  happy,

  /// Drooped, teary, gaze down. For empty/error states that need sympathy.
  sad,

  /// The big win: confetti burst + jumps. For "all done!" payoffs.
  celebrate,

  /// Gazing up with thought dots. For loading / "working on it" moments.
  thinking,

  /// Heavy lids, slow breathing, floating z z z. For night / quiet hours.
  sleepy,

  /// Wide-eyed with a bouncing "!" — something needs attention.
  alert,

  /// Hearts drifting up. For thank-yous, ratings, and delight beats.
  love,
}

/// Which way Rev faces. [right] is his natural side (tail bottom-right);
/// [left] mirrors him for placement on the right edge of a layout.
enum RevFacing { right, left }

extension RevPoseInfo on RevPose {
  String get label => switch (this) {
        RevPose.idle => 'Idle',
        RevPose.notes => 'Taking notes',
        RevPose.happy => 'Happy',
        RevPose.sad => 'Sad',
        RevPose.celebrate => 'Celebrate',
        RevPose.thinking => 'Thinking',
        RevPose.sleepy => 'Sleepy',
        RevPose.alert => 'Heads up',
        RevPose.love => 'Love',
      };

  String get hint => switch (this) {
        RevPose.idle => 'Anywhere he just hangs out',
        RevPose.notes => 'Forms, capture steps, saving',
        RevPose.happy => 'Success + greetings',
        RevPose.sad => 'Empty & error states',
        RevPose.celebrate => 'Big payoffs, all done!',
        RevPose.thinking => 'Loading, working on it',
        RevPose.sleepy => 'Night, quiet hours',
        RevPose.alert => 'Something needs attention',
        RevPose.love => 'Thank-yous & delight',
      };
}

/// One self-contained animated Rev in a given [pose].
class Rev extends StatefulWidget {
  const Rev({
    super.key,
    required this.pose,
    required this.size,
    this.facing = RevFacing.right,
    this.glow = true,
  });

  final RevPose pose;
  final double size;
  final RevFacing facing;
  final bool glow;

  @override
  State<Rev> createState() => _RevState();
}

class _RevState extends State<Rev> with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  static Duration _durationOf(RevPose pose) => switch (pose) {
        RevPose.idle => const Duration(milliseconds: 5200),
        RevPose.notes => const Duration(milliseconds: 3800),
        RevPose.happy => const Duration(milliseconds: 2400),
        RevPose.sad => const Duration(milliseconds: 5600),
        RevPose.celebrate => const Duration(milliseconds: 2600),
        RevPose.thinking => const Duration(milliseconds: 3400),
        RevPose.sleepy => const Duration(milliseconds: 4800),
        RevPose.alert => const Duration(milliseconds: 2200),
        RevPose.love => const Duration(milliseconds: 3600),
      };

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: _durationOf(widget.pose))
      ..repeat();
  }

  @override
  void didUpdateWidget(Rev old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) {
      _loop
        ..duration = _durationOf(widget.pose)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mirrored = widget.facing == RevFacing.left;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final f = _RevFrame.of(widget.pose, _loop.value);
          // The base body: flipped for facing; look/tilt pre-negated so the
          // SCREEN-space gaze and lean stay what the pose intends.
          final body = Transform.translate(
            offset: Offset(0, f.dy * widget.size),
            child: Transform.flip(
              flipX: mirrored,
              child: Mascot(
                size: widget.size,
                blink: f.blink,
                look: Offset(mirrored ? -f.look.dx : f.look.dx, f.look.dy),
                squash: f.squash,
                tilt: mirrored ? -f.tilt : f.tilt,
                glow: widget.glow,
              ),
            ),
          );
          return Stack(
            clipBehavior: Clip.none, // particles may float past the box
            fit: StackFit.expand,
            children: [
              body,
              CustomPaint(
                painter: _RevOverlayPainter(
                  pose: widget.pose,
                  t: _loop.value,
                  frame: f,
                  dir: mirrored ? -1 : 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The computed pose state for one moment of the loop.
class _RevFrame {
  const _RevFrame({
    this.blink = 0,
    this.look = Offset.zero,
    this.squash = 0,
    this.tilt = 0,
    this.dy = 0,
  });

  final double blink;
  final Offset look; // screen-space
  final double squash;
  final double tilt; // screen-space
  final double dy; // vertical bob, fraction of size

  /// A quick eye-close spike centred at loop-time [at].
  static double _spike(double t, double at, [double w = 0.022]) {
    final d = (t - at).abs();
    return d > w ? 0 : 1 - (d / w);
  }

  static double _sin(double t, [double phase = 0]) =>
      math.sin(t * 2 * math.pi + phase);

  static _RevFrame of(RevPose pose, double t) {
    switch (pose) {
      case RevPose.idle:
        final breath = _sin(t);
        return _RevFrame(
          blink: (_spike(t, 0.36) + _spike(t, 0.43) + _spike(t, 0.82))
              .clamp(0.0, 1.0),
          look: Offset(-0.42 + _sin(t, 1.2) * 0.22,
              math.cos(t * 4 * math.pi + 0.4) * 0.15),
          squash: breath * 0.05,
          tilt: _sin(t, 2.1) * 0.03,
          dy: breath * 0.03,
        );

      case RevPose.notes:
        // Three written lines (0–.78), a glance up at you (.78–.90), then the
        // page wipes for a fresh start (.90–1). The gaze tracks the pencil.
        final writing = t < 0.78;
        double lookX, lookY;
        if (writing) {
          final p = (t % 0.26) / 0.26; // progress along the current line
          lookX = -0.75 + p * 0.40;
          lookY = 0.75;
        } else if (t < 0.90) {
          lookX = -0.05;
          lookY = -0.05; // up at the viewer: "got it."
        } else {
          lookX = -0.55;
          lookY = 0.60; // back down for the fresh page
        }
        return _RevFrame(
          blink:
              (_spike(t, 0.79) + _spike(t, 0.30)).clamp(0.0, 1.0),
          look: Offset(lookX, lookY),
          squash: _sin(t) * 0.03,
          tilt: -0.06 + _sin(t * 2) * 0.012,
          dy: _sin(t) * 0.012,
        );

      case RevPose.happy:
        // Two springy hops per loop; smiling-arc eyes (drawn in the overlay).
        final u = (t * 2) % 1;
        return _RevFrame(
          blink: 1, // base eyes shut → overlay draws the happy ∩∩ arcs
          look: Offset.zero,
          squash: 0.09 * math.cos(2 * math.pi * u),
          tilt: _sin(t) * 0.05,
          dy: -0.055 * math.sin(math.pi * u),
        );

      case RevPose.sad:
        return _RevFrame(
          blink: 0.12 + _spike(t, 0.48, 0.05) * 0.4,
          look: Offset(-0.10, 0.62 + _sin(t) * 0.05),
          squash: -0.03 + _sin(t) * 0.02,
          tilt: 0.07 + _sin(t) * 0.012,
          dy: 0.02 + _sin(t) * 0.008,
        );

      case RevPose.celebrate:
        // One big launch hop, then two little landing bounces.
        double dy, squash;
        if (t < 0.32) {
          final u = t / 0.32;
          dy = -0.11 * math.sin(math.pi * u);
          squash = 0.12 * math.cos(math.pi * u * 2);
        } else {
          final u = (t - 0.32) / 0.68;
          dy = -0.028 * math.sin(2 * math.pi * u).abs() * (1 - u);
          squash = 0.05 * math.cos(4 * math.pi * u) * (1 - u);
        }
        return _RevFrame(
          blink: 1,
          look: Offset.zero,
          squash: squash,
          tilt: _sin(t * 2) * 0.06,
          dy: dy,
        );

      case RevPose.thinking:
        return _RevFrame(
          blink: (_spike(t, 0.62) + _spike(t, 0.66)).clamp(0.0, 1.0),
          look: Offset(-0.50 + _sin(t) * 0.06, -0.45),
          squash: _sin(t) * 0.03,
          tilt: 0.06,
          dy: _sin(t) * 0.015,
        );

      case RevPose.sleepy:
        return _RevFrame(
          blink: 0.85 + _sin(t) * 0.07,
          look: const Offset(-0.05, 0.35),
          squash: _sin(t) * 0.08,
          tilt: 0.05 + _sin(t, 1.0) * 0.02,
          dy: _sin(t) * 0.03,
        );

      case RevPose.alert:
        // Two quick startled hops, then attentive stillness.
        final hop = t < 0.35
            ? -0.05 * math.sin(2 * math.pi * (t / 0.35)).abs()
            : 0.0;
        final shiver = math.sin(t * 30 * math.pi) *
            0.02 *
            math.exp(-t * 6); // a brief startled tremble
        return _RevFrame(
          blink: _spike(t, 0.55),
          look: const Offset(0, -0.15),
          squash: t < 0.35 ? 0.06 * math.cos(2 * math.pi * (t / 0.35)) : 0.0,
          tilt: shiver,
          dy: hop,
        );

      case RevPose.love:
        return _RevFrame(
          blink: 1,
          look: Offset.zero,
          squash: _sin(t * 2) * 0.03,
          tilt: _sin(t) * 0.05,
          dy: _sin(t) * 0.02,
        );
    }
  }
}

// ── The overlay: expressions + props ─────────────────────────────────────────

class _RevOverlayPainter extends CustomPainter {
  const _RevOverlayPainter({
    required this.pose,
    required this.t,
    required this.frame,
    required this.dir,
  });

  final RevPose pose;
  final double t;
  final _RevFrame frame;

  /// +1 facing right (natural), −1 mirrored to face left. Asymmetric props
  /// multiply their x by this so they land on the balancing side.
  final int dir;

  // The mascot's palette (kept in sync with mascot.dart).
  static const _pink = Color(0xFFF7A8D8);
  static const _mint = Color(0xFF7FE8DA);
  static const _periwinkle = Color(0xFFA5B4FC);
  static const _lavender = Color(0xFFC4B5FD);
  static const _ink = Color(0xFF16181C);
  static const _accent = Color(0xFF7C5CFC);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);

    // Face decor rides the head: same bob/tilt/squash transform as the body.
    void withFace(void Function(Canvas, double) draw) {
      canvas.save();
      canvas.translate(c.dx, c.dy + frame.dy * s);
      canvas.rotate(frame.tilt);
      canvas.scale(1 + frame.squash * 0.5, 1 - frame.squash * 0.5);
      draw(canvas, s);
      canvas.restore();
    }

    // Props float in world space around him (they still share his ground).
    void withWorld(void Function(Canvas, double) draw) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      draw(canvas, s);
      canvas.restore();
    }

    switch (pose) {
      case RevPose.idle:
        break;

      case RevPose.notes:
        withWorld(_notepad);
        break;

      case RevPose.happy:
        withFace((cv, s) {
          _happyArcs(cv, s);
          _smile(cv, s, open: false);
          _blush(cv, s);
        });
        withWorld((cv, s) {
          _sparkle(cv, s, Offset(-s * 0.38 * dir, -s * 0.26), phase: 0.0);
          _sparkle(cv, s, Offset(s * 0.42 * dir, -s * 0.10), phase: 0.5);
        });
        break;

      case RevPose.sad:
        withFace((cv, s) {
          _sadBrows(cv, s);
          _frown(cv, s);
          _tear(cv, s);
        });
        break;

      case RevPose.celebrate:
        withFace((cv, s) {
          _happyArcs(cv, s);
          _smile(cv, s, open: true);
        });
        withWorld(_confetti);
        break;

      case RevPose.thinking:
        withWorld(_thoughtDots);
        break;

      case RevPose.sleepy:
        withWorld(_zzz);
        break;

      case RevPose.alert:
        withWorld(_alertMark);
        break;

      case RevPose.love:
        withFace((cv, s) {
          _happyArcs(cv, s);
          _smile(cv, s, open: false);
          _blush(cv, s);
        });
        withWorld(_hearts);
        break;
    }
  }

  // ── Face pieces (drawn in head space) ─────────────────────────────────────

  /// Happy ∩∩ eyes. The base eyes are shut to slivers (blink = 1); we hide the
  /// slivers under soft white patches, then draw the arcs.
  void _happyArcs(Canvas canvas, double s) {
    final patch = Paint()
      ..color = Colors.white
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.010);
    final arc = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.034
      ..strokeCap = StrokeCap.round;

    for (final side in const [-1, 1]) {
      final eye = Offset(side * s * 0.125, -s * 0.150);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(eye.dx, -s * 0.140), width: s * 0.15, height: s * 0.05),
        patch,
      );
      canvas.drawArc(
        Rect.fromCircle(center: eye, radius: s * 0.060),
        math.pi, // start at the left…
        math.pi, // …sweep over the top
        false,
        arc,
      );
    }
  }

  void _smile(Canvas canvas, double s, {required bool open}) {
    if (open) {
      // A joyful open mouth: a filled half-round.
      final r = s * 0.052;
      final rect = Rect.fromCircle(center: Offset(0, -s * 0.045), radius: r);
      canvas.drawArc(rect, 0, math.pi, true, Paint()..color = _ink);
    } else {
      final smile = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.020
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(0, -s * 0.065), radius: s * 0.045),
        math.pi * 0.15,
        math.pi * 0.70,
        false,
        smile,
      );
    }
  }

  void _frown(Canvas canvas, double s) {
    final frown = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -s * 0.010), radius: s * 0.038),
      math.pi * 1.18,
      math.pi * 0.64,
      false,
      frown,
    );
  }

  void _sadBrows(Canvas canvas, double s) {
    final brow = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1, 1]) {
      // Inner ends lifted — the classic worried slant.
      final outer = Offset(side * s * 0.185, -s * 0.285);
      final inner = Offset(side * s * 0.065, -s * 0.320);
      canvas.drawLine(outer, inner, brow);
    }
  }

  void _blush(Canvas canvas, double s) {
    final blush = Paint()
      ..color = _pink.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.020);
    for (final side in const [-1, 1]) {
      canvas.drawCircle(Offset(side * s * 0.215, -s * 0.055), s * 0.045, blush);
    }
  }

  /// One tear: wells up at the inner corner, slides down, fades.
  void _tear(Canvas canvas, double s) {
    // Cycle: grow 0–.35, slide .35–.75, gone .75–1.
    final double grow, slide, fade;
    if (t < 0.35) {
      grow = t / 0.35;
      slide = 0;
      fade = 1;
    } else if (t < 0.75) {
      grow = 1;
      slide = (t - 0.35) / 0.40;
      fade = 1;
    } else {
      return;
    }
    final r = s * 0.030 * (0.4 + grow * 0.6);
    final y = -s * 0.095 + slide * s * 0.22;
    final x = dir * -s * 0.085;
    final tearPaint = Paint()
      ..color = _periwinkle.withValues(alpha: 0.95 * fade);
    // A droplet: circle + a little point on top.
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, y), radius: r))
      ..moveTo(x - r * 0.55, y - r * 0.5)
      ..quadraticBezierTo(x, y - r * 2.0, x + r * 0.55, y - r * 0.5)
      ..close();
    canvas.drawPath(path, tearPaint);
    canvas.drawCircle(
      Offset(x - r * 0.3, y - r * 0.2),
      r * 0.25,
      Paint()..color = Colors.white.withValues(alpha: 0.7 * fade),
    );
  }

  // ── Props (drawn in world space) ──────────────────────────────────────────

  /// The floating notepad + pencil, with lines that actually get written.
  void _notepad(Canvas canvas, double s) {
    canvas.save();
    // The pad sits low on his gaze side, gently tilted toward him.
    canvas.translate(dir * -s * 0.315, s * 0.315);
    canvas.rotate(dir * -0.10);

    final w = s * 0.34, h = s * 0.26;
    final pad = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(s * 0.035),
    );
    // Soft shadow, paper, and a pastel binding strip on top.
    canvas.drawRRect(
      pad.shift(Offset(0, s * 0.012)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );
    canvas.drawRRect(pad, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(pad);
    canvas.drawRect(
      Rect.fromLTWH(-w / 2, -h / 2, w, s * 0.045),
      Paint()..color = _lavender.withValues(alpha: 0.55),
    );
    canvas.restore();

    // Written lines: line i lives in t ∈ [i·0.26, i·0.26+0.26); each draws
    // left → right with a hand-wobble; all fade out during the page wipe.
    final ink = Paint()
      ..color = _ink.withValues(alpha: t >= 0.90 ? (1 - (t - 0.90) / 0.10) : 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;
    final startX = -w * 0.36, endX = w * 0.38;
    Offset penTip = Offset(startX, -h * 0.16);
    for (var i = 0; i < 3; i++) {
      final lineT = ((t - i * 0.26) / 0.26).clamp(0.0, 1.0);
      if (t >= 0.90 || lineT <= 0) continue;
      final y = -h * 0.16 + i * h * 0.24;
      final p = Path()..moveTo(startX, y);
      final steps = (14 * lineT).ceil();
      for (var k = 1; k <= steps; k++) {
        final u = (k / 14).clamp(0.0, lineT);
        final x = startX + (endX - startX) * u;
        p.lineTo(x, y + math.sin(u * 26 + i * 2.0) * s * 0.008);
      }
      canvas.drawPath(p, ink);
      if (lineT < 1) {
        penTip = Offset(
          startX + (endX - startX) * lineT,
          y + math.sin(lineT * 26 + i * 2.0) * s * 0.008,
        );
      }
    }

    // The pencil, writing at the tip (parked mid-pad during the glance/wipe).
    final writing = t < 0.78;
    if (!writing) penTip = Offset(w * 0.10, h * 0.05);
    _pencil(canvas, s, penTip, wiggle: writing);
    canvas.restore();
  }

  void _pencil(Canvas canvas, double s, Offset tip, {required bool wiggle}) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(-0.62 + (wiggle ? math.sin(t * 44 * math.pi) * 0.05 : 0));

    final len = s * 0.185, wdt = s * 0.040;
    // Lead, wooden collar, body, eraser — tip at the origin, body running up.
    final lead = Path()
      ..moveTo(0, 0)
      ..lineTo(-wdt * 0.22, -s * 0.022)
      ..lineTo(wdt * 0.22, -s * 0.022)
      ..close();
    canvas.drawPath(lead, Paint()..color = _ink);
    final collar = Path()
      ..moveTo(-wdt * 0.5, -s * 0.052)
      ..lineTo(0, 0)
      ..lineTo(wdt * 0.5, -s * 0.052)
      ..close();
    canvas.drawPath(collar, Paint()..color = const Color(0xFFFFE3B3));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-wdt / 2, -s * 0.052 - len, wdt, len),
        Radius.circular(wdt * 0.3),
      ),
      Paint()..color = _accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-wdt / 2, -s * 0.052 - len - s * 0.026, wdt, s * 0.026),
        Radius.circular(wdt * 0.3),
      ),
      Paint()..color = _pink,
    );
    canvas.restore();
  }

  void _sparkle(Canvas canvas, double s, Offset at, {required double phase}) {
    // Twinkle: scale pulses out of phase so the two stars alternate.
    final tw = (math.sin((t + phase) * 2 * math.pi * 2) + 1) / 2;
    if (tw < 0.15) return;
    final r = s * 0.045 * (0.5 + tw * 0.5);
    final paint = Paint()..color = _lavender.withValues(alpha: 0.5 + tw * 0.5);
    canvas.drawPath(_star(at, r), paint);
  }

  void _confetti(Canvas canvas, double s) {
    const colors = [_pink, _mint, _periwinkle, _lavender, _accent];
    // Launch just after the hop starts; particles fly a fan, arc, and fade.
    final ta = ((t - 0.10) / 0.90).clamp(0.0, 1.0);
    if (ta <= 0) return;
    for (var i = 0; i < 12; i++) {
      final h = _hash(i.toDouble());
      final angle = -math.pi * (0.20 + 0.60 * h); // upward fan
      final speed = s * (0.55 + 0.5 * _hash(i + 7.0));
      final g = s * 1.35;
      final x = math.cos(angle) * speed * ta;
      final y = -s * 0.30 + math.sin(angle) * speed * ta + 0.5 * g * ta * ta;
      final fade = (1 - ta) * 1.6;
      if (fade <= 0) continue;
      final paint = Paint()
        ..color = colors[i % colors.length]
            .withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(ta * math.pi * 4 * (h - 0.5) * 2);
      final r = s * (0.018 + 0.014 * _hash(i + 13.0));
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, r * 0.8, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.2),
            Radius.circular(r * 0.3),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _thoughtDots(Canvas canvas, double s) {
    // Three dots pop in along his up-gaze diagonal, then all fade together.
    final fadeOut = t > 0.82 ? (1 - (t - 0.82) / 0.18) : 1.0;
    final spots = [
      (Offset(dir * -s * 0.30, -s * 0.345), s * 0.017, 0.14),
      (Offset(dir * -s * 0.375, -s * 0.435), s * 0.023, 0.30),
      (Offset(dir * -s * 0.44, -s * 0.535), s * 0.030, 0.46),
    ];
    for (final (at, r, born) in spots) {
      final pop = ((t - born) / 0.10).clamp(0.0, 1.0);
      if (pop <= 0) continue;
      final scale = Curves.easeOutBack.transform(pop);
      canvas.drawCircle(
        at,
        r * scale,
        Paint()..color = _lavender.withValues(alpha: 0.9 * fadeOut),
      );
    }
  }

  void _zzz(Canvas canvas, double s) {
    // Three z's rise from the crown, growing and fading, staggered thirds.
    for (var i = 0; i < 3; i++) {
      final zt = ((t + 1 - i * 0.33) % 1.0);
      final rise = zt; // 0 → 1 over its life
      final alpha = rise < 0.15
          ? rise / 0.15
          : rise > 0.75
              ? (1 - rise) / 0.25
              : 1.0;
      if (alpha <= 0) continue;
      final at = Offset(
        dir * s * (0.17 + rise * 0.17),
        -s * (0.30 + rise * 0.24),
      );
      final zSize = s * (0.030 + rise * 0.030);
      final paint = Paint()
        ..color = _periwinkle.withValues(alpha: 0.9 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final p = Path()
        ..moveTo(at.dx - zSize, at.dy - zSize)
        ..lineTo(at.dx + zSize, at.dy - zSize)
        ..lineTo(at.dx - zSize, at.dy + zSize)
        ..lineTo(at.dx + zSize, at.dy + zSize);
      canvas.drawPath(p, paint);
    }
  }

  void _alertMark(Canvas canvas, double s) {
    // The "!" pops in with a spring, hovers with a bounce, dips out at the end.
    final pop = Curves.elasticOut.transform(((t - 0.04) / 0.30).clamp(0.0, 1.0));
    final out = t > 0.88 ? 1 - (t - 0.88) / 0.12 : 1.0;
    final scale = pop * out;
    if (scale <= 0.01) return;
    final bounce = math.sin(t * 6 * math.pi) * s * 0.012;

    canvas.save();
    canvas.translate(dir * s * 0.02, -s * 0.44 + bounce);
    canvas.scale(scale);
    // A soft glow so it reads on the dark sky.
    final glow = Paint()
      ..color = _accent.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.035);
    canvas.drawCircle(Offset(0, -s * 0.02), s * 0.085, glow);
    final mark = Paint()..color = _accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, -s * 0.045), width: s * 0.048, height: s * 0.115),
        Radius.circular(s * 0.024),
      ),
      mark,
    );
    canvas.drawCircle(Offset(0, s * 0.055), s * 0.027, mark);
    canvas.restore();
  }

  void _hearts(Canvas canvas, double s) {
    const tints = [_pink, _lavender, _pink];
    for (var i = 0; i < 3; i++) {
      final ht = ((t + 1 - i * 0.33) % 1.0);
      final alpha = ht < 0.15
          ? ht / 0.15
          : ht > 0.70
              ? (1 - ht) / 0.30
              : 1.0;
      if (alpha <= 0) continue;
      final side = i.isEven ? 1 : -1;
      final at = Offset(
        dir * side * s * (0.30 + _hash(i + 3.0) * 0.10) +
            math.sin(ht * 3 * math.pi + i) * s * 0.04,
        s * 0.05 - ht * s * 0.55,
      );
      final r = s * (0.040 + _hash(i + 9.0) * 0.020) * (0.6 + ht * 0.4);
      canvas.drawPath(
        _heart(at, r),
        Paint()..color = tints[i].withValues(alpha: 0.95 * alpha),
      );
    }
  }

  // ── Tiny shape + noise helpers ────────────────────────────────────────────

  static Path _star(Offset c, double r) {
    final w = r * 0.16; // waist — how pinched the sparkle is
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
  }

  static Path _heart(Offset c, double r) {
    return Path()
      ..moveTo(c.dx, c.dy + r * 0.62)
      ..cubicTo(c.dx - r * 1.05, c.dy - r * 0.10, c.dx - r * 0.62,
          c.dy - r * 1.0, c.dx, c.dy - r * 0.38)
      ..cubicTo(c.dx + r * 0.62, c.dy - r * 1.0, c.dx + r * 1.05,
          c.dy - r * 0.10, c.dx, c.dy + r * 0.62)
      ..close();
  }

  /// Deterministic pseudo-random in 0..1 (stable per particle index).
  static double _hash(double n) {
    final x = math.sin(n * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(_RevOverlayPainter old) =>
      old.t != t || old.pose != pose || old.dir != dir;
}
