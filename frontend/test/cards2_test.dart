import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/core/theme/app_theme.dart';
import 'package:revolution/features/home/presentation/widgets/stat_cards.dart';
import 'package:revolution/features/home/domain/home_groups.dart';
import 'package:revolution/features/tasks/domain/task_filter.dart';

void main() {
  testWidgets('t', (tester) async {
    const stats = HomeStats(scheduled: 128, unscheduled: 3, active: 60, completed: 24);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16),
        child: StatCards(stats: stats, active: TaskFilter.all, onTap: (_) {})))));
    await tester.pump();
  });
}
