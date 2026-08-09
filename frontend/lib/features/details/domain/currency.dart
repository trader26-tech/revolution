/// A supported currency and its number-grouping system.
enum Grouping {
  /// Western: groups of 3 → 1,000,000 (US, Kuwait).
  western,

  /// Indian: 3 then 2s → 10,00,000 (lakh/crore).
  indian,
}

class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.label,
    required this.grouping,
    this.decimals = 2,
    this.inrPerUnit = 1,
  });

  /// ISO-ish code stored on the record (INR / USD / KWD).
  final String code;

  /// The glyph shown in the badge (₹ / $ / KD).
  final String symbol;
  final String label;
  final Grouping grouping;
  final int decimals;

  /// Approximate INR value of ONE unit of this currency — used to combine
  /// mixed-currency totals into a single ₹ figure. These are static estimates
  /// (not live rates); good enough for an at-a-glance "how much am I spending".
  final double inrPerUnit;
}

/// The currencies offered in the picker.
const List<Currency> kCurrencies = [
  Currency(code: 'INR', symbol: '₹', label: 'Indian Rupee', grouping: Grouping.indian),
  Currency(code: 'USD', symbol: '\$', label: 'US Dollar', grouping: Grouping.western, inrPerUnit: 86),
  // Kuwait uses 3-decimal fils, but per the requested UX we keep US-style
  // grouping. 3 decimals matches how KWD amounts are actually written.
  Currency(code: 'KWD', symbol: 'KD', label: 'Kuwaiti Dinar', grouping: Grouping.western, decimals: 3, inrPerUnit: 280),
];

/// Resolve a currency by its stored code or symbol; defaults to INR.
Currency currencyOf(String codeOrSymbol) {
  for (final c in kCurrencies) {
    if (c.code == codeOrSymbol || c.symbol == codeOrSymbol) return c;
  }
  return kCurrencies.first;
}

/// Convert [amount] of currency [code] to an approximate INR value.
double toInr(double amount, String code) =>
    amount * currencyOf(code).inrPerUnit;

/// Group the integer part of a number string according to [grouping].
/// Input is a plain digit string (no separators); returns it grouped.
String groupDigits(String digits, Grouping grouping) {
  if (digits.length <= 3) return digits;
  if (grouping == Grouping.western) {
    // Groups of 3 from the right: 1,000,000
    final buf = StringBuffer();
    var count = 0;
    for (var i = digits.length - 1; i >= 0; i--) {
      buf.write(digits[i]);
      count++;
      if (count % 3 == 0 && i != 0) buf.write(',');
    }
    return buf.toString().split('').reversed.join();
  }
  // Indian: last 3 digits, then groups of 2 → 10,00,000
  final last3 = digits.substring(digits.length - 3);
  final rest = digits.substring(0, digits.length - 3);
  final buf = StringBuffer();
  var count = 0;
  for (var i = rest.length - 1; i >= 0; i--) {
    buf.write(rest[i]);
    count++;
    if (count % 2 == 0 && i != 0) buf.write(',');
  }
  final grouped = buf.toString().split('').reversed.join();
  return '$grouped,$last3';
}

/// Format a full amount string ("1234.5") into grouped form ("1,234.5"),
/// preserving a trailing decimal the user is mid-typing.
String formatAmount(String raw, Grouping grouping) {
  if (raw.isEmpty) return '';
  final hasDot = raw.contains('.');
  final parts = raw.split('.');
  final intPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
  final decPart = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';
  final groupedInt = intPart.isEmpty ? '' : groupDigits(intPart, grouping);
  if (hasDot) return '$groupedInt.$decPart';
  return groupedInt;
}

/// Strip separators back to a plain number string for parsing/saving.
String unformatAmount(String formatted) =>
    formatted.replaceAll(',', '').trim();
