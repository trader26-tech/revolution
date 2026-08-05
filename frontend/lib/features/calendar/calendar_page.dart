import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The Calendar screen — minimal placeholder for the fresh template.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Calendar',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
          const Expanded(
            child: Center(
              child: Icon(Icons.calendar_month_rounded,
                  size: 56, color: AppColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
