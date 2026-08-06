import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../details/domain/item_details.dart';
import '../../details/presentation/item_details_page.dart';
import '../domain/task.dart';
import 'widgets/wheel_pickers.dart';

/// The details sheet — set/update a task's reminder, date, time, and repeat.
/// Modeled on the reference: a Reminder toggle, an "on `date` at `time`" block,
/// and a Repeat control. Returns the edited [Task], or null if dismissed.
///
/// When [requireDate] is true (used right after quick-adding a task), a date is
/// MANDATORY: the Reminder toggle is hidden/forced on, and dismissing without
/// setting one asks for confirmation — so tasks rarely stay unscheduled.
Future<Task?> showTaskDetailsSheet(
  BuildContext context,
  Task task, {
  bool requireDate = false,
}) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    // Make it harder to dismiss when a date is required.
    isDismissible: !requireDate,
    enableDrag: !requireDate,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TaskDetailsSheet(task: task, requireDate: requireDate),
  );
}

class _TaskDetailsSheet extends StatefulWidget {
  const _TaskDetailsSheet({required this.task, this.requireDate = false});
  final Task task;
  final bool requireDate;

  @override
  State<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<_TaskDetailsSheet> {
  // When a date is required, the reminder is always on.
  late bool _reminderOn = widget.requireDate ? true : widget.task.reminderOn;
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
    final picked = await showDateWheel(context, initial: _due);
    if (picked != null) {
      // Keep the existing time, take the new date.
      setState(() => _due = DateTime(
          picked.year, picked.month, picked.day, _due.hour, _due.minute));
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
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Repeat',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            for (final r in RepeatCadence.values)
              ListTile(
                title: Text(r.label),
                trailing: r == _repeat
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _repeat = picked);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return PopScope(
      // When a date is required, intercept back/dismiss and confirm first.
      canPop: !widget.requireDate,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !widget.requireDate) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmLeaveWithoutDate();
        if (leave == true) navigator.pop();
      },
      child: Padding(
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
                    icon:
                        const Icon(Icons.check_rounded, color: AppColors.accent),
                    tooltip: 'Done',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Reminder toggle — hidden when a date is required (always on).
              if (!widget.requireDate)
                _Row(
                  label: 'Reminder',
                  trailing: Switch(
                    value: _reminderOn,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    onChanged: (v) => setState(() => _reminderOn = v),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    'When is this due?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
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
                    label: 'Repeat',
                    trailing: _Chip(
                      text: _repeat.label,
                      onTap: _pickRepeat,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Open the full-screen rich editor (amount, cycle, list, category,
            // payment method, notification, URL, notes…).
            OutlinedButton.icon(
              onPressed: _openFullDetails,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Fill details'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppColors.accentDeep,
                side: const BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirm dialog shown when the user tries to leave the required-date sheet
  /// without setting a date — deliberate friction so it rarely happens.
  Future<bool?> _confirmLeaveWithoutDate() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Leave without a date?'),
        content: const Text(
          'This task will sit in “Unscheduled” until you set a date.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Set a date'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave',
                style: TextStyle(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }

  Future<void> _openFullDetails() async {
    final result = await Navigator.of(context).push<ItemDetails>(
      MaterialPageRoute(
        builder: (_) => ItemDetailsPage(
          title: widget.task.title.isEmpty ? 'Details' : widget.task.title,
          // Carry the task's current name AND icon into the form, so re-opening
          // keeps what was already chosen.
          initial: ItemDetails(
            name: widget.task.title,
            iconName: widget.task.iconName,
            iconDomain: widget.task.iconDomain,
            amount: widget.task.amount,
            currency: widget.task.currency,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;

    // Build the updated task from the details result — title, ICON, and the
    // sheet's reminder state — and close the SHEET returning it, so Home
    // persists it via store.update and the user lands back on Home.
    final updated = widget.task.copyWith(
      title: result.name.isNotEmpty ? result.name : null,
      reminderOn: _reminderOn,
      dueAt: _reminderOn ? _due : null,
      clearDueAt: !_reminderOn,
      repeat: _repeat,
      iconName: result.iconName,
      iconDomain: result.iconDomain,
      amount: result.amount,
      clearAmount: result.amount == null,
      currency: result.currency,
    );
    AppToast.show(context, message: 'Saved');
    // Pop THIS sheet (not the root) with the result, so showTaskDetailsSheet's
    // future resolves to `updated` and Home receives it.
    Navigator.of(context).pop(updated);
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
