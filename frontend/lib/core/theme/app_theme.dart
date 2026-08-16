import 'package:flutter/material.dart';

/// The app's single source of colour + theme truth.
///
/// A deep-space, dark-purple world (the "Orbit" scheme): a near-black violet
/// sky, soft lavender inks, dark elevated cards, and one vivid purple accent.
/// Everything else stays muted so the accent and the brand logos do all the
/// talking.
class AppColors {
  const AppColors._();

  // Backgrounds — near-black violet space (never pure #000).
  static const bg = Color(0xFF100B20);
  static const bgTop = Color(0xFF171030);

  // Ink (text) — soft white with lavender-grey secondary/tertiary.
  static const ink = Color(0xFFF5F2FF);
  static const inkSoft = Color(0xFFA9A1C4);
  static const inkFaint = Color(0xFF6F6890);

  // The single accent — vivid violet.
  static const accent = Color(0xFF7C5CFC);
  static const accentDeep = Color(0xFF6742EE);

  // Glass — translucent dark panes + faint light edges.
  static const glass = Color(0xB31D1636); // ~70% dark-violet fill behind blur
  static const glassBorder = Color(0x1FFFFFFF); // faint bright top edge
  static const hairline = Color(0x14FFFFFF); // faint light separator

  // Solid card surface (elevated above the sky).
  static const card = Color(0xFF1C1636);
  static const cardBorder = Color(0xFF2C2450);

  // Backing tile behind brand logos — a soft, lifted dark-violet (NEVER white),
  // so logos sit naturally on the space-dark UI.
  static const logoTile = Color(0xFF2A2150);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
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
      // Plus Jakarta Sans — a warm, modern geometric sans. Bundled (see
      // assets/fonts + pubspec), so it works offline and never pops in late.
      fontFamily: 'PlusJakartaSans',
      textTheme: _textTheme,
      splashFactory: InkRipple.splashFactory,
      // ONE consistent, subtle page transition everywhere (all platforms) so
      // navigating between screens feels smooth — a gentle fade + rise/slide,
      // never the abrupt platform default.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SmoothPageTransitionsBuilder(),
        },
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27), // full pill, like Orbit
          ),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }

  /// A considered scale for Plus Jakarta Sans: big headings are heavy and
  /// tightly tracked (feels premium), titles are semi-bold, body is comfortable
  /// with a hair of negative tracking so the geometric sans reads crisp — never
  /// flat or "default".
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
        fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.05),
    displayMedium: TextStyle(
        fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.08),
    displaySmall: TextStyle(
        fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.1),
    headlineLarge: TextStyle(
        fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.12),
    headlineMedium: TextStyle(
        fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15),
    headlineSmall: TextStyle(
        fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2),
    titleLarge: TextStyle(
        fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleMedium: TextStyle(
        fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleSmall: TextStyle(
        fontWeight: FontWeight.w600, letterSpacing: -0.1),
    bodyLarge: TextStyle(letterSpacing: -0.1, height: 1.45),
    bodyMedium: TextStyle(letterSpacing: -0.1, height: 1.45),
    bodySmall: TextStyle(letterSpacing: 0, height: 1.4),
    labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
    labelMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
  );
}

/// The app's ONE page transition — a subtle FADE + gentle RISE for the incoming
/// page, and a slight fade-back for the outgoing one. Calm and premium, applied
/// to every route push app-wide via [ThemeData.pageTransitionsTheme] so every
/// screen change feels smooth and consistent (never the abrupt default).
class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Incoming page: fade in + rise a touch, on a smooth decelerating curve.
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // Outgoing page (underneath): a gentle fade + tiny lift, so it recedes
    // instead of just snapping away.
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03), // rise ~3% of height as it fades in
          end: Offset.zero,
        ).animate(enter),
        child: FadeTransition(
          // The outgoing page dims slightly to ~0.85 as the new one covers it.
          opacity: Tween<double>(begin: 1, end: 0.85).animate(exit),
          child: child,
        ),
      ),
    );
  }
}
