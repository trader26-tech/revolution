import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/task.dart';
import 'animated_check_circle.dart';

/// A single task in the home list: a tappable check circle, the title, and a
/// due-date subtitle ("Tap to set a date" when unscheduled). Tapping the body
/// opens the details sheet.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // The completed row gently dims — a calm "done" feel.
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: task.done ? 0.6 : 1.0,
          child: Row(
            children: [
              AnimatedCheckCircle(
                checked: task.done,
                onTap: onToggle,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The title softens + strikes through smoothly when completed.
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: task.done ? AppColors.inkFaint : AppColors.ink,
                      decoration:
                          task.done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.inkFaint,
                    ),
                    child: Text(task.title),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(task),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: task.isScheduled && task.reminderOn
                          ? AppColors.accentDeep
                          : AppColors.inkFaint,
                      fontWeight: task.isScheduled
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(Task task) {
    if (!task.isScheduled) return 'Tap to set a date';
    final d = task.dueAt!;
    final base = '${_months[d.month - 1]} ${d.day}, ${d.year} · ${_time(d)}';
    if (task.repeat != RepeatCadence.none) {
      return '$base · ${task.repeat.label}';
    }
    return base;
  }

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? "AM" : "PM"}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
