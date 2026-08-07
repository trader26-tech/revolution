import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/widgets/mascot.dart';

void main() {
  test('render mascot to png', () async {
    const size = 320.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // dark space background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFF100B20),
    );
    // Mascot is a StatelessWidget; grab its painter via a boundary paint.
    // Easiest: use the public Mascot painter through a RenderBox is overkill —
    // instead re-instantiate the CustomPainter by painting the widget's layer.
    // We just call the painter through a CustomPaint we build manually.
    final painter = _mascotPainter();
    painter(canvas, const Size(size, size));
    final pic = recorder.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/07963e43-a804-4357-8f20-d76d2d993533/scratchpad/mascot.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// The painter is private, so render via the widget into an image using a
// simple layer capture through PaintingContext is complex. Fall back to
// pumping the widget instead.
void Function(Canvas, Size) _mascotPainter() {
  throw UnimplementedError();
}
