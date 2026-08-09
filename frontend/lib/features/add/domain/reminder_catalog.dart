import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/domain/task.dart';

/// The Add screen's catalog: a small set of life-event CATEGORIES, each holding
/// the reminders people actually track. This is the single registry the picker
/// renders from — one entry here adds a row to the sheet, no UI change needed.
///
/// It's deliberately about WHAT to remember (a birthday, a car-insurance
/// renewal, a mobile recharge), not about brands. Every item seeds a sensible
/// default repeat cadence so the form arrives pre-filled; the user only tweaks.
class ReminderCategory {
  const ReminderCategory({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  /// Stable id, e.g. 'important_dates'.
  final String key;

  /// Section title shown in the picker, e.g. 'Important dates'.
  final String title;

  /// A Material icon (renders reliably — no emoji tofu).
  final IconData icon;

  /// The category accent, carried into its form so the path feels cohesive.
  final Color color;

  final List<ReminderItem> items;
}

/// One tappable reminder inside a category. [defaultRepeat] pre-fills the form's
/// cadence; [isOther] marks the "add your own" row that opens a blank form.
class ReminderItem {
  const ReminderItem(
    this.label,
    this.icon, {
    this.defaultRepeat = RepeatCadence.yearly,
    this.isOther = false,
  });

  /// The "add a custom one" row for a category.
  const ReminderItem.other()
      : label = 'Something else',
        icon = Icons.add_rounded,
        defaultRepeat = RepeatCadence.none,
        isOther = true;

  final String label;
  final IconData icon;
  final RepeatCadence defaultRepeat;
  final bool isOther;
}

/// The whole catalog, in display order. Ordered by how often people reach for
/// each: dates and subscriptions first, the heavier admin lower down.
const List<ReminderCategory> kReminderCatalog = [
  ReminderCategory(
    key: 'important_dates',
    title: 'Occasions',
    icon: Icons.event_rounded,
    color: Color(0xFFFF6FB5), // warm pink — people & moments
    items: [
      ReminderItem('Birthday', Icons.cake_rounded),
      ReminderItem('Wedding anniversary', Icons.favorite_rounded),
      ReminderItem('School fee', Icons.school_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Festival preparation', Icons.celebration_rounded),
      ReminderItem('Parent–teacher meeting', Icons.groups_rounded, defaultRepeat: RepeatCadence.none),
      ReminderItem.other(),
    ],
  ),
  ReminderCategory(
    key: 'subscriptions',
    title: 'Subscriptions',
    icon: Icons.play_circle_fill_rounded,
    color: AppColors.accent,
    items: [
      ReminderItem('Netflix', Icons.movie_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Prime Video', Icons.slideshow_rounded, defaultRepeat: RepeatCadence.yearly),
      ReminderItem('Spotify', Icons.music_note_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('YouTube Premium', Icons.smart_display_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('OTT / streaming', Icons.live_tv_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Software / app', Icons.apps_rounded, defaultRepeat: RepeatCadence.yearly),
      ReminderItem.other(),
    ],
  ),
  ReminderCategory(
    key: 'insurance',
    title: 'Insurance & renewals',
    icon: Icons.shield_rounded,
    color: Color(0xFF34D399), // trustworthy green
    items: [
      ReminderItem('Life insurance', Icons.volunteer_activism_rounded),
      ReminderItem('Health insurance', Icons.health_and_safety_rounded),
      ReminderItem('Car insurance', Icons.directions_car_rounded),
      ReminderItem('Bike insurance', Icons.two_wheeler_rounded),
      ReminderItem('Home insurance', Icons.home_rounded),
      ReminderItem('Travel insurance', Icons.flight_takeoff_rounded),
      ReminderItem.other(),
    ],
  ),
  ReminderCategory(
    key: 'bills',
    title: 'Bills & payments',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFFFB020), // amber — money going out
    items: [
      ReminderItem('Credit card bill', Icons.credit_card_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Loan / EMI', Icons.account_balance_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Electricity bill', Icons.bolt_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Water bill', Icons.water_drop_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Gas bill', Icons.local_fire_department_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Internet / broadband', Icons.wifi_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Mobile recharge', Icons.smartphone_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('DTH / cable', Icons.tv_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Property / income tax', Icons.description_rounded),
      ReminderItem.other(),
    ],
  ),
  ReminderCategory(
    key: 'investments',
    title: 'Money & investments',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF4ADE80), // fresh green — money growing
    items: [
      ReminderItem('SIP investment', Icons.savings_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Mutual fund review', Icons.pie_chart_rounded),
      ReminderItem('Stock portfolio review', Icons.show_chart_rounded),
      ReminderItem('FD maturity', Icons.lock_clock_rounded),
      ReminderItem('RD maturity', Icons.event_repeat_rounded),
      ReminderItem.other(),
    ],
  ),
  ReminderCategory(
    key: 'documents',
    title: 'Documents & ID',
    icon: Icons.badge_rounded,
    color: Color(0xFF60A5FA), // official blue
    items: [
      ReminderItem('Driving license', Icons.card_membership_rounded),
      ReminderItem('Passport', Icons.book_rounded),
      ReminderItem('National ID / Aadhaar', Icons.fingerprint_rounded),
      ReminderItem('Voter ID', Icons.how_to_vote_rounded),
      ReminderItem('Vehicle registration', Icons.directions_car_filled_rounded),
      ReminderItem('Visa', Icons.public_rounded),
      ReminderItem('Pollution certificate', Icons.eco_rounded),
      ReminderItem.other(),
    ],
  ),
  ReminderCategory(
    key: 'health_home',
    title: 'Health & home',
    icon: Icons.medical_services_rounded,
    color: Color(0xFF22D3EE), // clean cyan — care
    items: [
      ReminderItem('Medicine refill', Icons.medication_rounded, defaultRepeat: RepeatCadence.monthly),
      ReminderItem('Health check-up', Icons.monitor_heart_rounded),
      ReminderItem('Dental check-up', Icons.sentiment_satisfied_rounded),
      ReminderItem('Eye check-up', Icons.visibility_rounded),
      ReminderItem('Vaccination', Icons.vaccines_rounded),
      ReminderItem('AC service', Icons.ac_unit_rounded),
      ReminderItem('Pest control', Icons.pest_control_rounded),
      ReminderItem('Water purifier filter', Icons.opacity_rounded),
      ReminderItem.other(),
    ],
  ),
];
