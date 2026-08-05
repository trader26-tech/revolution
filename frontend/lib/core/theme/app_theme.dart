import 'package:flutter/material.dart';

import 'bamboo_palette.dart';

/// The app theme — a calm, panda/bamboo light world. Light only, by design.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: Bamboo.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: Bamboo.green,
      onPrimary: Colors.white,
      surface: Bamboo.cream,
      onSurface: Bamboo.ink,
      onSurfaceVariant: Bamboo.inkSoft,
      surfaceContainerHighest: Bamboo.mist,
      outlineVariant: Bamboo.cardBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Bamboo.cream,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Bamboo.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Kept for the MaterialApp.darkTheme slot; the app ships light.
  static ThemeData get dark => light;
}
