/// Small date helpers so the UI reads dates the way people in India expect
/// (e.g. "5 Aug 2026") without pulling in the intl package yet.
class DateFmt {
  const DateFmt._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// e.g. "5 Aug 2026"
  static String medium(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// A friendly relative phrase for how far off a date is.
  /// e.g. "in 45 days", "today", "2 days ago".
  static String relativeDays(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days == -1) return 'yesterday';
    if (days > 0) {
      if (days < 45) return 'in $days days';
      final months = (days / 30).round();
      if (months < 12) return 'in $months months';
      final years = (days / 365);
      return years >= 1.9 ? 'in ${years.round()} years' : 'in about a year';
    }
    final ago = -days;
    if (ago < 45) return '$ago days ago';
    final months = (ago / 30).round();
    return '$months months ago';
  }
}
