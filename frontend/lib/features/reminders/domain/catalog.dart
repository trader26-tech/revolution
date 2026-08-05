import 'package:flutter/material.dart';

/// The catalog of things a user can set a renewal reminder for.
///
/// This is the source of the "prefilled to the max" experience: every item
/// ships with a sensible India-context validity, a default reminder lead time,
/// and a small set of fields that are themselves prefilled with the most common
/// choice. The user only tweaks what's different for them.

/// A top-level category shown first in the add drawer.
class ReminderCategory {
  const ReminderCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final List<CatalogItem> items;
}

/// How an item's expiry is determined.
enum ValidityKind {
  /// Expires after a fixed number of years from the issue date (e.g. passport).
  fixedYears,

  /// Never legally expires — we nudge the user to review/update it instead
  /// (e.g. Aadhaar, Voter ID). Uses a review interval instead of an expiry.
  evergreen,

  /// The user knows the expiry date directly (e.g. a visa). No issue-date math.
  expiryOnly,
}

/// A single field that appears, prefilled, in the item's form.
class CatalogField {
  const CatalogField({
    required this.key,
    required this.label,
    this.hint,
    this.defaultValue = '',
    this.options = const [],
    this.keyboardType = TextInputType.text,
  });

  final String key;
  final String label;
  final String? hint;
  final String defaultValue;

  /// If non-empty, the field renders as selectable chips instead of a text box.
  final List<String> options;
  final TextInputType keyboardType;
}

class CatalogItem {
  const CatalogItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.validityKind,
    this.defaultValidityYears,
    this.reviewIntervalMonths,
    required this.defaultRemindDaysBefore,
    this.documentNumberLabel,
    this.documentNumberHint,
    this.fields = const [],
    this.tip,
  });

  final String key;

  /// The default reminder title — editable, but rarely needs changing.
  final String title;
  final IconData icon;

  final ValidityKind validityKind;

  /// Used when [validityKind] is [ValidityKind.fixedYears].
  final int? defaultValidityYears;

  /// Used when [validityKind] is [ValidityKind.evergreen].
  final int? reviewIntervalMonths;

  final int defaultRemindDaysBefore;

  final String? documentNumberLabel;
  final String? documentNumberHint;

  final List<CatalogField> fields;

  /// A short reassuring line shown in the form to justify the defaults.
  final String? tip;
}

/// Reminder lead-time presets offered as chips (days before expiry).
const List<int> kRemindPresets = [30, 60, 90, 120, 180];

// ---------------------------------------------------------------------------
// Identity & Government (India defaults)
// ---------------------------------------------------------------------------

const _indianStates = <String>[
  'Andhra Pradesh',
  'Delhi',
  'Gujarat',
  'Karnataka',
  'Kerala',
  'Maharashtra',
  'Tamil Nadu',
  'Telangana',
  'Uttar Pradesh',
  'West Bengal',
  'Other',
];

const ReminderCategory identityGovernmentCategory = ReminderCategory(
  key: 'identity_government',
  label: 'Identity & Government',
  icon: Icons.badge_outlined,
  color: Color(0xFF4F46E5),
  items: [
    CatalogItem(
      key: 'driving_license',
      title: 'Driving Licence Renewal',
      icon: Icons.directions_car_outlined,
      validityKind: ValidityKind.fixedYears,
      defaultValidityYears: 20, // private LMV, valid till age 50 / 20 yrs
      defaultRemindDaysBefore: 60,
      documentNumberLabel: 'Licence number',
      documentNumberHint: 'DL-0420110149646',
      tip: 'Private licences are valid 20 years (or till age 50). '
          'We remind you 2 months ahead so you can book a slot.',
      fields: [
        CatalogField(
          key: 'license_type',
          label: 'Type',
          options: ['Private (LMV)', 'Commercial', 'Two-wheeler'],
          defaultValue: 'Private (LMV)',
        ),
        CatalogField(
          key: 'rto_state',
          label: 'Issuing state',
          options: _indianStates,
          defaultValue: 'Maharashtra',
        ),
      ],
    ),
    CatalogItem(
      key: 'passport',
      title: 'Passport Renewal',
      icon: Icons.menu_book_outlined,
      validityKind: ValidityKind.fixedYears,
      defaultValidityYears: 10, // adult passport
      defaultRemindDaysBefore: 180,
      documentNumberLabel: 'Passport number',
      documentNumberHint: 'K1234567',
      tip: 'Many countries need 6 months validity to grant a visa, so we '
          'remind you 6 months before expiry.',
      fields: [
        CatalogField(
          key: 'holder_type',
          label: 'Holder',
          options: ['Adult', 'Minor'],
          defaultValue: 'Adult',
        ),
      ],
    ),
    CatalogItem(
      key: 'national_id',
      title: 'Aadhaar Update',
      icon: Icons.fingerprint,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 120, // UIDAI recommends updating docs every 10 yrs
      defaultRemindDaysBefore: 30,
      documentNumberLabel: 'Aadhaar number',
      documentNumberHint: 'XXXX XXXX XXXX',
      tip: 'Aadhaar never expires. UIDAI recommends refreshing your address '
          'and documents every 10 years — we\'ll nudge you then.',
    ),
    CatalogItem(
      key: 'voter_id',
      title: 'Voter ID Verification',
      icon: Icons.how_to_vote_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 60,
      defaultRemindDaysBefore: 30,
      documentNumberLabel: 'EPIC number',
      documentNumberHint: 'ABC1234567',
      tip: 'Voter IDs don\'t expire. We\'ll remind you every 5 years to verify '
          'your address and details before elections.',
    ),
    CatalogItem(
      key: 'vehicle_registration',
      title: 'Vehicle RC Renewal',
      icon: Icons.confirmation_number_outlined,
      validityKind: ValidityKind.fixedYears,
      defaultValidityYears: 15, // private vehicle RC
      defaultRemindDaysBefore: 60,
      documentNumberLabel: 'Registration number',
      documentNumberHint: 'MH12AB1234',
      tip: 'Private vehicle registration is valid 15 years, then renewed every '
          '5 years. We remind you 2 months ahead.',
      fields: [
        CatalogField(
          key: 'vehicle_type',
          label: 'Vehicle',
          options: ['Car', 'Bike', 'Scooter', 'Commercial'],
          defaultValue: 'Car',
        ),
      ],
    ),
    CatalogItem(
      key: 'visa',
      title: 'Visa Renewal',
      icon: Icons.flight_takeoff_outlined,
      validityKind: ValidityKind.expiryOnly,
      defaultRemindDaysBefore: 90,
      documentNumberLabel: 'Visa number',
      documentNumberHint: 'Optional',
      tip: 'Enter the expiry printed on your visa. We remind you 3 months '
          'ahead so you can renew without overstaying.',
      fields: [
        CatalogField(
          key: 'country',
          label: 'Country',
          hint: 'e.g. UAE, USA, Schengen',
        ),
        CatalogField(
          key: 'visa_type',
          label: 'Type',
          options: ['Work', 'Residence', 'Student', 'Tourist', 'Business'],
          defaultValue: 'Work',
        ),
      ],
    ),
    CatalogItem(
      key: 'police_clearance',
      title: 'Police Clearance Renewal',
      icon: Icons.local_police_outlined,
      validityKind: ValidityKind.fixedYears,
      defaultValidityYears: 1, // PCC typically 6 months–1 year
      defaultRemindDaysBefore: 30,
      documentNumberLabel: 'PCC reference',
      documentNumberHint: 'Optional',
      tip: 'A Police Clearance Certificate is usually accepted for 6–12 months. '
          'We remind you 1 month before it lapses.',
    ),
  ],
);

// ---------------------------------------------------------------------------
// Remaining categories.
//
// These carry the essentials the onboarding + reveal need — key, title, icon,
// a sensible cadence and lead time — using the same CatalogItem shape as the
// fully-built Identity group above. Rich per-item fields get filled in over
// time; nothing here needs typing from the user during onboarding.
// ---------------------------------------------------------------------------

const ReminderCategory vehicleCategory = ReminderCategory(
  key: 'vehicle',
  label: 'Vehicle',
  icon: Icons.directions_car_filled_outlined,
  color: Color(0xFF0EA5E9),
  items: [
    CatalogItem(
      key: 'car_insurance',
      title: 'Car Insurance Renewal',
      icon: Icons.directions_car_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
      tip: 'Motor insurance lapses on the day it expires — we nudge you a month '
          'ahead so there is no break in cover.',
    ),
    CatalogItem(
      key: 'bike_insurance',
      title: 'Bike Insurance Renewal',
      icon: Icons.two_wheeler_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
    ),
    CatalogItem(
      key: 'vehicle_service',
      title: 'Vehicle Service Due',
      icon: Icons.build_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'tire_replacement',
      title: 'Tyre Replacement',
      icon: Icons.tire_repair_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 36,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'engine_oil',
      title: 'Engine Oil Change',
      icon: Icons.oil_barrel_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 7,
    ),
    CatalogItem(
      key: 'battery_replacement',
      title: 'Battery Replacement',
      icon: Icons.battery_charging_full_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 36,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'pollution_certificate',
      title: 'Pollution Certificate (PUC)',
      icon: Icons.eco_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 14,
      tip: 'A valid PUC is mandatory to drive. Petrol/diesel PUCs are usually '
          'valid 6 months — we remind you 2 weeks ahead.',
    ),
  ],
);

const ReminderCategory insuranceCategory = ReminderCategory(
  key: 'insurance',
  label: 'Insurance',
  icon: Icons.shield_outlined,
  color: Color(0xFF10B981),
  items: [
    CatalogItem(
      key: 'life_insurance',
      title: 'Life Insurance Premium',
      icon: Icons.favorite_outline,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 15,
      tip: 'Miss an LIC premium and the policy can lapse. We remind you early '
          'so cover — and tax benefit — stays intact.',
    ),
    CatalogItem(
      key: 'health_insurance',
      title: 'Health Insurance Premium',
      icon: Icons.local_hospital_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
    ),
    CatalogItem(
      key: 'home_insurance',
      title: 'Home Insurance Renewal',
      icon: Icons.house_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
    ),
    CatalogItem(
      key: 'travel_insurance',
      title: 'Travel Insurance Renewal',
      icon: Icons.luggage_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'personal_accident_insurance',
      title: 'Personal Accident Insurance',
      icon: Icons.personal_injury_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
    ),
  ],
);

const ReminderCategory bankingFinanceCategory = ReminderCategory(
  key: 'banking_finance',
  label: 'Banking & Finance',
  icon: Icons.account_balance_outlined,
  color: Color(0xFFF59E0B),
  items: [
    CatalogItem(
      key: 'credit_card_bill',
      title: 'Credit Card Bill Due',
      icon: Icons.credit_card_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 5,
      tip: 'Pay in full before the due date to dodge interest and late fees. '
          'We nudge you 5 days ahead, every month.',
    ),
    CatalogItem(
      key: 'loan_emi',
      title: 'Loan EMI Due',
      icon: Icons.payments_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'home_loan_emi',
      title: 'Home Loan EMI',
      icon: Icons.home_work_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'car_loan_emi',
      title: 'Car Loan EMI',
      icon: Icons.directions_car_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'sip_investment',
      title: 'SIP Investment Date',
      icon: Icons.trending_up_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 2,
    ),
    CatalogItem(
      key: 'mutual_fund_review',
      title: 'Mutual Fund Review',
      icon: Icons.pie_chart_outline,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 7,
    ),
    CatalogItem(
      key: 'stock_portfolio_review',
      title: 'Stock Portfolio Review',
      icon: Icons.show_chart_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 7,
    ),
    CatalogItem(
      key: 'fixed_deposit_maturity',
      title: 'Fixed Deposit Maturity',
      icon: Icons.savings_outlined,
      validityKind: ValidityKind.expiryOnly,
      defaultRemindDaysBefore: 15,
      tip: 'Enter the maturity date on your FD receipt. We remind you before '
          'it auto-renews so you can reinvest at the best rate.',
    ),
    CatalogItem(
      key: 'recurring_deposit_maturity',
      title: 'Recurring Deposit Maturity',
      icon: Icons.account_balance_wallet_outlined,
      validityKind: ValidityKind.expiryOnly,
      defaultRemindDaysBefore: 15,
    ),
    CatalogItem(
      key: 'income_tax_filing',
      title: 'Income Tax Filing',
      icon: Icons.receipt_long_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
      tip: 'The ITR deadline is usually 31 July. We remind you a month ahead so '
          'you gather documents without the last-minute rush.',
    ),
    CatalogItem(
      key: 'property_tax',
      title: 'Property Tax Due',
      icon: Icons.apartment_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
    ),
  ],
);

const ReminderCategory utilitiesCategory = ReminderCategory(
  key: 'utilities',
  label: 'Utilities',
  icon: Icons.bolt_outlined,
  color: Color(0xFFEAB308),
  items: [
    CatalogItem(
      key: 'electricity_bill',
      title: 'Electricity Bill',
      icon: Icons.lightbulb_outline,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'water_bill',
      title: 'Water Bill',
      icon: Icons.water_drop_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'gas_bill',
      title: 'Gas Bill',
      icon: Icons.local_fire_department_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'internet_bill',
      title: 'Internet Bill',
      icon: Icons.wifi_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'mobile_recharge',
      title: 'Mobile Recharge',
      icon: Icons.smartphone_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 2,
      tip: 'Prepaid packs lapse silently. We nudge you before your validity '
          'ends so calls and data keep working.',
    ),
    CatalogItem(
      key: 'dth_cable',
      title: 'DTH / Cable Renewal',
      icon: Icons.tv_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
    ),
  ],
);

const ReminderCategory healthCategory = ReminderCategory(
  key: 'health',
  label: 'Health',
  icon: Icons.health_and_safety_outlined,
  color: Color(0xFFEF4444),
  items: [
    CatalogItem(
      key: 'medicine_refill',
      title: 'Medicine Refill',
      icon: Icons.medication_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 5,
    ),
    CatalogItem(
      key: 'annual_health_checkup',
      title: 'Annual Health Check-up',
      icon: Icons.monitor_heart_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'dental_checkup',
      title: 'Dental Check-up',
      icon: Icons.medical_services_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'eye_checkup',
      title: 'Eye Check-up',
      icon: Icons.remove_red_eye_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'vaccination',
      title: 'Vaccination Due',
      icon: Icons.vaccines_outlined,
      validityKind: ValidityKind.expiryOnly,
      defaultRemindDaysBefore: 14,
    ),
  ],
);

const ReminderCategory homeCategory = ReminderCategory(
  key: 'home',
  label: 'Home',
  icon: Icons.home_outlined,
  color: Color(0xFF8B5CF6),
  items: [
    CatalogItem(
      key: 'deep_cleaning',
      title: 'Deep House Cleaning',
      icon: Icons.cleaning_services_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 3,
      defaultRemindDaysBefore: 7,
    ),
    CatalogItem(
      key: 'ac_service',
      title: 'AC Service',
      icon: Icons.ac_unit_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 14,
      tip: 'Servicing before summer keeps the AC efficient. We remind you twice '
          'a year, ahead of peak season.',
    ),
    CatalogItem(
      key: 'water_purifier_filter',
      title: 'Water Purifier Filter Change',
      icon: Icons.water_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 14,
    ),
    CatalogItem(
      key: 'fire_extinguisher_service',
      title: 'Fire Extinguisher Service',
      icon: Icons.fire_extinguisher,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 30,
    ),
    CatalogItem(
      key: 'pest_control',
      title: 'Pest Control',
      icon: Icons.pest_control_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 14,
    ),
  ],
);

const ReminderCategory familyPersonalCategory = ReminderCategory(
  key: 'family_personal',
  label: 'Family & Personal',
  icon: Icons.family_restroom_outlined,
  color: Color(0xFFEC4899),
  items: [
    CatalogItem(
      key: 'birthday',
      title: 'Birthday',
      icon: Icons.cake_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 7,
      tip: 'We remind you a week ahead so there is time to plan a gift or a '
          'call — never an awkward "happy belated".',
    ),
    CatalogItem(
      key: 'wedding_anniversary',
      title: 'Wedding Anniversary',
      icon: Icons.favorite_border,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 7,
    ),
    CatalogItem(
      key: 'school_fee',
      title: 'School Fee Payment',
      icon: Icons.school_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 3,
      defaultRemindDaysBefore: 10,
    ),
    CatalogItem(
      key: 'parent_teacher_meeting',
      title: 'Parent-Teacher Meeting',
      icon: Icons.groups_outlined,
      validityKind: ValidityKind.expiryOnly,
      defaultRemindDaysBefore: 3,
    ),
    CatalogItem(
      key: 'festival_preparation',
      title: 'Festival Preparation',
      icon: Icons.celebration_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 14,
    ),
  ],
);

const ReminderCategory digitalCategory = ReminderCategory(
  key: 'digital',
  label: 'Digital',
  icon: Icons.devices_outlined,
  color: Color(0xFF06B6D4),
  items: [
    CatalogItem(
      key: 'change_passwords',
      title: 'Change Passwords',
      icon: Icons.password_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 6,
      defaultRemindDaysBefore: 3,
      tip: 'A twice-yearly password refresh on key accounts keeps you ahead of '
          'breaches. We remind you so it actually happens.',
    ),
    CatalogItem(
      key: 'cloud_backup',
      title: 'Cloud Backup',
      icon: Icons.cloud_upload_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 2,
    ),
    CatalogItem(
      key: 'laptop_backup',
      title: 'Laptop Backup',
      icon: Icons.laptop_mac_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 2,
    ),
    CatalogItem(
      key: 'software_subscription',
      title: 'Software Subscription Renewal',
      icon: Icons.apps_outlined,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 12,
      defaultRemindDaysBefore: 7,
    ),
    CatalogItem(
      key: 'ott_subscription',
      title: 'OTT Subscription Renewal',
      icon: Icons.play_circle_outline,
      validityKind: ValidityKind.evergreen,
      reviewIntervalMonths: 1,
      defaultRemindDaysBefore: 3,
      tip: 'Streaming plans auto-renew quietly. We remind you so you can cancel '
          'or switch before the card is charged.',
    ),
  ],
);

/// Every category, in display order.
const List<ReminderCategory> kCategories = [
  identityGovernmentCategory,
  vehicleCategory,
  insuranceCategory,
  bankingFinanceCategory,
  utilitiesCategory,
  healthCategory,
  homeCategory,
  familyPersonalCategory,
  digitalCategory,
];

/// Flat lookup of every catalog item by its key, across all categories.
final Map<String, CatalogItem> kCatalogByKey = {
  for (final c in kCategories)
    for (final item in c.items) item.key: item,
};

/// The category each item key belongs to (for colour/icon in the reveal).
final Map<String, ReminderCategory> kCategoryByItemKey = {
  for (final c in kCategories)
    for (final item in c.items) item.key: c,
};
