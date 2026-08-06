import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task_filter.dart';
import '../../domain/home_groups.dart';

/// The four stat cards at the top of Home — Scheduled, Unscheduled, Active,
/// Completed. Each is a soft, colour-tinted card with a solid icon badge, a big
/// number, and a label. Tapping one filters the list below; tapping the selected
/// one again clears back to All.
class StatCards extends StatelessWidget {
  const StatCards({
    super.key,
    required this.stats,
    required this.active,
    required this.onTap,
  });

  final HomeStats stats;
  final TaskFilter active; // TaskFilter.all → none selected
  final ValueChanged<TaskFilter> onTap;

  static const _cards = <(TaskFilter, String, IconData, Color)>[
    (TaskFilter.scheduled, 'Scheduled', Icons.event_available_rounded, Color(0xFF3B82F6)),
    (TaskFilter.unscheduled, 'Unscheduled', Icons.inbox_rounded, Color(0xFFEF4444)),
    (TaskFilter.active, 'Active', Icons.bolt_rounded, Color(0xFF10B981)),
    (TaskFilter.completed, 'Completed', Icons.task_alt_rounded, Color(0xFF8B5CF6)),
  ];

  @override
  Widget build(BuildContext context) {
    // Fixed, comfortable card height — never depends on a fragile aspect ratio,
    // so the content always fits regardless of screen width.
    const rowGap = 12.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _card(_cards[0])),
            const SizedBox(width: rowGap),
            Expanded(child: _card(_cards[1])),
          ],
        ),
        const SizedBox(height: rowGap),
        Row(
          children: [
            Expanded(child: _card(_cards[2])),
            const SizedBox(width: rowGap),
            Expanded(child: _card(_cards[3])),
          ],
        ),
      ],
    );
  }

  Widget _card((TaskFilter, String, IconData, Color) c) {
    final (filter, label, icon, color) = c;
    return _StatCard(
      label: label,
      icon: icon,
      color: color,
      count: stats.countFor(filter),
      selected: active == filter,
      onTap: () => onTap(filter),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A gentle wash of the card's colour — calm, never harsh.
    final tint = Color.alphaBlend(color.withValues(alpha: 0.07), AppColors.card);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.14),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? 0.22 : 0.10),
              blurRadius: selected ? 20 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon badge on the left, count to its right.
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Label below, on its own line.
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
