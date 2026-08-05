import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/task_filter.dart';

/// A clean bottom sheet to choose which tasks to show. Returns the picked
/// [TaskFilter], or null if dismissed.
Future<TaskFilter?> showFilterSheet(
  BuildContext context, {
  required TaskFilter current,
}) {
  return showModalBottomSheet<TaskFilter>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FilterSheet(current: current),
  );
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.current});

  final TaskFilter current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            for (final f in TaskFilter.values)
              _FilterRow(filter: f, selected: f == current),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.selected});

  final TaskFilter filter;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(filter),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(
              filter.icon,
              size: 22,
              color: selected ? AppColors.accent : AppColors.inkSoft,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                filter.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.accentDeep : AppColors.ink,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
