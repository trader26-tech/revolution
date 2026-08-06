import 'package:flutter/material.dart';

/// One row on the onboarding quiz ("What do you juggle?").
///
/// [label] is what the user sees; [benefit] is the short, pointed line shown on
/// the benefits screen — what they'd lose by forgetting this. That's what makes
/// the last screen say *why the app matters*, not just "you'll save money".
class QuizOption {
  const QuizOption({
    required this.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.benefit,
  });

  final String key;
  final IconData icon;
  final String label;

  /// A short example under the label (clarifies what it covers).
  final String sub;
  final Color color;

  /// The consequence-of-forgetting benefit line for screen 3.
  final String benefit;
}

/// The quiz options — a clean, ordered list of the areas the app tracks.
const List<QuizOption> kQuizOptions = [
  QuizOption(
    key: 'bills',
    icon: Icons.receipt_long_rounded,
    label: 'Bills',
    sub: 'Electricity, mobile, internet',
    color: Color(0xFFF59E0B),
    benefit: 'Your power, phone and wifi never get cut.',
  ),
  QuizOption(
    key: 'insurance',
    icon: Icons.shield_rounded,
    label: 'Insurance',
    sub: 'Life, health, vehicle',
    color: Color(0xFF10B981),
    benefit: 'You stay covered the moment life goes wrong.',
  ),
  QuizOption(
    key: 'loans',
    icon: Icons.account_balance_rounded,
    label: 'Loans & EMIs',
    sub: 'Home, car, credit card',
    color: Color(0xFF3B82F6),
    benefit: 'Your credit score stays spotless — zero penalties.',
  ),
  QuizOption(
    key: 'renewals',
    icon: Icons.badge_rounded,
    label: 'Renewals',
    sub: 'Licence, passport, RC',
    color: Color(0xFF6366F1),
    benefit: 'Never stopped, fined, or stuck without valid ID.',
  ),
  QuizOption(
    key: 'taxes',
    icon: Icons.request_quote_rounded,
    label: 'Taxes & Filing',
    sub: 'ITR, GST, advance tax',
    color: Color(0xFF0EA5E9),
    benefit: 'File on time — no notices, no last-minute panic.',
  ),
  QuizOption(
    key: 'investments',
    icon: Icons.trending_up_rounded,
    label: 'Investments',
    sub: 'SIPs, FDs, maturities',
    color: Color(0xFF14B8A6),
    benefit: 'Your money keeps growing — nothing sits idle.',
  ),
  QuizOption(
    key: 'health',
    icon: Icons.favorite_rounded,
    label: 'Health & Meds',
    sub: 'Refills, check-ups, vaccines',
    color: Color(0xFFEF4444),
    benefit: 'Never skip a dose, refill, or check-up again.',
  ),
  QuizOption(
    key: 'vehicle',
    icon: Icons.directions_car_rounded,
    label: 'Vehicle',
    sub: 'PUC, service, insurance',
    color: Color(0xFF0891B2),
    benefit: 'Always road-legal and serviced on time.',
  ),
  QuizOption(
    key: 'home',
    icon: Icons.home_rounded,
    label: 'Home',
    sub: 'Rent, maintenance, bills',
    color: Color(0xFF9333EA),
    benefit: 'Your home runs smooth — nothing overdue.',
  ),
  QuizOption(
    key: 'warranties',
    icon: Icons.verified_rounded,
    label: 'Warranties',
    sub: 'Appliances, gadgets, AMC',
    color: Color(0xFFF97316),
    benefit: 'Claim free repairs before the cover runs out.',
  ),
  QuizOption(
    key: 'documents',
    icon: Icons.folder_shared_rounded,
    label: 'Documents',
    sub: 'Aadhaar, PAN, KYC',
    color: Color(0xFF64748B),
    benefit: 'Every important paper, updated and ready.',
  ),
  QuizOption(
    key: 'work',
    icon: Icons.work_rounded,
    label: 'Work & Deadlines',
    sub: 'Projects, invoices, renewals',
    color: Color(0xFF475569),
    benefit: 'Deliverables and payments never slip.',
  ),
  QuizOption(
    key: 'subscriptions',
    icon: Icons.play_circle_rounded,
    label: 'Subscriptions',
    sub: 'Netflix, Spotify, Prime',
    color: Color(0xFF8B5CF6),
    benefit: 'You stop paying for things you forgot you had.',
  ),
  QuizOption(
    key: 'birthdays',
    icon: Icons.cake_rounded,
    label: 'Birthdays',
    sub: 'Family & friends',
    color: Color(0xFFEC4899),
    benefit: 'You’re the one who always remembers.',
  ),
];
