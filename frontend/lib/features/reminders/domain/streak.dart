import '../../mascot/presentation/bobo_mascot.dart';
import 'reminder.dart';

/// Bobo's read on how the user is doing, derived purely from the reminder list.
///
/// The rule (kept deliberately simple and always accurate): as long as *nothing
/// is overdue*, the user is "on a good run" — Bobo gets excited and a flame
/// shows. The moment something lapses, the run breaks and Bobo turns sad.
///
/// The streak length is the number of days until the *next* thing that needs
/// attention — i.e. how long the user has been / will stay in the clear. When
/// everything is far off, that's a big number and a big flame.
class StreakStatus {
  const StreakStatus({
    required this.overdueCount,
    required this.dueSoonCount,
    required this.onStreak,
    required this.streakDays,
    required this.mood,
  });

  final int overdueCount;
  final int dueSoonCount;

  /// True when nothing is overdue — the user is maintaining their streak.
  final bool onStreak;

  /// Days of clear runway until the next renewal needs action. Drives the
  /// flame's size/label. 0 when something is overdue (streak broken).
  final int streakDays;

  /// The mood Bobo should show for this status.
  final BoboMood mood;

  bool get hasReminders => overdueCount + dueSoonCount + streakDays >= 0;

  /// A short label for the flame chip, e.g. "🔥 On a 42-day streak".
  String get flameLabel {
    if (!onStreak) return 'Streak broken';
    if (streakDays <= 0) return 'On track today';
    if (streakDays == 1) return 'Clear for 1 day';
    return 'Clear for $streakDays days';
  }

  static StreakStatus from(List<Reminder> reminders) {
    final overdue = reminders.where((r) => r.isExpired).length;
    final dueSoon =
        reminders.where((r) => r.isDueSoon && !r.isExpired).length;
    final onStreak = overdue == 0;

    // Days of clear runway = smallest positive days-until-expiry across all
    // reminders (how long until the next one even enters the picture).
    int runway = 0;
    if (reminders.isNotEmpty && onStreak) {
      final future = reminders
          .map((r) => r.daysUntilExpiry)
          .where((d) => d >= 0)
          .toList()
        ..sort();
      runway = future.isEmpty ? 0 : future.first;
    }

    // Mood: overdue → sad; something imminent → scared; on a healthy streak
    // with real breathing room → excited; empty/fresh → happy.
    final BoboMood mood;
    if (reminders.isEmpty) {
      mood = BoboMood.happy;
    } else if (overdue > 0) {
      mood = BoboMood.sad;
    } else if (dueSoon > 0) {
      mood = BoboMood.scared;
    } else {
      // All clear with runway ahead — Bobo is proud/excited on a good streak.
      mood = BoboMood.excited;
    }

    return StreakStatus(
      overdueCount: overdue,
      dueSoonCount: dueSoon,
      onStreak: onStreak,
      streakDays: runway,
      mood: mood,
    );
  }
}
