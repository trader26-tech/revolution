// Throwaway preview harness to render Pip in isolation (no backend needed).
// Run with: flutter run -t lib/panda_preview.dart  — safe to delete.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/panda/presentation/panda_mascot.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.light.colorScheme.primaryContainer
                    .withValues(alpha: 0.55),
                AppTheme.light.colorScheme.surface,
              ],
            ),
          ),
          child: const Center(
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _Tile(mood: PandaMood.happy, label: 'happy'),
                _Tile(mood: PandaMood.excited, label: 'excited'),
                _Tile(mood: PandaMood.sleepy, label: 'sleepy'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.mood, required this.label});
  final PandaMood mood;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PandaMascot(size: 200, mood: mood),
        Text(label),
      ],
    );
  }
}
