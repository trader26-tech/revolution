import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/domain/task.dart';
import 'widgets/orbit_form.dart';

/// The Medicines form — a clear, guided way to set up a medication reminder:
///   • the medicine NAME,
///   • the TIMES OF DAY each dose is taken (8:00 AM · 2:00 PM · 8:00 PM…),
///   • the DAYS it's taken (every day, or specific weekdays), and
///   • how many DAYS the course runs (or ongoing).
/// A plain-English summary ("3 times a day, every day, for 7 days") keeps the
/// whole schedule legible at a glance.
///
/// Returns a ready-to-save [Task] (category `medicine`), the edited copy in edit
/// mode, or null if cancelled.
class MedicineFormPage extends StatefulWidget {
  const MedicineFormPage({super.key, this.editTask, this.onDelete});

  final Task? editTask;

  /// Edit mode only — confirm + delete this task (returns true when deleted).
  final Future<bool> Function()? onDelete;

  @override
  State<MedicineFormPage> createState() => _MedicineFormPageState();
}

class _MedicineFormPageState extends State<MedicineFormPage> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  /// Dose times as minutes-since-midnight, kept sorted. Rendered as "8:00 AM".
  final List<int> _times = [8 * 60]; // default: one dose at 8:00 AM

  /// Selected weekdays (1 = Mon … 7 = Sun). Empty = EVERY day.
  final Set<int> _days = {};

  /// Course length in days. 0 = ongoing (no end).
  int _courseDays = 7;

  bool get _isEdit => widget.editTask != null;
  bool get _valid => _name.text.trim().isNotEmpty && _times.isNotEmpty;
  bool get _everyDay => _days.isEmpty || _days.length == 7;

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    if (t != null) {
      _name.text = t.title;
      if (t.doseTimes.isNotEmpty) {
        _times
          ..clear()
          ..addAll(t.doseTimes.map(_parseTime).whereType<int>());
        _times.sort();
        if (_times.isEmpty) _times.add(8 * 60);
      }
      if (t.repeatDays.isNotEmpty) _days.addAll(t.repeatDays);
      _courseDays = t.courseDays ?? 0;
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  static int? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  String _fmt(int mins) {
    final t = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  String _hhmm(int mins) =>
      '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'When is this dose?',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.card,
            onSurface: AppColors.ink,
          ),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: AppColors.bgTop,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final mins = picked.hour * 60 + picked.minute;
      if (!_times.contains(mins)) {
        setState(() {
          _times.add(mins);
          _times.sort();
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final deleted = await widget.onDelete!();
    if (deleted && mounted) Navigator.of(context).pop();
  }

  void _save() {
    if (!_valid) return;
    HapticFeedback.lightImpact();
    final times = _times.map(_hhmm).toList();
    // The reminder's dueAt = today at the FIRST dose time; the daily repeat +
    // dose times drive the actual per-dose notifications.
    final now = DateTime.now();
    final first = _times.first;
    final due =
        DateTime(now.year, now.month, now.day, first ~/ 60, first % 60);
    // Empty _days means "every day" → store no specific weekdays; otherwise the
    // chosen weekdays.
    final days = _everyDay ? <int>[] : (_days.toList()..sort());
    final course = _courseDays <= 0 ? null : _courseDays;

    final edit = widget.editTask;
    if (edit != null) {
      Navigator.of(context).pop(edit.copyWith(
        title: _name.text.trim(),
        dueAt: due,
        repeat: RepeatCadence.daily,
        repeatDays: days,
        doseTimes: times,
        courseDays: course,
        clearCourseDays: course == null,
        category: TaskCategory.medicine,
      ));
      return;
    }
    Navigator.of(context).pop(Task(
      id: 'new',
      title: _name.text.trim(),
      dueAt: due,
      repeat: RepeatCadence.daily,
      repeatDays: days,
      doseTimes: times,
      courseDays: course,
      storedCategory: TaskCategory.medicine,
    ));
  }

  /// A plain-English summary of the whole schedule.
  String get _summary {
    final n = _times.length;
    final freq = n == 1 ? 'Once a day' : '$n times a day';
    final when = _everyDay
        ? 'every day'
        : 'on ${(_days.toList()..sort()).map(_dayName).join(', ')}';
    final dur = _courseDays <= 0 ? 'ongoing' : 'for $_courseDays days';
    return '$freq, $when, $dur.';
  }

  static String _dayName(int d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            OrbitFormHeader(
              title: _isEdit ? 'Edit medicine' : 'Add a medicine',
              canSave: _valid,
              onBack: () => Navigator.of(context).maybePop(),
              onSave: _save,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  // ── Name ──
                  _NameCard(
                    controller: _name,
                    focus: _nameFocus,
                    autofocus: !_isEdit,
                  ),
                  const OrbitSaveHint(),
                  const SizedBox(height: 20),

                  // ── Times of day ──
                  const _GroupLabel('TIMES OF DAY'),
                  const SizedBox(height: 10),
                  _TimesCard(
                    times: _times,
                    fmt: _fmt,
                    onAdd: _addTime,
                    onRemove: (mins) => setState(() {
                      if (_times.length > 1) _times.remove(mins);
                    }),
                  ),
                  const SizedBox(height: 22),

                  // ── Which days ──
                  const _GroupLabel('WHICH DAYS'),
                  const SizedBox(height: 10),
                  _DaysCard(
                    days: _days,
                    everyDay: _everyDay,
                    labels: _weekdayLabels,
                    onEveryDay: () => setState(_days.clear),
                    onToggle: (d) => setState(() {
                      _days.contains(d) ? _days.remove(d) : _days.add(d);
                    }),
                  ),
                  const SizedBox(height: 22),

                  // ── Course length ──
                  const _GroupLabel('FOR HOW LONG'),
                  const SizedBox(height: 10),
                  OrbitGroupCard(
                    children: [
                      _CourseRow(
                        days: _courseDays,
                        onChanged: (d) => setState(() => _courseDays = d),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.inkFaint.withValues(alpha: 0.9)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _courseDays <= 0
                                ? 'Ongoing — no end date. Tap + to set how many '
                                    'days it lasts.'
                                : 'It’ll remind you for $_courseDays days, then '
                                    'stop. Tap − down to “Ongoing” for no end.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── The plain-English summary ──
                  _SummaryStrip(text: _summary),
                  if (widget.onDelete != null)
                    OrbitDeleteButton(onDelete: _handleDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

// ── Name card ────────────────────────────────────────────────────────────────

class _NameCard extends StatelessWidget {
  const _NameCard({
    required this.controller,
    required this.focus,
    this.autofocus = false,
  });

  /// Only raise the keyboard when ADDING, never when editing an existing item.
  final bool autofocus;
  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.28),
                  AppColors.accent.withValues(alpha: 0.12),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.ink, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: autofocus,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: AppColors.accent,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Which medicine? (e.g. Metformin)',
                hintStyle: TextStyle(
                  color: AppColors.inkFaint,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dose times ───────────────────────────────────────────────────────────────

/// The dose times as a wrap of removable time pills, plus an "Add a time" pill.
class _TimesCard extends StatelessWidget {
  const _TimesCard({
    required this.times,
    required this.fmt,
    required this.onAdd,
    required this.onRemove,
  });
  final List<int> times;
  final String Function(int) fmt;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final t in times)
            _TimePill(label: fmt(t), onRemove: () => onRemove(t)),
          // The add pill.
          GestureDetector(
            onTap: onAdd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
                  SizedBox(width: 5),
                  Text('Add a time',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Which days ───────────────────────────────────────────────────────────────

class _DaysCard extends StatelessWidget {
  const _DaysCard({
    required this.days,
    required this.everyDay,
    required this.labels,
    required this.onEveryDay,
    required this.onToggle,
  });
  final Set<int> days;
  final bool everyDay;
  final List<String> labels;
  final VoidCallback onEveryDay;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Every day" toggle.
          GestureDetector(
            onTap: onEveryDay,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  everyDay
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: everyDay ? AppColors.accent : AppColors.inkFaint,
                ),
                const SizedBox(width: 10),
                const Text('Every day',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Or pick specific weekdays.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _DayDot(
                  label: labels[i],
                  selected: !everyDay && days.contains(i + 1),
                  onTap: () => onToggle(i + 1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.cardBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

// ── Course length row ────────────────────────────────────────────────────────

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.days, required this.onChanged});
  final int days; // 0 = ongoing
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ongoing = days <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Text(ongoing ? 'No end date' : 'Course length',
              style: orbitLabelStyle),
          const Spacer(),
          _btn(Icons.remove_rounded, days > 0, () {
            HapticFeedback.selectionClick();
            onChanged(days - 1); // 1 → 0 = ongoing
          }),
          // At 0 the value reads a clear word — "Ongoing" — so nobody has to
          // guess what ∞/0 means; otherwise "N days".
          SizedBox(
            width: 108,
            child: Text(
              ongoing ? 'Ongoing' : '$days ${days == 1 ? 'day' : 'days'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ongoing ? 15 : 16,
                fontWeight: FontWeight.w800,
                color: ongoing ? AppColors.accent : AppColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _btn(Icons.add_rounded, days < 365, () {
            HapticFeedback.selectionClick();
            onChanged(days + 1);
          }),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon,
            size: 18, color: enabled ? AppColors.accent : AppColors.inkFaint),
      ),
    );
  }
}

// ── Summary strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.14),
            AppColors.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
