import 'package:flutter/material.dart';

import '../../domain/item_catalog.dart';

/// A small, stylized document "card" thumbnail — drawn in code, not a real logo.
///
/// It reads like a mini ID card: the item's theme colour as a soft gradient, the
/// emoji as the mark, and two faux text lines (a chip + a data line) so it looks
/// like a document at a glance. Zero downloads, offline, consistent, no legal
/// risk from copying official emblems.
class DocumentThumb extends StatelessWidget {
  const DocumentThumb({super.key, required this.item, this.size = 56});

  final Item item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 0.66; // credit-card-ish ratio
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.color,
            Color.lerp(item.color, Colors.black, 0.22)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Faux "chip" — a small rounded square, like a smart-card chip.
          Positioned(
            left: h * 0.16,
            top: h * 0.18,
            child: Container(
              width: h * 0.22,
              height: h * 0.16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // The emoji mark, bottom-left, sized to the card.
          Positioned(
            left: h * 0.14,
            bottom: h * 0.12,
            child: Text(item.emoji, style: TextStyle(fontSize: h * 0.42)),
          ),
          // Faux data lines, bottom-right, evoking printed text.
          Positioned(
            right: w * 0.12,
            bottom: h * 0.22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _line(w * 0.34, Colors.white.withValues(alpha: 0.9)),
                SizedBox(height: h * 0.10),
                _line(w * 0.24, Colors.white.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(double width, Color color) => Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
