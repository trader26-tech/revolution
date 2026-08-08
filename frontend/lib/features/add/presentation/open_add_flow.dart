import 'package:flutter/material.dart';

import '../../tasks/domain/task.dart';
import '../domain/add_category.dart';
import 'birthday_form_page.dart';
import 'category_picker_sheet.dart';
import 'subscription_form_page.dart';

/// The home "+" entry point: pick a category, then fill its tailored form.
/// Returns a ready-to-save [Task], or null if the user backed out at any step.
///
/// This is the single door the home screen calls. Adding a new category later
/// is one case here plus its form page — the picker and this switch are the only
/// wiring that grows.
Future<Task?> openAddFlow(BuildContext context) async {
  final category = await showCategoryPicker(context);
  if (category == null || !context.mounted) return null;

  switch (category) {
    case AddCategory.subscription:
      return Navigator.of(context).push<Task>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const SubscriptionFormPage(),
        ),
      );
    case AddCategory.birthday:
      return Navigator.of(context).push<Task>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const BirthdayFormPage(),
        ),
      );
  }
}
