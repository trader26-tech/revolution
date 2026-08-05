/// How often a reminder recurs. The reminder-app equivalent of Orbit's
/// Type + Cycle, collapsed into one clear choice.
enum RepeatCycle {
  once('One-time', null),
  monthly('Every month', 1),
  quarterly('Every 3 months', 3),
  halfYearly('Every 6 months', 6),
  yearly('Every year', 12);

  const RepeatCycle(this.label, this.months);

  /// Human label shown in the form.
  final String label;

  /// Interval in months, or null for a one-time reminder.
  final int? months;
}
