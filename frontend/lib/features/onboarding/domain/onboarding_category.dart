import 'package:flutter/material.dart';

import '../../tasks/domain/task.dart';

/// A category shown in the onboarding gallery. Tapping it stages a reminder
/// pre-filled with smart defaults — the user only tweaks what's wrong.
///
/// Everything a category needs to become a reminder is captured in the three
/// things that matter: [defaultName], [defaultDay] (day-of-month), and
/// [defaultFrequency]. The commonest bills are [preselected] so a new user's
/// list is mostly built the moment they arrive.
class OnboardingCategory {
  const OnboardingCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.defaultName,
    required this.defaultDay,
    required this.defaultFrequency,
    this.preselected = false,
  });

  final String key;
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

/// The onboarding gallery. Common, near-universal bills are preselected so most
/// of a user's list is built for them on arrival.
const List<OnboardingCategory> kOnboardingCategories = [
  OnboardingCategory(
    key: 'mobile',
    label: 'Mobile',
    icon: Icons.smartphone_rounded,
    color: Color(0xFF3B82F6),
    defaultName: 'Mobile recharge',
    defaultDay: 1,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'electricity',
    label: 'Electricity',
    icon: Icons.bolt_rounded,
    color: Color(0xFFF59E0B),
    defaultName: 'Electricity bill',
    defaultDay: 5,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'internet',
    label: 'Internet',
    icon: Icons.wifi_rounded,
    color: Color(0xFF06B6D4),
    defaultName: 'Internet / Wi-Fi',
    defaultDay: 3,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'credit_card',
    label: 'Credit Card',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF8B5CF6),
    defaultName: 'Credit card bill',
    defaultDay: 15,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  OnboardingCategory(
    key: 'ott',
    label: 'Netflix / OTT',
    icon: Icons.play_circle_rounded,
    color: Color(0xFFEF4444),
    defaultName: 'Netflix',
    defaultDay: 10,
    defaultFrequency: RepeatCadence.monthly,
    preselected: true,
  ),
  // --- not preselected, but common ---
  OnboardingCategory(
    key: 'gas',
    label: 'Gas',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF97316),
    defaultName: 'Gas bill',
    defaultDay: 8,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'dth',
    label: 'DTH / Cable',
    icon: Icons.tv_rounded,
    color: Color(0xFF6366F1),
    defaultName: 'DTH recharge',
    defaultDay: 12,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'rent',
    label: 'Rent',
    icon: Icons.home_rounded,
    color: Color(0xFF14B8A6),
    defaultName: 'House rent',
    defaultDay: 1,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'insurance',
    label: 'Insurance',
    icon: Icons.shield_rounded,
    color: Color(0xFF10B981),
    defaultName: 'Insurance premium',
    defaultDay: 20,
    defaultFrequency: RepeatCadence.yearly,
  ),
  OnboardingCategory(
    key: 'loan_emi',
    label: 'Loan EMI',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF2563EB),
    defaultName: 'Loan EMI',
    defaultDay: 5,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'sip',
    label: 'SIP',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF22C55E),
    defaultName: 'SIP investment',
    defaultDay: 1,
    defaultFrequency: RepeatCadence.monthly,
  ),
  OnboardingCategory(
    key: 'water',
    label: 'Water',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF0EA5E9),
    defaultName: 'Water bill',
    defaultDay: 7,
    defaultFrequency: RepeatCadence.monthly,
  ),
];
