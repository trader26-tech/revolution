// Throwaway preview: tile closed vs revealed actions. Not shipped.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/tasks/domain/task.dart';
import 'features/tasks/presentation/widgets/task_tile.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 0, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tap the ▸ chevron to reveal actions',
                      style: TextStyle(color: AppColors.inkFaint, fontSize: 12)),
                ),
              ),
              TaskTile(
                task: Task(id: '1', title: 'Renew car insurance'),
                onToggle: () {},
                onOpenDetails: () {},
                onDelete: () {},
              ),
              const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 20,
                  endIndent: 20,
                  color: AppColors.hairline),
              TaskTile(
                task: Task(id: '2', title: 'Passport renewal'),
                onToggle: () {},
                onOpenDetails: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
