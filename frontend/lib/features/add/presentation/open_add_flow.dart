import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';
import 'add_picker_page.dart';
import 'birthday_form_page.dart';
import 'general_form_page.dart';
import 'medicine_form_page.dart';
import 'insurance_form_page.dart';
import 'policy_form_page.dart';
import 'sip_form_page.dart';
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

  // Money & investments → the tailored SIP form (amount + platform + cadence).
  // Whether the whole "Money & investments" row or a specific SIP item was
  // tapped.
  final isSip = pick.category?.key == 'investments' ||
      pick.item?.label == 'SIP investment';
  if (isSip) {
    final task = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SipFormPage(
          initialName: pick.item?.label,
          accent: pick.category?.color,
        ),
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

/// Jump STRAIGHT into a category's tailored form (skipping the catalog picker) —
/// used by a category collection page's "+", so adding a subscription from the
/// Subscriptions page lands right on the subscription form. Returns an
/// [AddResult] or null if cancelled.
Future<AddResult?> openCategoryForm(
  BuildContext context,
  TaskStore store,
  TaskCategory category,
) async {
  switch (category) {
    case TaskCategory.birthday:
      final task = await Navigator.of(context)
          .push<Task>(_formRoute(const BirthdayFormPage()));
      return task == null ? null : AddResult(task: task);

    case TaskCategory.investment:
      final task = await Navigator.of(context)
          .push<Task>(_formRoute(SipFormPage(accent: category.color)));
      return task == null ? null : AddResult(task: task);

    case TaskCategory.insurance:
      // Insurance self-saves (uploads a document to the new task's id).
      final saved = await Navigator.of(context)
          .push<bool>(_formRoute(InsuranceFormPage(store: store)));
      return saved == true ? const AddResult(selfSaved: true) : null;

    case TaskCategory.policies:
      // Policies self-save too (they can attach a document, and compute their
      // own return fields — no generic add path fits).
      final saved = await Navigator.of(context)
          .push<bool>(_formRoute(PolicyFormPage(store: store)));
      return saved == true ? const AddResult(selfSaved: true) : null;

    case TaskCategory.other:
      // General: the open catch-all — title + date + freeform note.
      final task = await Navigator.of(context)
          .push<Task>(_formRoute(const GeneralFormPage()));
      return task == null ? null : AddResult(task: task);

    case TaskCategory.medicine:
      // Medicines: name + dose times + days + course length.
      final task = await Navigator.of(context)
          .push<Task>(_formRoute(const MedicineFormPage()));
      return task == null ? null : AddResult(task: task);

    case TaskCategory.subscription:
    case TaskCategory.bills:
      final task = await Navigator.of(context).push<Task>(_formRoute(
        SubscriptionFormPage(
          title: category == TaskCategory.bills ? 'New bill' : 'New subscription',
          accent: category.color,
        ),
      ));
      if (task == null) return null;
      // A bill from the bills page keeps the bills category.
      if (category == TaskCategory.bills) {
        task.storedCategory = TaskCategory.bills;
      }
      return AddResult(task: task);
  }
}

/// The add-form route. It slides up like a fullscreen dialog on the way IN, but
/// closes with ZERO reverse animation — so the instant you press Save, the form
/// vanishes and the success celebration (pushed right after) is already there,
/// with no slide-down and no flash of the screen underneath.
PageRouteBuilder<T> _formRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    fullscreenDialog: true,
    // Longer + a gentle FADE + small RISE (not a full-height slam), with a real
    // reverse — so opening/closing a form reads calm and premium, not abrupt.
    transitionDuration: const Duration(milliseconds: 440),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06), // rise ~6% of height, not full screen
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Persist an [AddResult] to the store (the one place add-persistence lives, so
/// Home and every collection page save identically). Returns true if something
/// was actually added (so the caller can show the success moment). Insurance
/// already saved itself, so [AddResult.selfSaved] counts as added too.
Future<bool> persistAddResult(TaskStore store, AddResult? result) async {
  if (result == null) return false;
  final task = result.task;
  if (task == null) return result.selfSaved; // insurance self-saved
  await store.add(
    task.title,
    iconName: task.iconName,
    iconDomain: task.iconDomain,
    dueAt: task.dueAt,
    repeat: task.repeat,
    repeatTimes: task.repeatTimes,
    repeatDays: task.repeatDays,
    amount: task.amount,
    currency: task.currency,
    category: task.storedCategory?.name,
    imagePath: task.imagePath,
    subCategory: task.subCategory,
    note: task.note,
    doseTimes: task.doseTimes,
    courseDays: task.courseDays,
    birthYear: task.birthYear,
    remindDaysBefore: task.remindDaysBefore,
  );
  return true;
}

/// Open the RICH edit form for a task, routed by its category — the same
/// tailored form used to add it, prefilled. This is where every detail is shown
/// in full (no truncation) and can be changed. Subscriptions, SIPs and occasions
/// each open their own form; anything else falls back to [fallback] (the quick
/// details sheet). Persists the edit via [store] and returns true if it saved.
///
/// One place so Home and every collection page open edits identically.
Future<bool> openEditForm(
  BuildContext context,
  TaskStore store,
  Task task, {
  Future<Task?> Function()? fallback,
}) async {
  // In EDIT mode, every tailored form gets a delete button. The callback shows a
  // confirm, then removes via the store (which handles the optimistic delete +
  // undo toast). Returns true when the item was deleted, so the form pops.
  Future<bool> onDelete() => confirmAndDeleteTask(context, store, task);

  // Policies own their save (patch in place), so they short-circuit here and
  // return whether they saved — they never fall through to the store.update
  // roundtrip below.
  if (task.category == TaskCategory.policies) {
    final saved = await Navigator.of(context).push<bool>(
        _formRoute(PolicyFormPage(store: store, editTask: task, onDelete: onDelete)));
    return saved == true;
  }

  Widget? form;
  switch (task.category) {
    case TaskCategory.subscription:
      form = SubscriptionFormPage(editTask: task, onDelete: onDelete);
    case TaskCategory.investment:
      form = SipFormPage(editTask: task, onDelete: onDelete);
    case TaskCategory.birthday:
      form = BirthdayFormPage(editTask: task, onDelete: onDelete);
    case TaskCategory.other:
      // General reminders edit in their own title + date + note form.
      form = GeneralFormPage(editTask: task, onDelete: onDelete);
    case TaskCategory.medicine:
      // Medicines edit in their own dose-schedule form.
      form = MedicineFormPage(editTask: task, onDelete: onDelete);
    case TaskCategory.insurance:
    case TaskCategory.policies:
    case TaskCategory.bills:
      form = null; // no tailored form → use the fallback sheet
  }

  final Task? updated = form != null
      ? await Navigator.of(context).push<Task>(_formRoute(form))
      : await fallback?.call();

  if (updated == null) return false;
  store.update(updated);
  return true;
}

/// Confirm + delete a task from its edit screen. Shows a small confirmation
/// dialog; on confirm, removes via [store] (which does the optimistic delete +
/// undo toast + rollback). Returns true when deleted, so the caller pops the
/// edit form. Shared by every tailored edit form's delete button.
Future<bool> confirmAndDeleteTask(
    BuildContext context, TaskStore store, Task task) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      title: const Text('Delete this?',
          style: TextStyle(
              color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 18)),
      content: Text(
        '“${task.title}” will be removed. You can undo right after.',
        style: const TextStyle(color: AppColors.inkSoft, fontSize: 14.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete',
              style: TextStyle(
                  color: Color(0xFFFF6B6B), fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await store.remove(task);
  return true;
}
