import 'package:flutter/material.dart';

/// The 2-tap engine.
///
/// The whole onboarding rests on a single idea: one tap should stand in for a
/// dozen decisions. A [Persona] is a life-role the user recognises instantly
/// ("I drive", "I run a home"), and selecting it unlocks a curated bundle of
/// catalog item keys — the things people in that role almost always need to
/// stay on top of. The user taps one primary persona (required) and, if they
/// like, one add-on (optional). That's the maximum of two taps.
///
/// Item keys here MUST match keys in the reminders catalog (`catalog.dart`).
class Persona {
  const Persona({
    required this.key,
    required this.emoji,
    required this.label,
    required this.blurb,
    required this.color,
    required this.itemKeys,
  });

  final String key;
  final String emoji;

  /// Short, first-person so it reads as an identity, not a category.
  final String label;

  /// One line under the label explaining what it covers.
  final String blurb;

  final Color color;

  /// Catalog item keys this persona brings in.
  final List<String> itemKeys;
}

/// Primary personas — the user picks exactly one. Each is deliberately broad so
/// a single tap covers the essentials most people in that role forget.
const List<Persona> kPrimaryPersonas = [
  Persona(
    key: 'driver',
    emoji: '🚗',
    label: 'I drive',
    blurb: 'Insurance, PUC, service, licence — the stuff that gets you fined.',
    color: Color(0xFF0EA5E9),
    itemKeys: [
      'car_insurance',
      'pollution_certificate',
      'vehicle_service',
      'driving_license',
      'vehicle_registration',
    ],
  ),
  Persona(
    key: 'homemaker',
    emoji: '🏠',
    label: 'I run a home',
    blurb: 'Bills, gas, AC service, pest control — a household never stops.',
    color: Color(0xFF8B5CF6),
    itemKeys: [
      'electricity_bill',
      'gas_bill',
      'internet_bill',
      'ac_service',
      'pest_control',
      'water_purifier_filter',
    ],
  ),
  Persona(
    key: 'family',
    emoji: '👨‍👩‍👧',
    label: 'I have a family',
    blurb: 'Birthdays, anniversaries, school fees, health cover.',
    color: Color(0xFFEC4899),
    itemKeys: [
      'birthday',
      'wedding_anniversary',
      'school_fee',
      'health_insurance',
      'annual_health_checkup',
    ],
  ),
  Persona(
    key: 'investor',
    emoji: '📈',
    label: 'I manage money',
    blurb: 'SIPs, EMIs, credit-card bills, FDs, tax filing.',
    color: Color(0xFFF59E0B),
    itemKeys: [
      'sip_investment',
      'credit_card_bill',
      'loan_emi',
      'fixed_deposit_maturity',
      'income_tax_filing',
      'life_insurance',
    ],
  ),
  Persona(
    key: 'traveller',
    emoji: '🌍',
    label: 'I travel',
    blurb: 'Passport, visa, travel insurance — validity you can’t miss.',
    color: Color(0xFF4F46E5),
    itemKeys: [
      'passport',
      'visa',
      'travel_insurance',
    ],
  ),
  Persona(
    key: 'digital',
    emoji: '💻',
    label: 'I live online',
    blurb: 'Subscriptions, backups, passwords — quiet auto-renewals.',
    color: Color(0xFF06B6D4),
    itemKeys: [
      'ott_subscription',
      'software_subscription',
      'cloud_backup',
      'change_passwords',
    ],
  ),
];

/// Optional add-ons — the user may pick one to broaden the set, or skip.
const List<Persona> kAddonPersonas = [
  Persona(
    key: 'add_health',
    emoji: '🩺',
    label: 'Health matters',
    blurb: 'Check-ups, dental, eyes, medicine refills.',
    color: Color(0xFFEF4444),
    itemKeys: [
      'annual_health_checkup',
      'dental_checkup',
      'eye_checkup',
      'medicine_refill',
    ],
  ),
  Persona(
    key: 'add_bike',
    emoji: '🏍️',
    label: 'I ride a bike',
    blurb: 'Bike insurance, service, PUC.',
    color: Color(0xFF0EA5E9),
    itemKeys: [
      'bike_insurance',
      'pollution_certificate',
      'vehicle_service',
    ],
  ),
  Persona(
    key: 'add_property',
    emoji: '🏢',
    label: 'I own property',
    blurb: 'Home loan EMI, property tax, home insurance.',
    color: Color(0xFF10B981),
    itemKeys: [
      'home_loan_emi',
      'property_tax',
      'home_insurance',
    ],
  ),
  Persona(
    key: 'add_id',
    emoji: '🪪',
    label: 'Keep my IDs current',
    blurb: 'Aadhaar, voter ID, driving licence.',
    color: Color(0xFF6366F1),
    itemKeys: [
      'national_id',
      'voter_id',
      'driving_license',
    ],
  ),
];

/// Merge the selected personas into a de-duplicated, order-preserving list of
/// catalog item keys. Primary first, then the add-on's extras.
List<String> resolveItemKeys({
  required Persona primary,
  Persona? addon,
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final key in [...primary.itemKeys, ...?addon?.itemKeys]) {
    if (seen.add(key)) out.add(key);
  }
  return out;
}
