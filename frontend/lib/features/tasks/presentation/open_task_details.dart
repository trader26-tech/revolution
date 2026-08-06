import 'package:flutter/material.dart';

import '../../details/domain/item_details.dart';
import '../../details/presentation/item_details_page.dart';
import '../domain/task.dart';

/// Opens the full-screen details editor for a task — used for BOTH:
///   • creating a new item (`existing == null`) → titled "Add details"
///   • updating an item     (`existing != null`) → titled "Update details"
///
/// Returns the resulting [Task] (mapped from the form), or null if cancelled.
/// This is the single entry point so the + button and tapping a task both land
/// on the same clean full screen — no intermediate reminder/repeat sheet.
Future<Task?> openTaskDetails(
  BuildContext context, {
  Task? existing,
}) async {
  final isUpdate = existing != null;

  final result = await Navigator.of(context).push<ItemDetails>(
    MaterialPageRoute(
      fullscreenDialog: !isUpdate, // create feels like a modal; update pushes
      builder: (_) => ItemDetailsPage(
        title: isUpdate ? 'Update details' : 'Add details',
        initial: _toItemDetails(existing),
      ),
    ),
  );
  if (result == null) return null;

  return _toTask(result, base: existing);
}

// --- mapping ---------------------------------------------------------------

ItemDetails? _toItemDetails(Task? t) {
  if (t == null) return null;
  return ItemDetails(
    name: t.title,
    iconName: t.iconName,
    iconDomain: t.iconDomain,
    amount: t.amount,
    currency: t.currency,
    firstPaymentDate: t.dueAt,
    type: t.repeat == RepeatCadence.none
        ? BillingType.oneTime
        : BillingType.recurring,
    cycle: _cycleFrom(t.repeat),
  );
}

Task _toTask(ItemDetails d, {Task? base}) {
  final repeat = d.type == BillingType.oneTime
      ? RepeatCadence.none
      : _repeatFrom(d.cycle);
  if (base != null) {
    return base.copyWith(
      title: d.name.isNotEmpty ? d.name : null,
      dueAt: d.firstPaymentDate,
      repeat: repeat,
      iconName: d.iconName,
      iconDomain: d.iconDomain,
      amount: d.amount,
      clearAmount: d.amount == null,
      currency: d.currency,
    );
  }
  // New task — id is assigned by the store on save, so a placeholder here.
  return Task(
    id: 'new',
    title: d.name,
    dueAt: d.firstPaymentDate,
    repeat: repeat,
    iconName: d.iconName,
    iconDomain: d.iconDomain,
    amount: d.amount,
    currency: d.currency,
  );
}

BillingCycle _cycleFrom(RepeatCadence r) => switch (r) {
      RepeatCadence.weekly => BillingCycle.weekly,
      RepeatCadence.yearly => BillingCycle.yearly,
      _ => BillingCycle.monthly,
    };

RepeatCadence _repeatFrom(BillingCycle c) => switch (c) {
      BillingCycle.weekly => RepeatCadence.weekly,
      BillingCycle.yearly => RepeatCadence.yearly,
      // quarterly / half-yearly collapse to monthly for the task cadence.
      _ => RepeatCadence.monthly,
    };
