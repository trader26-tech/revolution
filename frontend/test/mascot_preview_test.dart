import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/widgets/mascot.dart';

void main() {
  testWidgets('render mascot to png', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF100B20),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: const Color(0xFF100B20),
                padding: const EdgeInsets.all(20),
                child: const Mascot(size: 320),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/private/tmp/claude-501/-Users-ranjeev-Documents-projects-revolution/07963e43-a804-4357-8f20-d76d2d993533/scratchpad/mascot.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
