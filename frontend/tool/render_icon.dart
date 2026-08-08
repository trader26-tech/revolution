// Renders Revo (the in-app Mascot, drawn in code) to a 1024x1024 PNG on the
// app's dark-purple background, for use as the launcher icon.
//
// Run with:  flutter run -d macos -t tool/render_icon.dart
// (or any device) — it paints one frame, writes tool/revo_icon.png, and exits.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/core/widgets/mascot.dart';

const _size = 1024.0;
const _out = 'tool/revo_icon.png';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _RenderApp());
}

class _RenderApp extends StatefulWidget {
  const _RenderApp();
  @override
  State<_RenderApp> createState() => _RenderAppState();
}

class _RenderAppState extends State<_RenderApp> {
  final _boundaryKey = GlobalKey();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Capture after the first frame paints.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    // Let a couple of frames settle so the paint is complete.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final boundary = _boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(_out);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${file.absolute.path} (${bytes.lengthInBytes} bytes)');
    setState(() => _done = true);
    // Give the print a beat, then exit so `flutter run` returns.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: _size,
            height: _size,
            color: AppColors.bg, // dark purple, matches the app theme
            alignment: Alignment.center,
            // Mascot at ~76% of the canvas leaves a comfortable icon margin.
            child: const Mascot(size: _size * 0.76, glow: true),
          ),
        ),
      ),
    );
  }
}
