import 'package:flutter/material.dart';

import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import 'add_picker_page.dart';
import 'birthday_form_page.dart';
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

/// The home "+" entry point: pick a reminder from the catalog (or type your
/// own), then fill the tailored form pre-seeded with that choice. Returns an
/// [AddResult], or null if the user backed out at any step.
Future<AddResult?> openAddFlow(BuildContext context, TaskStore store) async {
  // Step 1: the catalog picker.
  final pick = await Navigator.of(context).push<AddPickerResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AddPickerPage(),
    ),
  );
  if (pick == null || !context.mounted) return null;

  // Birthdays get their own tailored form (person + date, no price/cycle) —
  // whether a specific birthday item was tapped OR the whole "Important dates"
  // category row was chosen.
  final isBirthday = pick.item?.label == 'Birthday' ||
      pick.item?.label == 'Wedding anniversary' ||
      pick.category?.key == 'important_dates';
  if (isBirthday) {
    final task = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BirthdayFormPage(),
      ),
    );
    return task == null ? null : AddResult(task: task);
  }

  // Everything else → the general reminder form, pre-seeded with the picked
  // item's name + cadence + category accent (or the name the user typed).
  final name = pick.item?.label ?? pick.query;
  final task = await Navigator.of(context).push<Task>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SubscriptionFormPage(
        initialName: name,
        initialCycle: pick.item?.defaultRepeat,
        title: name ?? 'New reminder',
        accent: pick.category?.color,
      ),
    ),
  );
  return task == null ? null : AddResult(task: task);
}
