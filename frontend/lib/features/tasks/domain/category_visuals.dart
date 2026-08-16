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
        TaskCategory.medicine => Icons.medication_rounded,
        TaskCategory.other => Icons.auto_awesome_rounded,
      };

  Color get color => switch (this) {
        TaskCategory.subscription => AppColors.accent, // violet
        TaskCategory.birthday => const Color(0xFFFF6FB5), // warm pink
        TaskCategory.insurance => const Color(0xFF34D399), // green
        TaskCategory.investment => const Color(0xFF4ADE80), // fresh green
        TaskCategory.bills => const Color(0xFFFBBF24), // amber
        TaskCategory.policies => const Color(0xFFF0B429), // gold — money returns
        TaskCategory.medicine => const Color(0xFF22D3EE), // cyan — health
        TaskCategory.other => const Color(0xFFA5B4FC), // soft indigo
      };
}

/// The categories offered as add/browse destinations, in display order.
/// `other` is the "General" catch-all (a free-form reminder + note); it leads
/// the Browse page's own list explicitly, so [kBrowseCategoriesNoGeneral]
/// excludes it there to avoid showing it twice.
const List<TaskCategory> kBrowseCategories = [
  TaskCategory.other, // "General"
  TaskCategory.subscription,
  TaskCategory.birthday,
  TaskCategory.investment,
  TaskCategory.medicine,
  // Policies hidden (General now covers amount + repeat); Insurance & Bills
  // temporarily removed from browse. The enum + PolicyFormPage stay so any
  // existing policy tasks still load/edit.
];

/// The same list WITHOUT the General catch-all — for surfaces that render
/// General separately (the Browse tab leads with it as a highlighted tile).
const List<TaskCategory> kBrowseCategoriesNoGeneral = [
  TaskCategory.subscription,
  TaskCategory.birthday,
  TaskCategory.investment,
  TaskCategory.medicine,
];
