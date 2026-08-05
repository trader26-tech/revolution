// Throwaway preview harness for Bobo (no backend needed). WHITE background to
// confirm the outline separates him. Run: flutter run -t lib/bobo_preview.dart
import 'package:flutter/material.dart';

import 'features/mascot/presentation/bobo_mascot.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _Tile(mood: BoboMood.happy, label: 'happy'),
              _Tile(mood: BoboMood.excited, label: 'excited'),
              _Tile(mood: BoboMood.sleepy, label: 'sleepy'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.mood, required this.label});
  final BoboMood mood;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BoboMascot(size: 220, mood: mood),
        Text(label),
      ],
    );
  }
}
