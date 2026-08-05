import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/task.dart';
import 'animated_check_circle.dart';

/// A single task in the home list.
///
/// Default: a check circle, the title, a due-date subtitle, and a chevron (▸)
/// on the right. Tapping the chevron **reveals actions**: the row content slides
/// left, the check circle fades away, and Details + Delete buttons appear on the
/// right. Tapping the chevron again collapses it.
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

  static const _dur = Duration(milliseconds: 240);
  static const _curve = Curves.easeOutCubic;

  void _toggleOpen() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return InkWell(
      // Tapping the body opens details only when actions aren't revealed;
      // otherwise a body tap collapses the actions.
      onTap: _open ? _toggleOpen : widget.onOpenDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: task.done ? 0.6 : 1.0,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              // The revealed actions, pinned right. They sit behind the sliding
              // content and become tappable as it moves off them.
              _RevealedActions(
                visible: _open,
                onDetails: widget.onOpenDetails,
                onDelete: widget.onDelete,
              ),
              // The main content — slides left when open to expose the actions.
              AnimatedSlide(
                duration: _dur,
                curve: _curve,
                offset: _open ? const Offset(-0.42, 0) : Offset.zero,
                child: Row(
                  children: [
                    // The check circle fades out while actions are shown.
                    AnimatedSize(
                      duration: _dur,
                      curve: _curve,
                      child: _open
                          ? const SizedBox(width: 0, height: 20)
                          : Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: AnimatedCheckCircle(
                                checked: task.done,
                                onTap: widget.onToggle,
                                size: 20,
                              ),
                            ),
                    ),
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
                              color:
                                  task.done ? AppColors.inkFaint : AppColors.ink,
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : null,
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
                    // The chevron toggles the reveal; it rotates to point back.
                    IconButton(
                      onPressed: _toggleOpen,
                      visualDensity: VisualDensity.compact,
                      icon: AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: _dur,
                        curve: _curve,
                        child: const Icon(Icons.chevron_right_rounded,
                            size: 22, color: AppColors.inkFaint),
                      ),
                    ),
                  ],
                ),
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

/// The Details + Delete actions revealed on the right when the tile is open.
class _RevealedActions extends StatelessWidget {
  const _RevealedActions({
    required this.visible,
    required this.onDetails,
    required this.onDelete,
  });

  final bool visible;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.tune_rounded,
              label: 'Details',
              color: AppColors.accentDeep,
              onTap: onDetails,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: const Color(0xFFE5484D),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
