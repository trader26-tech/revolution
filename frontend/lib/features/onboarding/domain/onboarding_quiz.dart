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
