import 'package:flutter/material.dart';

/// One tappable option on the onboarding quiz ("What do you juggle?").
///
/// Each option carries a realistic **annual ₹ figure** for what people in that
/// area typically lose to forgetting — late fees, lapses, silent renewals. The
/// benefits screen sums the picked options into a personalised "you could save"
/// number, so the payoff is tailored to what the user actually cares about.
class QuizOption {
  const QuizOption({
    required this.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.annualSaving,
    required this.blurb,
  });

  final String key;
  final String emoji;
  final String label;
  final Color color;

  /// Typical yearly ₹ lost to forgetting in this area (illustrative).
  final int annualSaving;

  /// One short line shown on the benefits screen.
  final String blurb;
}

/// The quiz options. Deliberately few and instantly recognisable.
const List<QuizOption> kQuizOptions = [
  QuizOption(
    key: 'bills',
    emoji: '💡',
    label: 'Bills',
    color: Color(0xFFF59E0B),
    annualSaving: 4800,
    blurb: 'late-fee-free',
  ),
  QuizOption(
    key: 'subscriptions',
    emoji: '📺',
    label: 'Subscriptions',
    color: Color(0xFF8B5CF6),
    annualSaving: 6400,
    blurb: 'no silent renewals',
  ),
  QuizOption(
    key: 'insurance',
    emoji: '🛡️',
    label: 'Insurance',
    color: Color(0xFF10B981),
    annualSaving: 9000,
    blurb: 'never lapses',
  ),
  QuizOption(
    key: 'loans',
    emoji: '🏦',
    label: 'Loans & EMIs',
    color: Color(0xFF3B82F6),
    annualSaving: 5200,
    blurb: 'no penalty interest',
  ),
  QuizOption(
    key: 'renewals',
    emoji: '🪪',
    label: 'Renewals',
    color: Color(0xFF6366F1),
    annualSaving: 3000,
    blurb: 'licence, passport, RC',
  ),
  QuizOption(
    key: 'birthdays',
    emoji: '🎂',
    label: 'Birthdays',
    color: Color(0xFFEC4899),
    annualSaving: 0,
    blurb: 'never awkward again',
  ),
];
