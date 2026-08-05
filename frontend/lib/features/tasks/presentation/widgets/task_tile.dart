import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/task.dart';
import 'animated_check_circle.dart';

/// A single task in the home list.
///
/// A check circle, the title, a due-date subtitle, and a chevron (▸) on the
/// right. Tapping the **row body** opens the details page. Tapping the
/// **chevron** morphs it into a red **Delete** button (the row content shifts
/// left to make room), so deleting clearly lives on the right; tapping Delete
/// removes the task.
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpenDetails,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onOpenDetails;
  final VoidCallback onDelete;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool _open = false;

  void _toggleOpen() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return InkWell(
      // Tapping the row body always goes to the details page. (The chevron on
      // the right is a separate tap that reveals Delete.)
      onTap: widget.onOpenDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: task.done ? 0.6 : 1.0,
          child: Row(
            children: [
              AnimatedCheckCircle(
                checked: task.done,
                onTap: widget.onToggle,
                size: 20,
              ),
              const SizedBox(width: 12),
              // Title + subtitle. Expanded → shrinks to leave room for Delete.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      child: Text(task.title, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(task),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: task.isScheduled && task.reminderOn
                            ? AppColors.accentDeep
                            : AppColors.inkFaint,
                        fontWeight:
                            task.isScheduled ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // The right control: a chevron that morphs into a Delete button.
              // Tap the chevron → it becomes Delete; tap Delete → removes it.
              // (Tapping elsewhere collapses it back to the chevron.)
              _TrailingControl(
                open: _open,
                onReveal: _toggleOpen,
                onDelete: widget.onDelete,
              ),
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

/// The right-hand control that morphs between a chevron and a Delete button.
///
///  * Closed → a grey chevron (▸). Tap it to reveal Delete.
///  * Open   → a red "Delete" pill. Tap it to remove the task.
///
/// The swap is animated so the chevron visibly turns into the delete control,
/// signalling "the delete lives here, on the right".
class _TrailingControl extends StatelessWidget {
  const _TrailingControl({
    required this.open,
    required this.onReveal,
    required this.onDelete,
  });

  final bool open;
  final VoidCallback onReveal;
  final VoidCallback onDelete;

  static const _red = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: open
            ? Material(
                key: const ValueKey('delete'),
                color: _red,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : IconButton(
                key: const ValueKey('chevron'),
                onPressed: onReveal,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_right_rounded,
                    size: 24, color: AppColors.inkFaint),
              ),
      ),
    );
  }
}
