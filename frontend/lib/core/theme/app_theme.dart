import 'package:flutter/material.dart';

/// Centralized light/dark themes for the app.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF4F46E5);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
