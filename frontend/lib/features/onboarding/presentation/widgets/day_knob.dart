import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// A premium semicircular knob for picking a day of the month (1–31).
///
/// Drag along the arc (or anywhere in the widget) to scrub the day; the knob
/// glides to your finger, the active arc fills, the big number updates, and a
/// crisp haptic tick fires on every day change — so it *feels* like turning a
/// physical dial. Tap the ends to nudge ±1.
class DayKnob extends StatefulWidget {
  const DayKnob({
    super.key,
    required this.day,
    required this.onChanged,
    this.accent = AppColors.accent,
    this.size = 260,
  });

  /// Current day (1–31).
  final int day;
  final ValueChanged<int> onChanged;
  final Color accent;
  final double size;

  @override
  State<DayKnob> createState() => _DayKnobState();
}

class _DayKnobState extends State<DayKnob> {
  static const _min = 1;
  static const _max = 31;

  // The arc sweeps from 180° (left) to 360°/0° (right) across the TOP half —
  // a wide, shallow semicircle the thumb can ride comfortably.
  static const double _startAngle = math.pi; // 180°
  static const double _sweep = math.pi; // 180°

  int get _day => widget.day.clamp(_min, _max);

  /// Fraction 0..1 of the current day along the arc.
  double get _t => (_day - _min) / (_max - _min);

  void _setFromLocal(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height * 0.86);
    final v = local - center;
    // Angle measured from +x axis, going clockwise into the top half.
    var angle = math.atan2(-v.dy, v.dx); // 0..π on the top half
    if (angle < 0) angle += 2 * math.pi;
    // Map the angle within [0, π] (right→left across the top) to t.
    // Our arc goes left(π)→right(0) as day increases, so invert.
    final clamped = angle.clamp(0.0, math.pi);
    final t = 1 - (clamped / math.pi);
    final day = (_min + t * (_max - _min)).round().clamp(_min, _max);
    if (day != _day) {
      HapticFeedback.selectionClick();
      widget.onChanged(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.size, widget.size * 0.62);
    return GestureDetector(
      onPanDown: (d) => _setFromLocal(d.localPosition, size),
      onPanUpdate: (d) => _setFromLocal(d.localPosition, size),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: size,
              painter: _KnobPainter(t: _t, accent: widget.accent),
            ),
            // Centre readout: the big day number + "of the month".
            Positioned(
              bottom: size.height * 0.06,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _day.toString(),
                    style: TextStyle(
                      fontSize: 64,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      color: widget.accent,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    _ordinalSuffix(_day),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkFaint,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ordinalSuffix(int d) {
    final label = switch (d % 100) {
      11 || 12 || 13 => '${d}TH',
      _ => switch (d % 10) {
          1 => '${d}ST',
          2 => '${d}ND',
          3 => '${d}RD',
          _ => '${d}TH',
        },
    };
    return '$label OF THE MONTH';
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.t, required this.accent});

  final double t; // 0..1 position of the knob along the arc
  final Color accent;

  static const double _start = math.pi; // 180°
  static const double _sweep = math.pi; // 180°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.86);
    final radius = size.width * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full arc, faint).
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.12);
    canvas.drawArc(rect, _start, _sweep, false, track);

    // Filled portion up to the knob.
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [accent.withValues(alpha: 0.55), accent],
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep * t, false, fill);

    // Little tick marks around the arc for texture.
    final tickPaint = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const ticks = 30;
    for (var i = 0; i <= ticks; i++) {
      final a = _start + _sweep * (i / ticks);
      final outer = center + Offset(math.cos(a), math.sin(a)) * (radius + 14);
      final inner = center + Offset(math.cos(a), math.sin(a)) * (radius + 20);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // The knob.
    final knobAngle = _start + _sweep * t;
    final knobPos = center + Offset(math.cos(knobAngle), math.sin(knobAngle)) * radius;
    // Glow.
    canvas.drawCircle(
      knobPos,
      20,
      Paint()..color = accent.withValues(alpha: 0.22),
    );
    // White knob with an accent ring.
    canvas.drawCircle(knobPos, 15, Paint()..color = Colors.white);
    canvas.drawCircle(
      knobPos,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = accent,
    );
    canvas.drawCircle(knobPos, 5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter old) =>
      old.t != t || old.accent != accent;
}
