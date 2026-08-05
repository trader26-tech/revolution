import 'package:flutter/material.dart';

/// The app's single source of colour + theme truth.
///
/// A clean, neutral, light "glass" world: soft off-white surfaces, frosted white
/// panes, hairline borders, and one calm accent. Everything else is greys, so
/// the frosted glass and the accent do all the talking.
class AppColors {
  const AppColors._();

  // Backgrounds — soft, warm-neutral off-white (never pure #FFF).
  static const bg = Color(0xFFF4F5F7);
  static const bgTop = Color(0xFFEFF1F4);

  // Ink (text) — near-black with soft secondary/tertiary greys.
  static const ink = Color(0xFF1A1C1E);
  static const inkSoft = Color(0xFF6B7280);
  static const inkFaint = Color(0xFF9AA1AC);

  // The single accent.
  static const accent = Color(0xFF3B82F6); // calm blue
  static const accentDeep = Color(0xFF2563EB);

  // Glass — translucent white panes + hairline borders/edges.
  static const glass = Color(0xB3FFFFFF); // ~70% white fill behind the blur
  static const glassBorder = Color(0x33FFFFFF); // bright top edge
  static const hairline = Color(0x14000000); // faint dark separator

  // Solid card surface (for content that shouldn't blur).
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE8EAED);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.bg,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: null, // system font — crisp and native on each platform
      splashFactory: InkRipple.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
