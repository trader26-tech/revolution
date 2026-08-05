/// How often a task repeats. `none` = a one-off.
enum RepeatCadence { none, daily, weekly, monthly, yearly }

extension RepeatCadenceLabel on RepeatCadence {
  String get label => switch (this) {
        RepeatCadence.none => 'Never',
        RepeatCadence.daily => 'Daily',
        RepeatCadence.weekly => 'Weekly',
        RepeatCadence.monthly => 'Monthly',
        RepeatCadence.yearly => 'Yearly',
      };
}

/// A single task the user tracks.
///
/// Deliberately minimal: it starts life as just a name (from the quick-add
/// field). The date/time and repeat are optional and set later via the details
/// sheet, so nothing blocks a fast capture.
class Task {
  Task({
    required this.id,
    required this.title,
    this.done = false,
    this.reminderOn = true,
    this.dueAt,
    this.repeat = RepeatCadence.none,
    this.iconName,
    this.iconDomain,
  });

  final String id;
  String title;
  bool done;

  /// Whether a reminder is active for this task.
  bool reminderOn;

  /// When it's due (date + time). Null = unscheduled ("Tap to set a date").
  DateTime? dueAt;

  RepeatCadence repeat;

  /// The brand/app icon attached to this task (optional). [iconName] seeds the
  /// letter-avatar fallback; [iconDomain] is the logo domain (empty/null → no
  /// remote logo, just the avatar).
  String? iconName;
  String? iconDomain;

  bool get isScheduled => dueAt != null;
  bool get hasIcon => (iconName != null && iconName!.isNotEmpty);

  Task copyWith({
    String? title,
    bool? done,
    bool? reminderOn,
    DateTime? dueAt,
    bool clearDueAt = false,
    RepeatCadence? repeat,
    String? iconName,
    String? iconDomain,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      done: done ?? this.done,
      reminderOn: reminderOn ?? this.reminderOn,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      repeat: repeat ?? this.repeat,
      iconName: iconName ?? this.iconName,
      iconDomain: iconDomain ?? this.iconDomain,
    );
  }
}
