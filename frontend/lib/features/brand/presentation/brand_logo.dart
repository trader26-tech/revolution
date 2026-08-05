import 'package:flutter/material.dart';

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

    if (brand.logoUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        brand.logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // While loading, keep the space stable with the avatar underneath.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child; // done
          return _LoadingBox(size: size, radius: radius);
        },
        // Any failure (404, offline, timeout) → the letter avatar.
        errorBuilder: (_, _, _) => fallback,
      ),
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

  // Deterministic, pleasant colour derived from the name so the same brand
  // always gets the same avatar colour.
  static const _palette = [
    Color(0xFF4F46E5), Color(0xFF0EA5E9), Color(0xFF16A34A),
    Color(0xFFCA8A04), Color(0xFFEF4444), Color(0xFF9333EA),
    Color(0xFFEC4899), Color(0xFF06B6D4), Color(0xFFF59E0B),
  ];

  Color get _color {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.46,
        ),
      ),
    );
  }
}
