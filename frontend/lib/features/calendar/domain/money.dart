import '../../details/domain/currency.dart';
import 'occurrences.dart';

/// Money math for the calendar: totalling occurrence amounts and formatting them
/// with the right currency symbol + grouping (Indian lakh vs Western).
///
/// A set of occurrences can in theory mix currencies; we total per currency and,
/// for the single headline figure the UI shows, use the currency that carries
/// the most value (falling back to INR). This keeps the common single-currency
/// case exact while never crashing on a mixed set.
class MoneyTotal {
  const MoneyTotal({required this.amount, required this.currency});

  final double amount;
  final String currency;

  static const MoneyTotal zero = MoneyTotal(amount: 0, currency: 'INR');

  bool get isZero => amount == 0;

  /// "₹1,22,484.00" — grouped for the currency, with its decimals + symbol.
  String get formatted {
    final c = currencyOf(currency);
    final fixed = amount.toStringAsFixed(c.decimals);
    return '${c.symbol}${formatAmount(fixed, c.grouping)}';
  }
}

/// Sum the amounts of [occ], grouped by currency, and return the dominant one.
/// Occurrences without an amount contribute nothing. Empty → zero (INR).
MoneyTotal totalOf(Iterable<Occurrence> occ) {
  final byCurrency = <String, double>{};
  for (final o in occ) {
    final amt = o.task.amount;
    if (amt == null) continue;
    final cur = o.task.currency;
    byCurrency[cur] = (byCurrency[cur] ?? 0) + amt;
  }
  if (byCurrency.isEmpty) return MoneyTotal.zero;

  // Pick the currency holding the most value as the headline currency.
  var bestCur = 'INR';
  var best = double.negativeInfinity;
  double grandTotal = 0;
  for (final entry in byCurrency.entries) {
    grandTotal += entry.value;
    if (entry.value > best) {
      best = entry.value;
      bestCur = entry.key;
    }
  }
  // If it's genuinely single-currency, grandTotal == that currency's sum.
  final single = byCurrency.length == 1;
  return MoneyTotal(
    amount: single ? byCurrency[bestCur]! : grandTotal,
    currency: bestCur,
  );
}

/// The total for a single day (date-only key) from a grouped map.
MoneyTotal dayTotal(Map<DateTime, List<Occurrence>> byDay, DateTime day) =>
    totalOf(byDay[DateTime(day.year, day.month, day.day)] ?? const []);

/// The whole month's total across every occurrence passed.
MoneyTotal monthTotal(Iterable<Occurrence> occ) => totalOf(occ);

/// The "upcoming" total: occurrences dated today or later. Mirrors the
/// screenshots' "Upcoming" figure next to the month total.
MoneyTotal upcomingTotal(Iterable<Occurrence> occ, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return totalOf(
    occ.where((o) => !o.date.isBefore(today)),
  );
}
