import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A frosted-glass pane: real backdrop blur + a translucent fill, a bright top
/// edge and a soft shadow so it reads as a floating sheet of glass.
///
/// This is the single glass primitive — the top bar, the bottom nav, and any
/// glass button are built from it, so the whole app's glass looks like one
/// material.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = 20,
    this.padding = EdgeInsets.zero,
    this.opacity = 0.62,
    this.onTap,
    this.shadow = true,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final VoidCallback? onTap;

  /// The soft lift shadow. Turn off for flat elements (e.g. the Settings
  /// button) where the glow reads as clutter.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    Widget pane = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // Dark violet glass over the space background; the faint light
            // border is the "bright edge" that sells it as glass.
            color: AppColors.card.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      pane = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: pane,
      );
    }

    if (!shadow) return pane;

    // Soft lift under the glass so it floats above the content.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: pane,
    );
  }
}

/// A round frosted-glass icon button — used for Settings and Add in the top bar.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.accent = false,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// When true the button is filled with the accent colour (the primary "Add").
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = accent
        ? _AccentButton(icon: icon, onTap: onTap, size: size)
        : GlassPanel(
            borderRadius: size / 2,
            onTap: onTap,
            shadow: false, // flat Settings button — no glow
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: AppColors.ink, size: size * 0.48),
            ),
          );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _AccentButton extends StatelessWidget {
  const _AccentButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.accentDeep],
          ),
          // Purple glow — the "+" reads as the app's one special action.
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}
