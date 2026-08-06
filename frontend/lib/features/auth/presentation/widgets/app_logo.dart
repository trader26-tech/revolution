import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The app's logo mark — a premium rounded-square badge with a soft gradient,
/// an inner glass highlight, and a crisp bell glyph (reminders). Drawn in code
/// so it's razor-sharp at any size and needs no asset.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final r = size * 0.30;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B9DFF), AppColors.accent, AppColors.accentDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.45),
            blurRadius: size * 0.42,
            offset: Offset(0, size * 0.18),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy top highlight for depth.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
