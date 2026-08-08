import 'package:flutter/material.dart';

import '../../brand/domain/brand.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import '../domain/add_category.dart';
import 'add_picker_page.dart';
import 'birthday_form_page.dart';
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
  // Step 1: the rich picker — pick a brand, a type, or type a name.
  final pick = await Navigator.of(context).push<AddPickerResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AddPickerPage(),
    ),
  );
  if (pick == null || !context.mounted) return null;

  // Birthday / Insurance route to their own tailored forms.
  if (pick.category == AddCategory.birthday) {
    final task = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BirthdayFormPage(),
      ),
    );
    return task == null ? null : AddResult(task: task);
  }
  if (pick.category == AddCategory.insurance) {
    // Insurance saves itself (task + document upload). Returns true on success.
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InsuranceFormPage(store: store),
      ),
    );
    return saved == true ? const AddResult(selfSaved: true) : null;
  }

  // Everything else → the subscription form, pre-filled with the chosen brand
  // (or the typed name) when there is one.
  final Brand? seed = pick.brand ??
      (pick.query != null ? Brand(name: pick.query!, domain: '') : null);
  final task = await Navigator.of(context).push<Task>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SubscriptionFormPage(initialBrand: seed),
    ),
  );
  return task == null ? null : AddResult(task: task);
}
