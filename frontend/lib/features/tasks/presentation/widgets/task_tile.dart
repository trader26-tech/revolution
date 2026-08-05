import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/task.dart';
import 'animated_check_circle.dart';

/// A single task in the home list.
///
/// A check circle, the title, a due-date subtitle, and a chevron (▸) on the
/// right. Interaction:
///  * Tap the **row body** → open the details page.
///  * Tap the **chevron** → the row content shifts left (the check circle
///    collapses) and a red **Delete** slides in on the right. The chevron
///    rotates to point back (◂) and stays as the close control — tap it, or
///    anywhere on the row, to slide it all back. So the reveal is fully
///    reversible; there is never a dead end.
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
      // Open → a body tap closes the actions (so there's always an escape).
      // Closed → a body tap opens the details page.
      onTap: _open ? _toggleOpen : widget.onOpenDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: task.done ? 0.6 : 1.0,
          child: Row(
            children: [
              // Check circle — collapses away when actions are open so the
              // content shifts left, exposing Delete on the right.
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
              // The Delete button slides in from the right when open.
              AnimatedSize(
                duration: _dur,
                curve: _curve,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _DeletePill(onTap: widget.onDelete),
                      )
                    : const SizedBox(height: 40),
              ),
              // The chevron is always present and is the open/close toggle. It
              // rotates to point back (◂) when open, so it clearly reverses.
              IconButton(
                onPressed: _toggleOpen,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: _open ? 'Close' : 'More',
                icon: AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: _dur,
                  curve: _curve,
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 24, color: AppColors.inkFaint),
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

/// The red "Delete" pill revealed on the right when the tile is open.
class _DeletePill extends StatelessWidget {
  const _DeletePill({required this.onTap});

  final VoidCallback onTap;

  static const _red = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _red,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
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
    );
  }
}
