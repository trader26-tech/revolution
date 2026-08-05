import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/task.dart';

/// The details sheet — set/update a task's reminder, date, time, and repeat.
/// Modeled on the reference: a Reminder toggle, an "on <date> at <time>" block,
/// and a Repeat control. Returns the edited [Task], or null if dismissed.
Future<Task?> showTaskDetailsSheet(BuildContext context, Task task) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TaskDetailsSheet(task: task),
  );
}

class _TaskDetailsSheet extends StatefulWidget {
  const _TaskDetailsSheet({required this.task});
  final Task task;

  @override
  State<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<_TaskDetailsSheet> {
  late bool _reminderOn = widget.task.reminderOn;
  late DateTime _due =
      widget.task.dueAt ?? _defaultDue();
  late RepeatCadence _repeat = widget.task.repeat;

  static DateTime _defaultDue() {
    final now = DateTime.now();
    // Default to today at the next round hour.
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  void _save() {
    Navigator.of(context).pop(
      widget.task.copyWith(
        reminderOn: _reminderOn,
        dueAt: _reminderOn ? _due : null,
        clearDueAt: !_reminderOn,
        repeat: _repeat,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
    );
    if (picked != null) {
      setState(() => _due =
          DateTime(picked.year, picked.month, picked.day, _due.hour, _due.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (picked != null) {
      setState(() => _due = DateTime(
          _due.year, _due.month, _due.day, picked.hour, picked.minute));
    }
  }

  Future<void> _pickRepeat() async {
    final picked = await showModalBottomSheet<RepeatCadence>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in RepeatCadence.values)
              ListTile(
                title: Text(r.label),
                trailing: r == _repeat
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _repeat = picked);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title + a check to confirm.
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, color: AppColors.accent),
                  tooltip: 'Done',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reminder on/off.
            _Row(
              label: 'Reminder',
              trailing: Switch(
                value: _reminderOn,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.accent,
                onChanged: (v) => setState(() => _reminderOn = v),
              ),
            ),

            // Everything below only matters when the reminder is on.
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _reminderOn
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              secondChild: const SizedBox(width: double.infinity),
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _Row(
                    label: 'On',
                    trailing: _Chip(
                      text: _fmtDate(_due),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'At',
                    trailing: _Chip(
                      text: _fmtTime(_due),
                      onTap: _pickTime,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'Repeat',
                    trailing: _Chip(
                      text: _repeat.label,
                      onTap: _pickRepeat,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}
