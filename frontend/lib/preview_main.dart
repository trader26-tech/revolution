// Throwaway preview: pill-shaped add input above flat task rows. Not shipped.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/tasks/domain/task.dart';
import 'features/tasks/presentation/widgets/quick_add_row.dart';
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
          child: Center(
            child: SizedBox(
              width: 393,
              child: ListView(
                padding: const EdgeInsets.only(top: 10),
                children: [
                  QuickAddRow(
                    controller: TextEditingController(text: 'Renew car insurance'),
                    focusNode: FocusNode(),
                    onSubmitText: () {},
                    onTapOutsideEmpty: () {},
                    showHint: false,
                  ),
                  const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                      color: AppColors.hairline),
                  for (final t in [
                    Task(id: '2', title: 'Pay electricity bill'),
                    Task(id: '3', title: 'Passport renewal'),
                  ]) ...[
                    TaskTile(
                        task: t,
                        onToggle: () {},
                        onOpenDetails: () {},
                        onDelete: () {}),
                    const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                        color: AppColors.hairline),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
