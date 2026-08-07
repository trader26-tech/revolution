import 'package:flutter/material.dart';

/// One row on the onboarding quiz ("What do you juggle?").
///
/// [label] is what the user sees; [perYear] is how many reminders this area
/// realistically generates in a year. Screen 3 multiplies picks × [perYear]
/// and counts the total up into one big number — that's the payoff.
class QuizOption {
  const QuizOption({
    required this.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.perYear,
  });

  final String key;
  final IconData icon;
  final String label;

  /// A short example under the label (clarifies what it covers).
  final String sub;
  final Color color;

  /// Reminders per year this area typically generates. Deliberately
  /// conservative — the total must feel honest, not inflated.
  final int perYear;
}

/// The quiz options — a clean, ordered list of the areas the app tracks.
const List<QuizOption> kQuizOptions = [
  QuizOption(
    key: 'bills',
    icon: Icons.receipt_long_rounded,
    label: 'Bills',
    sub: 'Electricity, mobile, internet',
    color: Color(0xFFF59E0B),
    perYear: 36, // electricity + mobile + internet, each monthly
  ),
  QuizOption(
    key: 'insurance',
    icon: Icons.shield_rounded,
    label: 'Insurance',
    sub: 'Life, health, vehicle',
    color: Color(0xFF10B981),
    perYear: 6, // life/health/vehicle premiums + renewal checks
  ),
  QuizOption(
    key: 'loans',
    icon: Icons.account_balance_rounded,
    label: 'Loans & EMIs',
    sub: 'Home, car, credit card',
    color: Color(0xFF3B82F6),
    perYear: 24, // an EMI + a credit-card bill, monthly each
  ),
  QuizOption(
    key: 'renewals',
    icon: Icons.badge_rounded,
    label: 'Renewals',
    sub: 'Licence, passport, RC',
    color: Color(0xFF6366F1),
    perYear: 4, // a handful of expiry dates spread over the year
  ),
  QuizOption(
    key: 'taxes',
    icon: Icons.request_quote_rounded,
    label: 'Taxes & Filing',
    sub: 'ITR, GST, advance tax',
    color: Color(0xFF0EA5E9),
    perYear: 9, // 4 advance-tax dates + ITR + GST-style filings
  ),
  QuizOption(
    key: 'investments',
    icon: Icons.trending_up_rounded,
    label: 'Investments',
    sub: 'SIPs, FDs, maturities',
    color: Color(0xFF14B8A6),
    perYear: 12, // the monthly SIP date
  ),
  QuizOption(
    key: 'health',
    icon: Icons.favorite_rounded,
    label: 'Health & Meds',
    sub: 'Refills, check-ups, vaccines',
    color: Color(0xFFEF4444),
    perYear: 15, // monthly refills + a few check-ups / vaccines
  ),
  QuizOption(
    key: 'vehicle',
    icon: Icons.directions_car_rounded,
    label: 'Vehicle',
    sub: 'PUC, service, insurance',
    color: Color(0xFF0891B2),
    perYear: 6, // 2 PUC + 2 services + insurance + road tax
  ),
  QuizOption(
    key: 'home',
    icon: Icons.home_rounded,
    label: 'Home',
    sub: 'Rent, maintenance, bills',
    color: Color(0xFF9333EA),
    perYear: 16, // rent monthly + quarterly society maintenance
  ),
  QuizOption(
    key: 'warranties',
    icon: Icons.verified_rounded,
    label: 'Warranties',
    sub: 'Appliances, gadgets, AMC',
    color: Color(0xFFF97316),
    perYear: 4, // covers and AMCs expiring through the year
  ),
  QuizOption(
    key: 'documents',
    icon: Icons.folder_shared_rounded,
    label: 'Documents',
    sub: 'Aadhaar, PAN, KYC',
    color: Color(0xFF64748B),
    perYear: 3, // occasional KYC / re-verification nudges
  ),
  QuizOption(
    key: 'work',
    icon: Icons.work_rounded,
    label: 'Work & Deadlines',
    sub: 'Projects, invoices, renewals',
    color: Color(0xFF475569),
    perYear: 24, // roughly two invoices / deadlines a month
  ),
  QuizOption(
    key: 'subscriptions',
    icon: Icons.play_circle_rounded,
    label: 'Subscriptions',
    sub: 'Netflix, Spotify, Prime',
    color: Color(0xFF8B5CF6),
    perYear: 36, // ~3 services, each renewing monthly
  ),
  QuizOption(
    key: 'birthdays',
    icon: Icons.cake_rounded,
    label: 'Birthdays',
    sub: 'Family & friends',
    color: Color(0xFFEC4899),
    perYear: 12, // the people you can't afford to forget
  ),
];
