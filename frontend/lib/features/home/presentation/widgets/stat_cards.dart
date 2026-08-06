import 'package:flutter/material.dart';

import '../../../tasks/domain/task_filter.dart';
import '../../domain/home_groups.dart';

/// The four coloured stat cards at the top of Home — Scheduled, Unscheduled,
/// Active, Completed. Each shows a live count; tapping one filters the list
/// below (tap the selected one again to clear back to All).
class StatCards extends StatelessWidget {
  const StatCards({
    super.key,
    required this.stats,
    required this.active,
    required this.onTap,
  });

  final HomeStats stats;

  /// The currently applied filter (TaskFilter.all → none selected).
  final TaskFilter active;
  final ValueChanged<TaskFilter> onTap;

  static const _cards = <(TaskFilter, String, IconData, Color)>[
    (TaskFilter.scheduled, 'Scheduled', Icons.event_available_rounded, Color(0xFFEB5757)),
    (TaskFilter.unscheduled, 'Unscheduled', Icons.inbox_rounded, Color(0xFF2F80ED)),
    (TaskFilter.active, 'Active', Icons.bolt_rounded, Color(0xFF27AE60)),
    (TaskFilter.completed, 'Completed', Icons.check_circle_rounded, Color(0xFF9B51E0)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        for (final (filter, label, icon, color) in _cards)
          _StatCard(
            label: label,
            icon: icon,
            color: color,
            count: stats.countFor(filter),
            selected: active == filter,
            onTap: () => onTap(filter),
          ),
      ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.14)!],
          ),
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: Colors.white, width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? 0.45 : 0.28),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
