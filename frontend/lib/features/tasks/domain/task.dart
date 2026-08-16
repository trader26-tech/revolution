/// How often a task repeats. `none` = a one-off. The repeat is an INTERVAL:
/// "every N `unit`" where N is [Task.repeatTimes] and the unit is this cadence.
enum RepeatCadence { none, minute, hour, daily, weekly, monthly, yearly }

extension RepeatCadenceLabel on RepeatCadence {
  String get label => switch (this) {
        RepeatCadence.none => 'Never',
        RepeatCadence.minute => 'Minutely',
        RepeatCadence.hour => 'Hourly',
        RepeatCadence.daily => 'Daily',
        RepeatCadence.weekly => 'Weekly',
        RepeatCadence.monthly => 'Monthly',
        RepeatCadence.yearly => 'Yearly',
      };

  /// The singular unit word — "every N `unit`".
  String get unit => switch (this) {
        RepeatCadence.none => '',
        RepeatCadence.minute => 'minute',
        RepeatCadence.hour => 'hour',
        RepeatCadence.daily => 'day',
        RepeatCadence.weekly => 'week',
        RepeatCadence.monthly => 'month',
        RepeatCadence.yearly => 'year',
      };
}

/// The units offered in the "every N …" repeat picker, in display order.
const List<RepeatCadence> kRepeatUnits = [
  RepeatCadence.minute,
  RepeatCadence.hour,
  RepeatCadence.daily,
  RepeatCadence.weekly,
  RepeatCadence.monthly,
  RepeatCadence.yearly,
];

/// A human-readable frequency — "Every day", "Every 2 months", "Every 3 weeks".
String frequencyLabel(RepeatCadence repeat, int interval) {
  if (repeat == RepeatCadence.none) return 'Never';
  final n = interval < 1 ? 1 : interval;
  if (n == 1) return 'Every ${repeat.unit}';
  return 'Every $n ${repeat.unit}s';
}

/// What kind of thing a reminder is — used to group the Home into per-category
/// cards. `other` is the catch-all for anything that doesn't fit (or older
/// tasks created before categories existed).
enum TaskCategory {
  subscription,
  birthday,
  insurance,
  investment,
  bills,
  policies,
  medicine,
  other
}

extension TaskCategoryInfo on TaskCategory {
  String get label => switch (this) {
        TaskCategory.subscription => 'Subscriptions',
        TaskCategory.birthday => 'Special Days',
        TaskCategory.insurance => 'Insurance',
        TaskCategory.investment => 'SIPs',
        TaskCategory.bills => 'Bills',
        TaskCategory.policies => 'Policies',
        TaskCategory.medicine => 'Medicines',
        TaskCategory.other => 'General',
      };

  /// Singular form for a card header count ("1 subscription").
  String get singular => switch (this) {
        TaskCategory.subscription => 'subscription',
        TaskCategory.birthday => 'special day',
        TaskCategory.insurance => 'insurance item',
        TaskCategory.investment => 'SIP',
        TaskCategory.bills => 'bill',
        TaskCategory.policies => 'policy',
        TaskCategory.medicine => 'medicine',
        TaskCategory.other => 'reminder',
      };
}

/// How a maturing policy pays out.
enum PayoutMethod { lumpSum, monthlyPension, annualPayout }

extension PayoutMethodInfo on PayoutMethod {
  String get label => switch (this) {
        PayoutMethod.lumpSum => 'Lump sum',
        PayoutMethod.monthlyPension => 'Monthly pension',
        PayoutMethod.annualPayout => 'Annual payout',
      };

  /// Short one-liner shown under the return amount.
  String get blurb => switch (this) {
        PayoutMethod.lumpSum => 'The whole return in one payment at maturity',
        PayoutMethod.monthlyPension => 'A fixed amount every month after maturity',
        PayoutMethod.annualPayout => 'A fixed amount every year after maturity',
      };
}

/// Best-guess a category from a task's fields, for reminders that were created
/// before categories existed (or came from the server without one). Cheap
/// heuristics — the user can always correct it, and a real [Task.category]
/// (once set on add) overrides this entirely.
TaskCategory inferCategory(Task t) {
  final name = t.title.toLowerCase();
  final looksBirthday = t.repeat == RepeatCadence.yearly &&
      (name.contains('birthday') ||
          name.contains("'s day") ||
          name.contains('anniversary') ||
          name.contains('bday'));
  if (looksBirthday) return TaskCategory.birthday;
  // A policy/document + yearly renewal reads as insurance.
  if (t.hasDocument ||
      name.contains('insurance') ||
      name.contains('policy') ||
      name.contains('renewal')) {
    return TaskCategory.insurance;
  }
  // SIP / mutual-fund investing.
  if (name.contains('sip') ||
      name.contains('mutual fund') ||
      name.contains('mutualfund') ||
      name.contains('invest')) {
    return TaskCategory.investment;
  }
  // Recurring bills / payments.
  if (name.contains('bill') ||
      name.contains('recharge') ||
      name.contains('electricity') ||
      name.contains('rent') ||
      name.contains('emi') ||
      name.contains('payment')) {
    return TaskCategory.bills;
  }
  // A recurring paid item reads as a subscription.
  if (t.hasAmount && t.repeat == RepeatCadence.monthly) {
    return TaskCategory.subscription;
  }
  if (name.contains('netflix') ||
      name.contains('prime') ||
      name.contains('spotify') ||
      name.contains('subscription')) {
    return TaskCategory.subscription;
  }
  return TaskCategory.other;
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
    this.repeatTimes = 1,
    this.repeatDays = const [],
    this.iconName,
    this.iconDomain,
    this.amount,
    this.currency = 'INR',
    this.documentPath,
    this.imagePath,
    this.storedCategory,
    this.subCategory,
    this.note,
    this.doseTimes = const [],
    this.courseDays,
    this.birthYear,
    this.remindDaysBefore = 0,
    this.returnAmount,
    this.maturityAt,
    this.payoutMethod,
    this.payoutAmount,
    this.payoutCount,
  });

  final String id;
  String title;
  bool done;

  /// Whether a reminder is active for this task.
  bool reminderOn;

  /// When it's due (date + time). Null = unscheduled ("Tap to set a date").
  DateTime? dueAt;

  RepeatCadence repeat;

  /// How many TIMES per cycle it recurs — e.g. `repeat == weekly` with
  /// `repeatTimes == 2` means "twice a week". Default 1.
  int repeatTimes;

  /// For a WEEKLY repeat, the specific weekdays it lands on (1 = Mon … 7 = Sun,
  /// matching [DateTime.weekday]). Empty = no specific days chosen.
  List<int> repeatDays;

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

  /// A LOCAL, on-device image file path (a person's face for a birthday, a
  /// subscription's picture). Not synced to the server — stored per-device via
  /// the task cache. Shown as the task's avatar when present.
  String? imagePath;

  /// The explicitly-set category (from the add flow). Null for older tasks —
  /// use [category], which falls back to [inferCategory].
  TaskCategory? storedCategory;

  /// A free-text SUB-category within a category — e.g. a subscription's
  /// "Entertainment" / "Music" / "AI" bucket (auto-filled from the app, or a
  /// custom label the user typed). Null = uncategorised → "Other".
  String? subCategory;

  /// A freeform NOTE the user attaches to a reminder — the "why", context, or
  /// anything worth remembering. Used most by the General category (a catch-all
  /// reminder + note), but available to any task. Null = no note.
  String? note;

  // ── Medicines: the dosing schedule ───────────────────────────────────────
  // A medicine is taken at one or more TIMES OF DAY, on certain WEEKDAYS (via
  // [repeatDays]; empty = every day), for a COURSE of a given number of days.

  /// The times of day a dose is taken, as "HH:mm" 24-hour strings (e.g.
  /// ["08:00", "14:00", "20:00"]). Empty for non-medicine tasks.
  List<String> doseTimes;

  /// How many days the medicine course runs (from the start date). Null = open-
  /// ended / ongoing.
  int? courseDays;

  /// For a birthday/anniversary: the person's birth year, when known. Null =
  /// year unknown (we only track the day/month). Drives the "turns N" age.
  int? birthYear;

  /// How many days before the due date to remind (0 = on the day).
  int remindDaysBefore;

  // ── Policies: the "return" side ──────────────────────────────────────────
  // For a savings/endowment policy, [amount] is the premium you PAY (its
  // [repeat] cadence tells us monthly vs yearly). These three describe what
  // comes BACK: how much, when it matures, and how it's paid out.

  /// The total you get back at/after maturity (null = not a returning policy).
  double? returnAmount;

  /// The date the policy matures — when the return starts/arrives.
  DateTime? maturityAt;

  /// How the return is paid out (lump sum / monthly pension / annual payout).
  PayoutMethod? payoutMethod;

  /// For an AMORTIZED return (monthly pension / annual payout): the amount of a
  /// SINGLE installment, and how many installments there are. The total
  /// [returnAmount] is then payoutAmount × payoutCount. Both null for a lump
  /// sum (where [returnAmount] is the whole figure directly).
  double? payoutAmount;
  int? payoutCount;

  bool get isScheduled => dueAt != null;
  bool get hasReturn => returnAmount != null && returnAmount! > 0;

  /// How many premium payments land between now and maturity, given the premium
  /// cadence AND its interval ([repeatTimes] = "every N months/years"). So a
  /// yearly premium paid "every 2 years" halves the count. Best-effort — null
  /// if we can't compute it (no maturity/cadence).
  int? get premiumPeriods {
    final m = maturityAt;
    if (m == null) return null;
    final months =
        (m.year - DateTime.now().year) * 12 + (m.month - DateTime.now().month);
    if (months <= 0) return null;
    final every = repeatTimes < 1 ? 1 : repeatTimes;
    return switch (repeat) {
      RepeatCadence.monthly => (months / every).ceil(),
      RepeatCadence.yearly => (months / (12 * every)).ceil(),
      _ => null,
    };
  }

  /// Total you'll have paid in by maturity = premium × periods. Null if either
  /// the premium [amount] or the period count is unknown.
  double? get totalPaidIn {
    final periods = premiumPeriods;
    if (amount == null || periods == null) return null;
    return amount! * periods;
  }

  /// Net gain = what you get back − what you put in. Null if either is unknown.
  double? get netGain {
    final paid = totalPaidIn;
    if (returnAmount == null || paid == null) return null;
    return returnAmount! - paid;
  }
  bool get hasIcon => (iconName != null && iconName!.isNotEmpty);
  bool get hasAmount => amount != null;
  bool get hasDocument => documentPath != null && documentPath!.isNotEmpty;
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// The task's category — the explicit one if set, else a best-guess from its
  /// fields. Always returns something (never null), so the Home can group.
  TaskCategory get category =>
      storedCategory ?? inferCategory(this);

  Task copyWith({
    String? title,
    bool? done,
    bool? reminderOn,
    DateTime? dueAt,
    bool clearDueAt = false,
    RepeatCadence? repeat,
    int? repeatTimes,
    List<int>? repeatDays,
    String? iconName,
    String? iconDomain,
    double? amount,
    bool clearAmount = false,
    String? currency,
    String? documentPath,
    String? imagePath,
    bool clearImage = false,
    TaskCategory? category,
    String? subCategory,
    String? note,
    bool clearNote = false,
    List<String>? doseTimes,
    int? courseDays,
    bool clearCourseDays = false,
    int? birthYear,
    bool clearBirthYear = false,
    int? remindDaysBefore,
    double? returnAmount,
    bool clearReturnAmount = false,
    DateTime? maturityAt,
    bool clearMaturityAt = false,
    PayoutMethod? payoutMethod,
    double? payoutAmount,
    bool clearPayoutAmount = false,
    int? payoutCount,
    bool clearPayoutCount = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      done: done ?? this.done,
      reminderOn: reminderOn ?? this.reminderOn,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      repeat: repeat ?? this.repeat,
      repeatTimes: repeatTimes ?? this.repeatTimes,
      repeatDays: repeatDays ?? this.repeatDays,
      iconName: iconName ?? this.iconName,
      iconDomain: iconDomain ?? this.iconDomain,
      amount: clearAmount ? null : (amount ?? this.amount),
      currency: currency ?? this.currency,
      documentPath: documentPath ?? this.documentPath,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      storedCategory: category ?? storedCategory,
      subCategory: subCategory ?? this.subCategory,
      note: clearNote ? null : (note ?? this.note),
      doseTimes: doseTimes ?? this.doseTimes,
      courseDays: clearCourseDays ? null : (courseDays ?? this.courseDays),
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      returnAmount:
          clearReturnAmount ? null : (returnAmount ?? this.returnAmount),
      maturityAt: clearMaturityAt ? null : (maturityAt ?? this.maturityAt),
      payoutMethod: payoutMethod ?? this.payoutMethod,
      payoutAmount:
          clearPayoutAmount ? null : (payoutAmount ?? this.payoutAmount),
      payoutCount: clearPayoutCount ? null : (payoutCount ?? this.payoutCount),
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
        'repeat_times': repeatTimes,
        if (repeatDays.isNotEmpty) 'repeat_days': repeatDays,
        'icon_name': iconName,
        'icon_domain': iconDomain,
        'amount': amount,
        'currency': currency,
        'document_path': documentPath,
        // Local-only image path — persisted in the on-device cache; the server
        // ignores unknown fields.
        'image_path': imagePath,
        if (storedCategory != null) 'category': storedCategory!.name,
        if (subCategory != null) 'sub_category': subCategory,
        if (note != null) 'note': note,
        if (doseTimes.isNotEmpty) 'dose_times': doseTimes,
        if (courseDays != null) 'course_days': courseDays,
        if (birthYear != null) 'birth_year': birthYear,
        'remind_days_before': remindDaysBefore,
        // Policy "return" side — snake_case; the server roundtrips/ignores
        // unknown fields (same as image_path), so this stays build-safe.
        if (returnAmount != null) 'return_amount': returnAmount,
        if (maturityAt != null) 'maturity_at': maturityAt!.toIso8601String(),
        if (payoutMethod != null) 'payout_method': payoutMethod!.name,
        if (payoutAmount != null) 'payout_amount': payoutAmount,
        if (payoutCount != null) 'payout_count': payoutCount,
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
        repeatTimes: (j['repeat_times'] as num?)?.toInt() ?? 1,
        repeatDays: (j['repeat_days'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        iconName: j['icon_name'] as String?,
        iconDomain: j['icon_domain'] as String?,
        amount: (j['amount'] as num?)?.toDouble(),
        currency: j['currency'] as String? ?? 'INR',
        documentPath: j['document_path'] as String?,
        imagePath: j['image_path'] as String?,
        storedCategory: j['category'] == null
            ? null
            : TaskCategory.values.firstWhere(
                (c) => c.name == j['category'],
                orElse: () => TaskCategory.other,
              ),
        subCategory: j['sub_category'] as String?,
        note: j['note'] as String?,
        doseTimes: (j['dose_times'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        courseDays: (j['course_days'] as num?)?.toInt(),
        birthYear: (j['birth_year'] as num?)?.toInt(),
        remindDaysBefore: (j['remind_days_before'] as num?)?.toInt() ?? 0,
        returnAmount: (j['return_amount'] as num?)?.toDouble(),
        maturityAt: j['maturity_at'] == null
            ? null
            : DateTime.tryParse(j['maturity_at'] as String),
        payoutMethod: j['payout_method'] == null
            ? null
            : PayoutMethod.values.firstWhere(
                (p) => p.name == j['payout_method'],
                orElse: () => PayoutMethod.lumpSum,
              ),
        payoutAmount: (j['payout_amount'] as num?)?.toDouble(),
        payoutCount: (j['payout_count'] as num?)?.toInt(),
      );
}
