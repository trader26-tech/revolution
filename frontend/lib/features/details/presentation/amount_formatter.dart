import 'package:flutter/services.dart';

import '../domain/currency.dart';

/// Live-formats the amount field with the right thousands grouping for the
/// active currency (Indian lakh grouping vs Western), keeping the caret at the
/// end. Allows digits and a single decimal point.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter(this.grouping);

  final Grouping grouping;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Keep only digits + at most one dot.
    var cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
    final firstDot = cleaned.indexOf('.');
    if (firstDot != -1) {
      cleaned = cleaned.substring(0, firstDot + 1) +
          cleaned.substring(firstDot + 1).replaceAll('.', '');
    }

    final formatted = formatAmount(cleaned, grouping);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
