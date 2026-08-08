import 'package:flutter/material.dart';

import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import '../domain/add_category.dart';
import 'birthday_form_page.dart';
import 'category_picker_sheet.dart';
import 'insurance_form_page.dart';
import 'subscription_form_page.dart';

/// The result of the add flow. Most forms hand back a ready-to-save [Task] the
/// caller persists. Insurance saves itself (it needs the created task's id to
/// upload the document), so it returns [selfSaved] instead — the caller just
/// refreshes.
class AddResult {
  const AddResult({this.task, this.selfSaved = false});
  final Task? task;
  final bool selfSaved;
}

/// The home "+" entry point: pick a category, then fill its tailored form.
/// Returns an [AddResult], or null if the user backed out at any step. Needs the
/// [store] so the insurance form can create-then-upload directly.
Future<AddResult?> openAddFlow(BuildContext context, TaskStore store) async {
  final category = await showCategoryPicker(context);
  if (category == null || !context.mounted) return null;

  switch (category) {
    case AddCategory.subscription:
      final task = await Navigator.of(context).push<Task>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const SubscriptionFormPage(),
        ),
      );
      return task == null ? null : AddResult(task: task);
    case AddCategory.birthday:
      final task = await Navigator.of(context).push<Task>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const BirthdayFormPage(),
        ),
      );
      return task == null ? null : AddResult(task: task);
    case AddCategory.insurance:
      // Insurance saves itself (task + document upload). It returns true on
      // success; nothing more for the caller to persist.
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => InsuranceFormPage(store: store),
        ),
      );
      return saved == true ? const AddResult(selfSaved: true) : null;
  }
}
