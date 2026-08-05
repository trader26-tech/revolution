import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import '../tasks/presentation/widgets/task_tile.dart';

/// The Calendar screen — the scheduled tasks, soonest first. (A full month grid
/// can layer on later; for now it's the agenda of everything with a date.)
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.store});

  final TaskStore store;

  Future<void> _edit(BuildContext context, Task task) async {
    final updated = await showTaskDetailsSheet(context, task);
    if (updated != null) store.update(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Calendar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: store,
              builder: (context, _) {
                final scheduled = store.scheduled;
                if (scheduled.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              size: 56, color: AppColors.inkFaint),
                          SizedBox(height: 12),
                          Text('No scheduled tasks yet',
                              style: TextStyle(color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(top: 4, bottom: 120),
                  itemCount: scheduled.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                    color: AppColors.hairline,
                  ),
                  itemBuilder: (_, i) {
                    final t = scheduled[i];
                    return TaskTile(
                      task: t,
                      onToggle: () => store.toggleDone(t),
                      onTap: () => _edit(context, t),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
