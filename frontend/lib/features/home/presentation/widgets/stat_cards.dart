import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task_filter.dart';
import '../../domain/home_groups.dart';

/// The four stat cards at the top of Home — Scheduled (blue), Unscheduled (red),
/// Active, Completed. Sleek white cards with a colored accent strip, an icon
/// chip, and a big number. Tapping one filters the list below; tapping the
/// selected one again clears back to All.
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
    (TaskFilter.scheduled, 'Scheduled', Icons.event_available_rounded, Color(0xFF2F6BFF)),
    (TaskFilter.unscheduled, 'Unscheduled', Icons.inbox_rounded, Color(0xFFF0392B)),
    (TaskFilter.active, 'Active', Icons.bolt_rounded, Color(0xFF00A870)),
    (TaskFilter.completed, 'Completed', Icons.check_circle_rounded, Color(0xFF8A56E2)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.35,
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
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? color.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // ClipRRect so the accent strip follows the rounded corners.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored accent strip along the top.
              Container(height: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      // Icon chip in the card's color.
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
