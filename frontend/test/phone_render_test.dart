import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/features/auth/presentation/phone_login_page.dart';

void main() {
  testWidgets('render phone login', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: RepaintBoundary(
        child: PhoneLoginPage(onSubmit: (_) async {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    RenderRepaintBoundary? b;
    void visit(RenderObject o){ if(o is RenderRepaintBoundary) b??=o; o.visitChildren(visit);}
    visit(tester.binding.renderViewElement!.renderObject!);
    final img = await b!.toImage(pixelRatio: 2.0);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('test/tmp/phone.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}
