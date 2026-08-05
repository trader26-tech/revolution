import 'package:flutter/material.dart';

/// How an item's reminder date is anchored — this decides which ONE date we ask
/// the user for, keeping input minimal.
enum AnchorType {
  /// The user enters the printed EXPIRY / valid-till date directly. Used when
  /// the document prints one (Passport, DL, RC, Visa, PUC, Insurance). We remind
  /// [leadDays] before it.
  expiry,

  /// The user enters the ISSUE date; we compute expiry as issue + [validityDays]
  /// (PCC 6 months, Aadhaar-update 10 years). Reminder is [leadDays] before that.
  issuePlusValidity,

  /// The user enters the NEXT due date, and it repeats every [repeatDays]
  /// (bills, EMIs, services, birthdays…). We remind [leadDays] before each
  /// occurrence and roll forward automatically.
  recurring,

  /// A single upcoming date with no repeat (Vaccination, Parent-Teacher
  /// Meeting…). We remind [leadDays] before it and that's it.
  oneOff,

  /// No expiry — a store-only record (PAN, Voter ID). We keep the number for
  /// reference and set no reminder.
  none,
}

/// A concrete thing a user can track inside a category — with the predefined
/// rules that make input minimal and the reminder correct.
class Item {
  const Item({
    required this.key,
    required this.name,
    required this.emoji,
    required this.color,
    required this.anchor,
    this.validityDays,
    this.repeatDays,
    this.leadDays = 30,
    this.askDocNumber = false,
    this.docNumberLabel,
    this.askAmount = false,
    this.note,
    this.keywords = const [],
  });

  /// Stable id (also used as the reminder's item_key).
  final String key;
  final String name;

  /// Emoji shown on the stylized card thumbnail.
  final String emoji;

  /// The card's theme colour (a stylized nod to the real document, not its logo).
  final Color color;

  final AnchorType anchor;

  /// For [AnchorType.issuePlusValidity] — days from issue to expiry.
  final int? validityDays;

  /// For [AnchorType.recurring] — days between occurrences (30 monthly,
  /// 365 yearly, 182 half-yearly…).
  final int? repeatDays;

  /// How many days before the due date to remind.
  final int leadDays;

  /// Whether to offer an optional document-number field.
  final bool askDocNumber;
  final String? docNumberLabel;

  /// Whether to offer an optional amount field (SIP, FD, school fee…).
  final bool askAmount;

  /// A short reassuring line shown on the entry screen (why these defaults).
  final String? note;

  /// Extra search terms so users find items by synonym (e.g. "DL" → Licence).
  final List<String> keywords;

  bool get hasReminder => anchor != AnchorType.none;

  /// A short, human phrase for the cadence, shown as the row subtitle.
  String get cadenceLabel {
    switch (anchor) {
      case AnchorType.none:
        return 'No expiry · stored for reference';
      case AnchorType.oneOff:
        return 'One-time · remind $leadDays days before';
      case AnchorType.expiry:
        return 'Remind $leadDays days before it expires';
      case AnchorType.issuePlusValidity:
        final yrs = (validityDays ?? 365) ~/ 365;
        return yrs >= 1
            ? 'Review every $yrs ${yrs == 1 ? "year" : "years"}'
            : 'Valid a few months · we\'ll nudge you';
      case AnchorType.recurring:
        return _repeatPhrase(repeatDays ?? 30);
    }
  }

  static String _repeatPhrase(int days) {
    if (days <= 2) return 'Repeats daily';
    if (days <= 8) return 'Repeats weekly';
    if (days <= 31) return 'Repeats monthly';
    if (days <= 95) return 'Repeats quarterly';
    if (days <= 190) return 'Repeats every 6 months';
    if (days <= 400) return 'Repeats yearly';
    final yrs = (days / 365).round();
    return 'Repeats every $yrs years';
  }

  /// Case-insensitive match against name + keywords, for the search box.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (name.toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }
}

const _y = 365; // days in a year, for readable validity below

/// The Identity & Government items — the pattern category, built from verified
/// Indian document rules. Ordered by how commonly they're held.
const List<Item> kIdentityItems = [
  Item(
    key: 'aadhaar',
    name: 'Aadhaar',
    emoji: '🆔',
    color: Color(0xFFE4572E), // saffron-red
    anchor: AnchorType.issuePlusValidity,
    validityDays: 10 * _y, // UIDAI recommends updating docs every 10 years
    leadDays: 30,
    askDocNumber: true,
    docNumberLabel: 'Aadhaar number',
    note: "Aadhaar doesn't expire — UIDAI suggests refreshing your documents "
        'every 10 years. We\'ll give you a gentle nudge then.',
    keywords: ['uidai', 'uid', 'aadhar'],
  ),
  Item(
    key: 'pan',
    name: 'PAN Card',
    emoji: '💳',
    color: Color(0xFF2563EB), // income-tax blue
    anchor: AnchorType.none,
    askDocNumber: true,
    docNumberLabel: 'PAN',
    note: 'PAN has lifetime validity — no renewal needed. We\'ll just keep it '
        'handy for you.',
    keywords: ['permanent account number', 'income tax', 'tax'],
  ),
  Item(
    key: 'passport',
    name: 'Passport',
    emoji: '🛂',
    color: Color(0xFF1E3A5F), // navy
    anchor: AnchorType.expiry,
    leadDays: 180, // visas often need 6 months' validity
    askDocNumber: true,
    docNumberLabel: 'Passport number',
    note: 'Enter the expiry printed on your passport. We remind you 6 months '
        'ahead — most countries need that much validity for a visa.',
    keywords: ['travel', 'immigration', 'visa book'],
  ),
  Item(
    key: 'driving_licence',
    name: 'Driving Licence',
    emoji: '🪪',
    color: Color(0xFF0E7C86), // teal card
    anchor: AnchorType.expiry,
    leadDays: 60,
    askDocNumber: true,
    docNumberLabel: 'Licence number',
    note: 'Enter the valid-till date on your licence. We remind you 2 months '
        'ahead so you can renew before it lapses.',
    keywords: ['dl', 'rto', 'driver', 'license'],
  ),
  Item(
    key: 'voter_id',
    name: 'Voter ID',
    emoji: '🗳️',
    color: Color(0xFF6B7280), // neutral grey
    anchor: AnchorType.none,
    askDocNumber: true,
    docNumberLabel: 'EPIC number',
    note: "Voter ID doesn't expire. We'll keep your EPIC number for reference.",
    keywords: ['epic', 'election', 'eci'],
  ),
  Item(
    key: 'vehicle_rc',
    name: 'Vehicle RC',
    emoji: '🚗',
    color: Color(0xFF334155), // slate
    anchor: AnchorType.expiry,
    leadDays: 90,
    askDocNumber: true,
    docNumberLabel: 'Registration number',
    note: 'Enter the valid-till date on your RC. Private vehicles renew after '
        '15 years, then every 5 — we remind you 3 months ahead.',
    keywords: ['registration', 'rc', 'vahan', 'number plate'],
  ),
  Item(
    key: 'visa',
    name: 'Visa',
    emoji: '🛃',
    color: Color(0xFF7C3AED), // violet
    anchor: AnchorType.expiry,
    leadDays: 90,
    askDocNumber: false,
    note: 'Enter the expiry printed on your visa. We remind you 3 months ahead '
        'so you can renew without overstaying.',
    keywords: ['permit', 'residence', 'work permit', 'travel'],
  ),
  Item(
    key: 'puc',
    name: 'PUC Certificate',
    emoji: '🌱',
    color: Color(0xFF16A34A), // green / eco
    anchor: AnchorType.expiry,
    leadDays: 15,
    askDocNumber: false,
    note: 'A valid PUC is mandatory to drive. They\'re short (often 6 months) — '
        'we remind you 2 weeks before it expires.',
    keywords: ['pollution', 'emission', 'pollution under control'],
  ),
  Item(
    key: 'vehicle_insurance',
    name: 'Vehicle Insurance',
    emoji: '🛡️',
    color: Color(0xFF0891B2), // cyan
    anchor: AnchorType.expiry,
    leadDays: 30,
    askDocNumber: true,
    docNumberLabel: 'Policy number',
    note: 'Enter your policy renewal date. We remind you a month ahead so cover '
        'never lapses and you keep your No-Claim Bonus.',
    keywords: ['motor', 'car insurance', 'bike insurance', 'policy'],
  ),
  Item(
    key: 'police_clearance',
    name: 'Police Clearance (PCC)',
    emoji: '🧾',
    color: Color(0xFF3F3F46), // dark neutral
    anchor: AnchorType.issuePlusValidity,
    validityDays: 182, // ~6 months
    leadDays: 30,
    askDocNumber: false,
    note: 'A PCC is usually accepted for about 6 months. Enter the issue date '
        'and we\'ll flag when it\'s getting stale.',
    keywords: ['pcc', 'police', 'clearance', 'background'],
  ),
];

/// Detailed items by category name. Only Identity & Government is built out as
/// the pattern; other categories fall back to a simple flow until filled in.
const Map<String, List<Item>> kItemsByCategory = {
  'Identity & Government': kIdentityItems,
};
