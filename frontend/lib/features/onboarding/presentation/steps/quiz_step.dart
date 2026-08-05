import 'package:flutter/material.dart';

import '../../domain/quiz.dart';
import '../onboarding_controller.dart';

/// A single quiz card: a big emoji, a few-word question, two taps.
///
/// The user answers in a second and the flow advances automatically — no
/// "Continue", no step labels, no blurbs.
class QuizStep extends StatelessWidget {
  const QuizStep({
    super.key,
    required this.question,
    required this.controller,
    required this.onAnswered,
  });

  final QuizQuestion question;
  final OnboardingController controller;

  /// Called after an answer is recorded, to advance the flow.
  final VoidCallback onAnswered;

  void _answer(bool yes) {
    controller.answer(question, yes: yes);
    onAnswered();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = question.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(question.emoji, style: const TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 28),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  label: 'Not really',
                  filled: false,
                  color: c,
                  onTap: () => _answer(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceButton(
                  label: 'Yes',
                  filled: true,
                  color: c,
                  onTap: () => _answer(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(const Size.fromHeight(56)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );

    if (filled) {
      return FilledButton(
        onPressed: onTap,
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(color),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: style.copyWith(
        foregroundColor: WidgetStatePropertyAll(color),
        side: WidgetStatePropertyAll(BorderSide(color: color, width: 1.5)),
      ),
      child: Text(label),
    );
  }
}
