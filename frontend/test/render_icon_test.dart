// Headless renderer for the app icon: paints Revo (the in-app Mascot, drawn in
// code) to a 1024x1024 PNG on the app's dark-purple background. Not a real test
// — it's a convenient way to run Flutter's rendering pipeline without a device.
//
// Run:  flutter test test/render_icon_test.dart
// Out:  tool/revo_icon.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/core/widgets/mascot.dart';

const _size = 1024.0;
const _out = 'tool/revo_icon.png';

void main() {
  testWidgets('render Revo app icon', (tester) async {
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: boundaryKey,
          child: Container(
            width: _size,
            height: _size,
            color: AppColors.bg, // dark purple, app theme
            alignment: Alignment.center,
            child: const Mascot(size: _size * 0.76, glow: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(_out);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${file.absolute.path} (${bytes.lengthInBytes} bytes)');

    expect(file.existsSync(), isTrue);
  });
}
