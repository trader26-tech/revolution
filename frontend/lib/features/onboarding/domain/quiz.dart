import 'package:flutter/material.dart';

/// One quiz question. Deliberately tiny: a few words, an emoji, and the set of
/// catalog item keys a "yes" pulls in. No paragraphs, no sub-labels.
///
/// Item keys must match keys in the reminders catalog (`catalog.dart`).
class QuizQuestion {
  const QuizQuestion({
    required this.emoji,
    required this.prompt,
    required this.color,
    required this.itemKeys,
  });

  /// The big glyph Pip "holds up".
  final String emoji;

  /// The question — 2 to 4 words, phrased so a tap answers it.
  final String prompt;

  final Color color;

  /// What a "Yes" adds to the plan.
  final List<String> itemKeys;
}

/// The whole quiz — a handful of instant taps. Each is a yes/no the user
/// answers in under a second.
const List<QuizQuestion> kQuiz = [
  QuizQuestion(
    emoji: '🚗',
    prompt: 'You drive?',
    color: Color(0xFF0EA5E9),
    itemKeys: [
      'car_insurance',
      'pollution_certificate',
      'driving_license',
    ],
  ),
  QuizQuestion(
    emoji: '👨‍👩‍👧',
    prompt: 'Got a family?',
    color: Color(0xFFEC4899),
    itemKeys: [
      'birthday',
      'wedding_anniversary',
      'health_insurance',
    ],
  ),
  QuizQuestion(
    emoji: '💸',
    prompt: 'Pay bills?',
    color: Color(0xFFF59E0B),
    itemKeys: [
      'credit_card_bill',
      'electricity_bill',
      'mobile_recharge',
    ],
  ),
  QuizQuestion(
    emoji: '✈️',
    prompt: 'You travel?',
    color: Color(0xFF4F46E5),
    itemKeys: [
      'passport',
      'visa',
    ],
  ),
];
