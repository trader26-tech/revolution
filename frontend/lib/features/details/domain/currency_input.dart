import 'package:flutter/services.dart';

import 'currency.dart';

/// A [TextInputFormatter] that groups the amount as the user types, per the
/// active currency's [Grouping]: Indian (₹1,00,000) for INR, Western
/// ($100,000) for USD/KWD. Allows one decimal point and up to [decimals]
/// fractional digits. Keeps the caret at the end (simple + predictable for a
/// right-aligned money field).
///
/// The stored/parsed value is still plain — callers strip separators with
/// `replaceAll(RegExp(r'[^0-9.]'), '')` before parsing, so grouping is purely
/// visual.
class CurrencyAmountFormatter extends TextInputFormatter {
  const CurrencyAmountFormatter(this.grouping, {this.decimals = 2});

  final Grouping grouping;
  final int decimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text;
    // Keep only digits and at most one dot.
    raw = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    final firstDot = raw.indexOf('.');
    if (firstDot != -1) {
      // Drop any extra dots after the first.
      raw = raw.substring(0, firstDot + 1) +
          raw.substring(firstDot + 1).replaceAll('.', '');
      // Clamp the fractional part to `decimals`.
      final parts = raw.split('.');
      if (parts.length == 2 && parts[1].length > decimals) {
        raw = '${parts[0]}.${parts[1].substring(0, decimals)}';
      }
    }

    final formatted = formatAmount(raw, grouping);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
