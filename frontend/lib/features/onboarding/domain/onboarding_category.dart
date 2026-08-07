import 'package:flutter/material.dart';

import '../../tasks/domain/task.dart';

/// A category shown in the onboarding gallery. Tapping it stages a reminder
/// pre-filled with smart defaults — the user only tweaks what's wrong.
///
/// Everything a category needs to become a reminder is captured in the three
/// things that matter: [defaultName], [defaultDay] (day-of-month), and
/// [defaultFrequency]. The commonest bills are [preselected] so a new user's
/// list is mostly built the moment they arrive. Each belongs to a [group] so
/// the picker can walk the user through one bite-sized section at a time.
class OnboardingCategory {
  const OnboardingCategory({
    required this.key,
    required this.group,
    required this.label,
    required this.icon,
    required this.color,
    required this.defaultName,
    required this.defaultDay,
    required this.defaultFrequency,
    this.preselected = false,
  });

  final String key;

  /// Which [OnboardingGroup] this belongs to.
  final String group;

  final String label;
  final IconData icon;
  final Color color;

  /// The reminder name we pre-fill (editable).
  final String defaultName;

  /// Default day-of-month (1–31) the knob picker starts on.
  final int defaultDay;

  final RepeatCadence defaultFrequency;

  /// Whether it's ticked by default (near-universal bills).
  final bool preselected;
}

/// A section of the onboarding picker — a themed group of related categories
/// the user reviews together on one step (with the progress bar advancing per
/// group).
class OnboardingGroup {
  const OnboardingGroup({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// The categories belonging to this group, in display order.
  List<OnboardingCategory> get categories =>
      kOnboardingCategories.where((c) => c.group == key).toList();
}

/// Ordered onboarding groups — the wizard walks these top to bottom, one step
/// (and one progress segment) each.
const List<OnboardingGroup> kOnboardingGroups = [
  OnboardingGroup(
    key: 'subscriptions',
    title: 'Subscriptions',
    subtitle: 'The apps and services that auto-renew.',
    icon: Icons.play_circle_rounded,
    color: Color(0xFFEF4444),
  ),
  OnboardingGroup(
    key: 'connectivity',
    title: 'Phone & Internet',
    subtitle: 'Recharges and the Wi-Fi at home.',
    icon: Icons.wifi_rounded,
    color: Color(0xFF06B6D4),
  ),
  OnboardingGroup(
    key: 'utilities',
    title: 'Bills & Utilities',
    subtitle: 'The monthly must-pays for your home.',
    icon: Icons.bolt_rounded,
    color: Color(0xFFF59E0B),
  ),
  OnboardingGroup(
    key: 'finance',
    title: 'Money & EMIs',
    subtitle: 'Cards, loans, rent and investments.',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF2563EB),
  ),
];

/// The onboarding gallery. Common, near-universal bills are preselected so most
/// of a user's list is built for them on arrival.
const List<OnboardingCategory> kOnboardingCategories = [
  // ── Subscriptions ──────────────────────────────────────────────
  OnboardingCategory(
    key: 'ott',
    group: 'subscriptions',
    label: 'Netflix / OTT',
    icon: Icons.play_circle_rounded,
    color: Color(0xFFEF4444),
    defaultName: 'Netflix',
    defaultDay: 10,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'music',
    group: 'subscriptions',
    label: 'Music',
    icon: Icons.music_note_rounded,
    color: Color(0xFF1DB954),
    defaultName: 'Spotify',
    defaultDay: 10,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'dth',
    group: 'subscriptions',
    label: 'DTH / Cable',
    icon: Icons.tv_rounded,
    color: Color(0xFF6366F1),
    defaultName: 'DTH recharge',
    defaultDay: 12,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'cloud',
    group: 'subscriptions',
    label: 'Cloud / iCloud',
    icon: Icons.cloud_rounded,
    color: Color(0xFF0EA5E9),
    defaultName: 'Cloud storage',
    defaultDay: 10,
    defaultFrequency: RepeatCadence.monthly,
  ),

  // ── Phone & Internet ───────────────────────────────────────────
  OnboardingCategory(
    key: 'mobile',
    group: 'connectivity',
    label: 'Mobile',
    icon: Icons.smartphone_rounded,
    color: Color(0xFF3B82F6),
    defaultName: 'Mobile recharge',
    defaultDay: 1,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'internet',
    group: 'connectivity',
    label: 'Internet',
    icon: Icons.wifi_rounded,
    color: Color(0xFF06B6D4),
    defaultName: 'Internet / Wi-Fi',
    defaultDay: 3,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),

  // ── Bills & Utilities ──────────────────────────────────────────
  OnboardingCategory(
    key: 'electricity',
    group: 'utilities',
    label: 'Electricity',
    icon: Icons.bolt_rounded,
    color: Color(0xFFF59E0B),
    defaultName: 'Electricity bill',
    defaultDay: 5,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'gas',
    group: 'utilities',
    label: 'Gas',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF97316),
    defaultName: 'Gas bill',
    defaultDay: 8,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'water',
    group: 'utilities',
    label: 'Water',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF0EA5E9),
    defaultName: 'Water bill',
    defaultDay: 7,
    defaultFrequency: RepeatCadence.monthly,
  ),

  // ── Money & EMIs ───────────────────────────────────────────────
  OnboardingCategory(
    key: 'credit_card',
    group: 'finance',
    label: 'Credit Card',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF8B5CF6),
    defaultName: 'Credit card bill',
    defaultDay: 15,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'rent',
    group: 'finance',
    label: 'Rent',
    icon: Icons.home_rounded,
    color: Color(0xFF14B8A6),
    defaultName: 'House rent',
    defaultDay: 1,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'loan_emi',
    group: 'finance',
    label: 'Loan EMI',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF2563EB),
    defaultName: 'Loan EMI',
    defaultDay: 5,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'insurance',
    group: 'finance',
    label: 'Insurance',
    icon: Icons.shield_rounded,
    color: Color(0xFF10B981),
    defaultName: 'Insurance premium',
    defaultDay: 20,
    defaultFrequency: RepeatCadence.yearly,
  ),
  OnboardingCategory(
    key: 'sip',
    group: 'finance',
    label: 'SIP',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF22C55E),
    defaultName: 'SIP investment',
    defaultDay: 1,
    defaultFrequency: RepeatCadence.monthly,
  ),
];
