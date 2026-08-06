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
  });

  final Brand brand;
  final double size;
  final double radius;

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
      fit: BoxFit.contain,
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
    // One clean, uniform tile for EVERY logo-less task: a light accent-tinted
    // surface with a hairline accent border and a confident blue letter. Crisp
    // and intentional (not a washed-out grey blob), yet calm enough to sit
    // beside the real logos.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.accentDeep,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.48,
          height: 1.0,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
