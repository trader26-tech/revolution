import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A country flag that renders reliably on BOTH Android and iOS.
///
/// Android's system font has no flag emoji glyphs, so `Text('🇮🇳')` shows a
/// blank box / "IN" there. We instead load a small flag PNG by ISO code, with a
/// clean ISO-code chip as the fallback when offline — so it always looks right.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.iso, this.size = 22});

  final String iso; // e.g. 'IN'
  final double size;

  @override
  Widget build(BuildContext context) {
    final width = size * 1.4; // flags are wider than tall (4:3-ish)
    final height = size;
    final fallback = _IsoChip(iso: iso, width: width, height: height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        'https://flagcdn.com/w80/${iso.toLowerCase()}.png',
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// The offline fallback: the 2-letter ISO code in a tidy chip.
class _IsoChip extends StatelessWidget {
  const _IsoChip({required this.iso, required this.width, required this.height});
  final String iso;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        iso.toUpperCase(),
        style: TextStyle(
          fontSize: height * 0.5,
          fontWeight: FontWeight.w800,
          color: AppColors.inkSoft,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
