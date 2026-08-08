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
    this.amount,
    this.currency = 'INR',
    this.documentPath,
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

  /// The recurring/one-time cost (null = no amount set, e.g. a free plan). Its
  /// [currency] is an ISO code (INR / USD / KWD).
  double? amount;
  String currency;

  /// Path of an attached document (insurance policy PDF/photo) in the private
  /// bucket. Non-null → the item has a document; tapping its icon opens it.
  String? documentPath;

  bool get isScheduled => dueAt != null;
  bool get hasIcon => (iconName != null && iconName!.isNotEmpty);
  bool get hasAmount => amount != null;
  bool get hasDocument => documentPath != null && documentPath!.isNotEmpty;

  Task copyWith({
    String? title,
    bool? done,
    bool? reminderOn,
    DateTime? dueAt,
    bool clearDueAt = false,
    RepeatCadence? repeat,
    String? iconName,
    String? iconDomain,
    double? amount,
    bool clearAmount = false,
    String? currency,
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
      amount: clearAmount ? null : (amount ?? this.amount),
      currency: currency ?? this.currency,
    );
  }

  // --- JSON (matches the backend /tasks API, snake_case) --------------------
  /// Body for creating/updating a task on the server. `id` is server-assigned,
  /// so it's not sent.
  Map<String, dynamic> toJson() => {
        'title': title,
        'done': done,
        'reminder_on': reminderOn,
        'due_at': dueAt?.toIso8601String(),
        'repeat': repeat.name,
        'icon_name': iconName,
        'icon_domain': iconDomain,
        'amount': amount,
        'currency': currency,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'].toString(),
        title: j['title'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        reminderOn: j['reminder_on'] as bool? ?? true,
        dueAt:
            j['due_at'] == null ? null : DateTime.parse(j['due_at'] as String),
        repeat: RepeatCadence.values.firstWhere(
          (r) => r.name == j['repeat'],
          orElse: () => RepeatCadence.none,
        ),
        iconName: j['icon_name'] as String?,
        iconDomain: j['icon_domain'] as String?,
        amount: (j['amount'] as num?)?.toDouble(),
        currency: j['currency'] as String? ?? 'INR',
        documentPath: j['document_path'] as String?,
      );
}
