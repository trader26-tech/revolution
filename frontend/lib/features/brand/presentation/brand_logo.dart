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
      circular: circular,
    );

    // A bundled logo wins over everything: it's already on device, so it
    // renders instantly, works offline, and can't be a 16px favicon.
    final asset = brand.assetPath;
    if (asset != null && asset.isNotEmpty) {
      final image = SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
      if (!bare) return _tile(image);
      if (circular) return ClipOval(child: image);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      );
    }

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

    // Default: the whole logo (contain) on a SPACE-THEMED badge — a subtle dark
    // violet tile, never white, so it sits naturally on the dark UI.
    return _tile(SizedBox(
      width: size,
      height: size,
      child: _chain(urls, 0, fallback),
    ));
  }

  /// A space-themed badge behind a `contain` logo: a soft dark-violet fill and a
  /// faint border — reads as an intentional tile, not a glaring white patch,
  /// while keeping transparent/dark logos visible on the dark UI.
  Widget _tile(Widget image) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: AppColors.logoTile,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: image,
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

/// The graceful fallback when there's no logo: a STYLIZED first-letter avatar —
/// a space-themed accent-tinted orb with a soft radial glow and a gradient
/// letter (ink → lavender). Consistent across the whole app, so a logo-less
/// task never looks bare.
class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar({
    required this.letter,
    required this.size,
    required this.radius,
    required this.seed,
    this.circular = false,
  });

  final String letter;
  final double size;
  final double radius;
  final String seed;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final shape = circular
        ? const _AvatarShape.circle()
        : _AvatarShape.rounded(radius);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: shape.shape,
        borderRadius: shape.borderRadius,
        // A subtle accent-tinted radial fill — a little planet, not a flat tile.
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 1.05,
          colors: [
            AppColors.accent.withValues(alpha: 0.22),
            AppColors.card,
          ],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ink, Color(0xFFB9A8FF)],
        ).createShader(r),
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white, // masked by the gradient
            fontWeight: FontWeight.w900,
            fontSize: size * 0.48,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Small helper so the avatar can be a circle or a rounded square cleanly.
class _AvatarShape {
  const _AvatarShape.circle()
      : shape = BoxShape.circle,
        borderRadius = null;
  _AvatarShape.rounded(double radius)
      : shape = BoxShape.rectangle,
        borderRadius = BorderRadius.circular(radius);
  final BoxShape shape;
  final BorderRadius? borderRadius;
}
