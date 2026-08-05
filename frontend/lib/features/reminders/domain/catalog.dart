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

/// All categories shown in the add drawer. Only Identity & Government is built
/// out for now; the rest arrive as we fill in each tab.
const List<ReminderCategory> kCategories = [
  identityGovernmentCategory,
];
