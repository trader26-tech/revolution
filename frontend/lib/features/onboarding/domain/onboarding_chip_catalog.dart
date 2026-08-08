import 'package:flutter/material.dart';

import '../../tasks/domain/task.dart';

/// Page 2 of onboarding: the "what should we remember?" chip picker.
///
/// Six life categories, each a wrap of pill chips holding the most common
/// repeatable payments/renewals (India-first). The page arrives MOSTLY DONE:
/// every near-universal item ships [preselected] — subscriptions people
/// actually have, the bills everyone pays (electricity, water tax, land tax),
/// document renewals, parents' birthdays, core insurance — so the user mostly
/// just unticks what isn't theirs. That's the point of the page: show them
/// what the app remembers, pre-picked, instead of an empty quiz.
class OnboardingChipSection {
  const OnboardingChipSection({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String key;
  final String title;
  final IconData icon;
  final Color color;
  final List<OnboardingChipItem> items;
}

class OnboardingChipItem {
  const OnboardingChipItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.defaultName,
    required this.defaultDay,
    required this.defaultFrequency,
    this.preselected = false,
  });

  final String key;
  final String label;
  final IconData icon;

  /// Pre-filled reminder name (editable later).
  final String defaultName;

  /// Default day-of-month (1–31).
  final int defaultDay;

  final RepeatCadence defaultFrequency;

  /// Ticked on arrival (the near-universal picks).
  final bool preselected;
}

const List<OnboardingChipSection> kOnboardingChipSections = [
  OnboardingChipSection(
    key: 'subs',
    title: 'Subscriptions',
    icon: Icons.play_circle_rounded,
    color: Color(0xFFEF4444),
    items: [
      OnboardingChipItem(
        key: 'subs_netflix',
        label: 'Netflix',
        icon: Icons.play_circle_rounded,
        defaultName: 'Netflix',
        defaultDay: 10,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'subs_prime',
        label: 'Amazon Prime',
        icon: Icons.shopping_bag_rounded,
        defaultName: 'Amazon Prime',
        defaultDay: 15,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'subs_spotify',
        label: 'Spotify',
        icon: Icons.music_note_rounded,
        defaultName: 'Spotify',
        defaultDay: 10,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'subs_hotstar',
        label: 'Hotstar',
        icon: Icons.star_rounded,
        defaultName: 'Disney+ Hotstar',
        defaultDay: 12,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'subs_youtube',
        label: 'YouTube',
        icon: Icons.smart_display_rounded,
        defaultName: 'YouTube Premium',
        defaultDay: 8,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'subs_cloud',
        label: 'iCloud',
        icon: Icons.cloud_rounded,
        defaultName: 'Cloud storage',
        defaultDay: 5,
        defaultFrequency: RepeatCadence.monthly,
      ),
      OnboardingChipItem(
        key: 'subs_gym',
        label: 'Gym',
        icon: Icons.fitness_center_rounded,
        defaultName: 'Gym membership',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.monthly,
      ),
    ],
  ),
  // The bills EVERYONE pays monthly — the strongest "this app gets my life"
  // section, so it sits right after the familiar subscription logos.
  OnboardingChipSection(
    key: 'bills',
    title: 'Bills',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFF59E0B),
    items: [
      OnboardingChipItem(
        key: 'bills_electricity',
        label: 'Electricity bill',
        icon: Icons.bolt_rounded,
        defaultName: 'Electricity bill',
        defaultDay: 5,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'bills_wifi',
        label: 'WiFi',
        icon: Icons.wifi_rounded,
        defaultName: 'WiFi bill',
        defaultDay: 5,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'bills_mobile',
        label: 'Mobile recharge',
        icon: Icons.smartphone_rounded,
        defaultName: 'Mobile recharge',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'bills_gas',
        label: 'Gas cylinder',
        icon: Icons.local_fire_department_rounded,
        defaultName: 'Gas cylinder booking',
        defaultDay: 20,
        defaultFrequency: RepeatCadence.monthly,
      ),
      OnboardingChipItem(
        key: 'bills_rent',
        label: 'House rent',
        icon: Icons.home_rounded,
        defaultName: 'House rent',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.monthly,
      ),
    ],
  ),
  OnboardingChipSection(
    key: 'docs',
    title: 'Document renewals',
    icon: Icons.badge_rounded,
    color: Color(0xFF6366F1),
    items: [
      OnboardingChipItem(
        key: 'docs_passport',
        label: 'Passport',
        icon: Icons.flight_takeoff_rounded,
        defaultName: 'Passport renewal',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.none,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'docs_licence',
        label: 'Driving licence',
        icon: Icons.directions_car_filled_rounded,
        defaultName: 'Driving licence renewal',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.none,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'docs_pan',
        label: 'PAN',
        icon: Icons.credit_card_rounded,
        defaultName: 'PAN card',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.none,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'docs_voter',
        label: 'Voter ID',
        icon: Icons.how_to_vote_rounded,
        defaultName: 'Voter ID update',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.none,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'docs_aadhaar',
        label: 'Aadhaar',
        icon: Icons.fingerprint_rounded,
        defaultName: 'Aadhaar update',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.none,
      ),
      OnboardingChipItem(
        key: 'docs_visa',
        label: 'Visa',
        icon: Icons.public_rounded,
        defaultName: 'Visa renewal',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.none,
      ),
      OnboardingChipItem(
        key: 'docs_rc',
        label: 'Vehicle RC',
        icon: Icons.article_rounded,
        defaultName: 'Vehicle RC renewal',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.none,
      ),
    ],
  ),
  OnboardingChipSection(
    key: 'family',
    title: 'Birthdays & family',
    icon: Icons.cake_rounded,
    color: Color(0xFFEC4899),
    items: [
      OnboardingChipItem(
        key: 'family_mom',
        label: 'Mom',
        icon: Icons.cake_rounded,
        defaultName: "Mom's birthday",
        defaultDay: 1,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'family_dad',
        label: 'Dad',
        icon: Icons.cake_rounded,
        defaultName: "Dad's birthday",
        defaultDay: 1,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'family_sibling',
        label: 'Sibling',
        icon: Icons.cake_rounded,
        defaultName: "Sibling's birthday",
        defaultDay: 1,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'family_partner',
        label: 'Partner',
        icon: Icons.favorite_rounded,
        defaultName: "Partner's birthday",
        defaultDay: 1,
        defaultFrequency: RepeatCadence.yearly,
      ),
      OnboardingChipItem(
        key: 'family_anniv',
        label: 'Anniversary',
        icon: Icons.favorite_border_rounded,
        defaultName: 'Wedding anniversary',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.yearly,
      ),
    ],
  ),
  OnboardingChipSection(
    key: 'insure',
    title: 'Insurance & vehicle',
    icon: Icons.shield_rounded,
    color: Color(0xFF10B981),
    items: [
      OnboardingChipItem(
        key: 'insure_health',
        label: 'Health',
        icon: Icons.favorite_rounded,
        defaultName: 'Health insurance premium',
        defaultDay: 20,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'insure_life',
        label: 'Life / LIC',
        icon: Icons.shield_rounded,
        defaultName: 'Life insurance premium',
        defaultDay: 20,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'insure_bike',
        label: 'Bike',
        icon: Icons.two_wheeler_rounded,
        defaultName: 'Bike insurance renewal',
        defaultDay: 10,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'insure_car',
        label: 'Car',
        icon: Icons.directions_car_rounded,
        defaultName: 'Car insurance renewal',
        defaultDay: 10,
        defaultFrequency: RepeatCadence.yearly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'insure_service',
        label: 'Car service',
        icon: Icons.build_rounded,
        defaultName: 'Car service',
        defaultDay: 15,
        defaultFrequency: RepeatCadence.yearly,
      ),
      OnboardingChipItem(
        key: 'insure_puc',
        label: 'PUC',
        icon: Icons.eco_rounded,
        defaultName: 'PUC certificate renewal',
        defaultDay: 15,
        defaultFrequency: RepeatCadence.yearly,
      ),
    ],
  ),
  OnboardingChipSection(
    key: 'invest',
    title: 'SIPs & investments',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF22C55E),
    items: [
      OnboardingChipItem(
        key: 'invest_sip',
        label: 'SIP',
        icon: Icons.trending_up_rounded,
        defaultName: 'SIP investment',
        defaultDay: 5,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'invest_mf',
        label: 'Mutual funds',
        icon: Icons.pie_chart_rounded,
        defaultName: 'Mutual fund review',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.monthly,
        preselected: true,
      ),
      OnboardingChipItem(
        key: 'invest_stocks',
        label: 'Stocks',
        icon: Icons.show_chart_rounded,
        defaultName: 'Stocks review',
        defaultDay: 1,
        defaultFrequency: RepeatCadence.monthly,
      ),
    ],
  ),
];
