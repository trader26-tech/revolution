// Throwaway preview: typography sampler. Not shipped.
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
          child: Center(
            child: SizedBox(
              width: 393,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Never miss\na renewal again.',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text('Jot down everything you want to remember.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.inkSoft)),
                  const SizedBox(height: 24),
                  Text('THIS WEEK',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.inkFaint, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  ...[
                    Task(id: '1', title: 'Renew car insurance'),
                    Task(id: '2', title: 'Pay electricity bill', done: true),
                    Task(id: '3', title: 'Passport renewal'),
                  ].map((t) => Column(children: [
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
                      ])),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () {}, child: const Text('Add items')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
