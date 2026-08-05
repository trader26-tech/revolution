import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../domain/task.dart';
import 'animated_check_circle.dart';

/// A single task in the home list.
///
/// A check circle, the title, a due-date subtitle, and a chevron (▸) on the
/// right. Interaction:
///  * Tap the **row body** → open the details page.
///  * Tap the **chevron** → the row **expands downward** to reveal a subtle
///    Delete action in a section below. The chevron rotates to point down (▾).
///    Tap it again — or anywhere on the row — to collapse. Fully reversible.
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
      // Open → a body tap closes the panel. Closed → opens the details page.
      onTap: _open ? _toggleOpen : widget.onOpenDetails,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: task.done ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The main row — unchanged whether open or closed.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  AnimatedCheckCircle(
                    checked: task.done,
                    onTap: widget.onToggle,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  // The brand/app logo, when the task has one.
                  if (task.hasIcon) ...[
                    BrandLogo(
                      brand: Brand(
                        name: task.iconName ?? task.title,
                        domain: task.iconDomain ?? '',
                      ),
                      size: 36,
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                  ],
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
                          child:
                              Text(task.title, overflow: TextOverflow.ellipsis),
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
                            fontWeight: task.isScheduled
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The chevron opens/closes the panel below; it rotates to
                  // point down (▾) when open.
                  IconButton(
                    onPressed: _toggleOpen,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: _open ? 'Close' : 'More',
                    icon: AnimatedRotation(
                      turns: _open ? 0.25 : 0,
                      duration: _dur,
                      curve: _curve,
                      child: const Icon(Icons.chevron_right_rounded,
                          size: 24, color: AppColors.inkFaint),
                    ),
                  ),
                ],
              ),
            ),
            // The subtle drop-down section — a single quiet Delete action.
            AnimatedSize(
              duration: _dur,
              curve: _curve,
              alignment: Alignment.topCenter,
              child: _open
                  ? _DeleteSection(onDelete: widget.onDelete)
                  : const SizedBox(width: double.infinity),
            ),
          ],
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

/// The subtle drop-down section under a task when its chevron is open. A quiet
/// hairline, then a single understated Delete action — nothing shouty.
class _DeleteSection extends StatelessWidget {
  const _DeleteSection({required this.onDelete});

  final VoidCallback onDelete;

  static const _red = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.hairline,
        ),
        InkWell(
          onTap: onDelete,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 19, color: _red),
                SizedBox(width: 10),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: _red,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
