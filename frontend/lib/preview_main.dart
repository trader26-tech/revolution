import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/screens/gallery_preview_page.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const GalleryPreviewPage(),
      );
}
