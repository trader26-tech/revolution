import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/brand.dart';

/// Shows a brand's logo, fetched from the network and cached by Flutter's image
/// cache. If the logo is missing, fails, or the device is offline, it gracefully
/// falls back to a coloured letter-avatar — so it NEVER shows a broken image.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.brand,
    this.size = 44,
    this.radius = 12,
    this.bare = false,
    this.circular = false,
  });

  final Brand brand;
  final double size;
  final double radius;

  /// When true, the logo is drawn with NO white backing tile or padding — just
  /// the (rounded) logo image itself. For hero/marketing surfaces where the
  /// logos float freely rather than sit in list rows.
  final bool bare;

  /// Crop the logo to a circle instead of a rounded square.
  ///
  /// Some brands' favicons ship a fully OPAQUE white background (SBI's, for
  /// one) rather than a transparent one. On a dark surface that renders as a
  /// glaring white patch around the mark. Cropping to a circle turns that
  /// leftover background into a deliberate circular badge — the shape reads as
  /// intentional, and no square white corners survive.
  ///
  /// Logos that are already transparent are unaffected: a circular crop of a
  /// centred mark looks the same as an uncropped one.
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final fallback = _LetterAvatar(
      letter: brand.initial,
      size: size,
      radius: radius,
      seed: brand.name,
    );

    final urls = brand.logoUrlCandidates;
    if (urls.isEmpty) return fallback;

    if (bare) {
      final image = SizedBox(
        width: size,
        height: size,
        child: _chain(urls, 0, fallback),
      );
      // `cover` on the circular path: the mark fills the circle edge-to-edge,
      // so a white-backed favicon becomes a clean filled badge with no pale
      // rim left showing at the corners.
      if (circular) return ClipOval(child: image);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      );
    }

    // Try each candidate in order; the first that loads is shown. `contain` +
    // white backdrop keeps the WHOLE logo visible (no crop). Simple + reliable.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        padding: EdgeInsets.all(size * 0.12),
        child: _chain(urls, 0, fallback),
      ),
    );
  }

  /// Try [urls[i]]; on error fall through to the next, finally the avatar.
  Widget _chain(List<String> urls, int i, Widget fallback) {
    if (i >= urls.length) return fallback;
    return Image.network(
      urls[i],
      // Circular crop fills the circle (`cover`) so no pale rim survives at the
      // edge; everywhere else `contain` keeps the whole mark visible.
      fit: circular ? BoxFit.cover : BoxFit.contain,
      filterQuality: FilterQuality.high,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _LoadingBox(size: size, radius: radius);
      },
      errorBuilder: (_, _, _) => _chain(urls, i + 1, fallback),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({required this.size, required this.radius});
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// A coloured square with the brand's first letter — the graceful fallback.
class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar({
    required this.letter,
    required this.size,
    required this.radius,
    required this.seed,
  });

  final String letter;
  final double size;
  final double radius;
  final String seed;

  @override
  Widget build(BuildContext context) {
    // Neutral tile for logo-less tasks — matches the real brand logos (white
    // surface, subtle border) so the whole list looks consistent. The letter is
    // a calm ash grey, not blue.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.card, // white
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.inkSoft, // ash grey
          fontWeight: FontWeight.w700,
          fontSize: size * 0.46,
          height: 1.0,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
