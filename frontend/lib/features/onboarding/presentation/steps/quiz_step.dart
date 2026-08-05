import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';
import '../../domain/quiz.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// One quiz card — a big emoji, a few-word question, two clean rows. The user
/// answers in a tap and the flow advances; no step labels, no blurbs.
class QuizStep extends StatelessWidget {
  const QuizStep({
    super.key,
    required this.question,
    required this.controller,
    required this.onAnswered,
  });

  final QuizQuestion question;
  final OnboardingController controller;
  final VoidCallback onAnswered;

  void _answer(bool yes) {
    controller.answer(question, yes: yes);
    onAnswered();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return OnboardingScaffold(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 116,
            height: 116,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Bamboo.mist,
              shape: BoxShape.circle,
              border: Border.all(color: Bamboo.sprout.withValues(alpha: 0.5)),
            ),
            child: Text(question.emoji, style: const TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 28),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Bamboo.ink,
            ),
          ),
          const SizedBox(height: 28),
          _AnswerRow(
            label: 'Yes, that’s me',
            primary: true,
            onTap: () => _answer(true),
          ),
          const SizedBox(height: 12),
          _AnswerRow(
            label: 'Not really',
            primary: false,
            onTap: () => _answer(false),
          ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Bamboo.green : Bamboo.card,
      borderRadius: BorderRadius.circular(18),
      elevation: primary ? 0 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: primary
                ? null
                : Border.all(color: Bamboo.cardBorder, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: primary ? Colors.white : Bamboo.ink,
            ),
          ),
        ),
      ),
    );
  }
}
