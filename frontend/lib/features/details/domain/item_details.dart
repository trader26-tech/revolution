/// The rich, optional details a tracked item can carry — modelled on a
/// subscription/renewal entry (amount, cycle, list, notification, etc.).
///
/// Kept separate from the minimal `Task` so the fast-capture flow stays simple:
/// a task is just a name + date until the user chooses to "Fill details", at
/// which point these fields come into play.
enum BillingType { recurring, oneTime }

extension BillingTypeLabel on BillingType {
  String get label => switch (this) {
        BillingType.recurring => 'Recurring',
        BillingType.oneTime => 'One-time',
      };
}

enum BillingCycle { weekly, monthly, quarterly, halfYearly, yearly }

extension BillingCycleLabel on BillingCycle {
  String get label => switch (this) {
        BillingCycle.weekly => 'Every week',
        BillingCycle.monthly => 'Every month',
        BillingCycle.quarterly => 'Every 3 months',
        BillingCycle.halfYearly => 'Every 6 months',
        BillingCycle.yearly => 'Every year',
      };
}

enum NotifyBefore { none, sameDay, oneDay, threeDays, oneWeek }

extension NotifyBeforeLabel on NotifyBefore {
  String get label => switch (this) {
        NotifyBefore.none => 'None',
        NotifyBefore.sameDay => 'On the day',
        NotifyBefore.oneDay => '1 day before',
        NotifyBefore.threeDays => '3 days before',
        NotifyBefore.oneWeek => '1 week before',
      };
}

/// The full details record. Every field is optional/defaulted so a partial fill
/// is always valid.
class ItemDetails {
  ItemDetails({
    this.name = '',
    this.amount,
    this.currency = 'INR',
    DateTime? firstPaymentDate,
    this.type = BillingType.recurring,
    this.cycle = BillingCycle.monthly,
    this.durationForever = true,
    this.freeTrial = false,
    this.list = 'Personal',
    this.category = 'Other',
    this.paymentMethod,
    this.notify = NotifyBefore.oneDay,
    this.url = '',
    this.notes = '',
  }) : firstPaymentDate = firstPaymentDate ?? DateTime.now();

  String name;
  double? amount;
  String currency;
  DateTime firstPaymentDate;
  BillingType type;
  BillingCycle cycle;
  bool durationForever;
  bool freeTrial;
  String list;
  String category;
  String? paymentMethod;
  NotifyBefore notify;
  String url;
  String notes;

  ItemDetails copy() => ItemDetails(
        name: name,
        amount: amount,
        currency: currency,
        firstPaymentDate: firstPaymentDate,
        type: type,
        cycle: cycle,
        durationForever: durationForever,
        freeTrial: freeTrial,
        list: list,
        category: category,
        paymentMethod: paymentMethod,
        notify: notify,
        url: url,
        notes: notes,
      );
}
