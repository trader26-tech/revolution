import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/presentation/widgets/task_tile.dart';

/// A titled group of tasks on Home (Today / Tomorrow / Scheduled). Shows a
/// header with the title + count and, when [collapsible], a chevron to
/// expand/collapse. Today & Tomorrow are always open; Scheduled collapses.
class TaskSection extends StatelessWidget {
  const TaskSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.onToggleTask,
    required this.onOpenTask,
    required this.onDeleteTask,
    this.collapsible = false,
    this.expanded = true,
    this.onToggleExpanded,
  });

  final String title;
  final List<Task> tasks;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<Task> onOpenTask;
  final ValueChanged<Task> onDeleteTask;

  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — tappable when collapsible.
        GestureDetector(
          onTap: collapsible ? onToggleExpanded : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                _CountBadge(count: tasks.length),
                const Spacer(),
                if (collapsible)
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.inkSoft),
                  ),
              ],
            ),
          ),
        ),
        // Body.
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
              expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Column(
            children: [
              for (final t in tasks)
                TaskTile(
                  task: t,
                  onToggle: () => onToggleTask(t),
                  onOpenDetails: () => onOpenTask(t),
                  onDelete: () => onDeleteTask(t),
                ),
            ],
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.accentDeep,
        ),
      ),
    );
  }
}
