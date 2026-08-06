import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/tasks/domain/task.dart';
import 'features/tasks/presentation/widgets/task_tile.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tasks = [
      // Real logo (Netflix) next to letter-avatar ones for comparison.
      Task(id: '0', title: 'Netflix', iconName: 'Netflix', iconDomain: 'netflix.com', dueAt: now, reminderOn: true),
      Task(id: '1', title: 'Renew car insurance', dueAt: now, reminderOn: true),
      Task(id: '2', title: 'Pay electricity bill', dueAt: now.add(const Duration(days: 2)), reminderOn: true),
      Task(id: '3', title: 'Gym membership'),
    ];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: SizedBox(
              width: 393,
              child: ListView.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, _) => const Divider(
                    height: 1, thickness: 1, indent: 20, endIndent: 20,
                    color: AppColors.hairline),
                itemBuilder: (_, i) => TaskTile(
                  task: tasks[i],
                  onToggle: () {},
                  onOpenDetails: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
