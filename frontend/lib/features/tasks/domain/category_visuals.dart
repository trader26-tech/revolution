import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'task.dart';

/// One place for a category's icon + accent, shared by the browse grid, the
/// collection pages, the Up Next cards, and the task list so every surface
/// speaks the same visual language.
extension TaskCategoryVisuals on TaskCategory {
  IconData get icon => switch (this) {
        TaskCategory.subscription => Icons.subscriptions_rounded,
        TaskCategory.birthday => Icons.cake_rounded,
        TaskCategory.insurance => Icons.shield_rounded,
        TaskCategory.investment => Icons.savings_rounded,
        TaskCategory.bills => Icons.receipt_long_rounded,
        TaskCategory.policies => Icons.account_balance_rounded,
        TaskCategory.other => Icons.auto_awesome_rounded,
      };

  Color get color => switch (this) {
        TaskCategory.subscription => AppColors.accent, // violet
        TaskCategory.birthday => const Color(0xFFFF6FB5), // warm pink
        TaskCategory.insurance => const Color(0xFF34D399), // green
        TaskCategory.investment => const Color(0xFF4ADE80), // fresh green
        TaskCategory.bills => const Color(0xFFFBBF24), // amber
        TaskCategory.policies => const Color(0xFFF0B429), // gold — money returns
        TaskCategory.other => const Color(0xFFA5B4FC), // soft indigo
      };
}

/// The categories offered in the Home browse grid, in display order. "Other"
/// is intentionally excluded from the grid (the "All" tile covers it).
const List<TaskCategory> kBrowseCategories = [
  TaskCategory.subscription,
  TaskCategory.birthday,
  TaskCategory.investment,
  TaskCategory.policies,
  // Insurance & Bills temporarily removed from browse — add back later.
];
