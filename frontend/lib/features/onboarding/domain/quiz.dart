import 'package:flutter/material.dart';

/// One line in the "Which of these are you?" checklist. Deliberately tiny: an
/// emoji, a few-word label, and the catalog item keys selecting it pulls in.
///
/// Item keys must match keys in the reminders catalog (`catalog.dart`).
class QuizQuestion {
  const QuizQuestion({
    required this.key,
    required this.emoji,
    required this.prompt,
    required this.color,
    required this.itemKeys,
  });

  /// Stable id for selection tracking.
  final String key;

  /// The emoji shown at the start of the row.
  final String emoji;

  /// The label — first-person, a few words ("I drive").
  final String prompt;

  final Color color;

  /// What selecting this row adds to the plan.
  final List<String> itemKeys;
}

/// The checklist — one screen, multi-select. Each row is an identity the user
/// recognises instantly and can tick on or off.
const List<QuizQuestion> kQuiz = [
  QuizQuestion(
    key: 'drive',
    emoji: '🚗',
    prompt: 'I drive',
    color: Color(0xFF0EA5E9),
    itemKeys: [
      'car_insurance',
      'pollution_certificate',
      'driving_license',
    ],
  ),
  QuizQuestion(
    key: 'family',
    emoji: '👨‍👩‍👧',
    prompt: 'I have a family',
    color: Color(0xFFEC4899),
    itemKeys: [
      'birthday',
      'wedding_anniversary',
      'health_insurance',
    ],
  ),
  QuizQuestion(
    key: 'bills',
    emoji: '💸',
    prompt: 'I pay bills',
    color: Color(0xFFF59E0B),
    itemKeys: [
      'credit_card_bill',
      'electricity_bill',
      'mobile_recharge',
    ],
  ),
  QuizQuestion(
    key: 'travel',
    emoji: '✈️',
    prompt: 'I travel',
    color: Color(0xFF4F46E5),
    itemKeys: [
      'passport',
      'visa',
    ],
  ),
  QuizQuestion(
    key: 'home',
    emoji: '🏠',
    prompt: 'I run a home',
    color: Color(0xFF8B5CF6),
    itemKeys: [
      'gas_bill',
      'internet_bill',
      'ac_service',
      'pest_control',
    ],
  ),
  QuizQuestion(
    key: 'health',
    emoji: '🩺',
    prompt: 'I mind my health',
    color: Color(0xFFEF4444),
    itemKeys: [
      'annual_health_checkup',
      'dental_checkup',
      'medicine_refill',
    ],
  ),
  QuizQuestion(
    key: 'invest',
    emoji: '📈',
    prompt: 'I invest & save',
    color: Color(0xFF10B981),
    itemKeys: [
      'sip_investment',
      'fixed_deposit_maturity',
      'income_tax_filing',
    ],
  ),
  QuizQuestion(
    key: 'digital',
    emoji: '💻',
    prompt: 'I live online',
    color: Color(0xFF06B6D4),
    itemKeys: [
      'ott_subscription',
      'software_subscription',
      'change_passwords',
    ],
  ),
];
