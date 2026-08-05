import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';
import '../../domain/quiz.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// The one-screen checklist — "Which of these are you?". The user ticks any
/// number of rows, sees a live count, and continues. No per-question tabs.
class ChecklistStep extends StatelessWidget {
  const ChecklistStep({
    super.key,
    required this.controller,
    required this.onContinue,
  });

  final OnboardingController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final n = controller.count;
        return OnboardingScaffold(
          centerContent: false,
          cta: 'Continue',
          onCta: controller.hasAny ? onContinue : null,
          footnote: controller.hasAny
              ? 'Bobo will look after $n ${n == 1 ? "thing" : "things"} for you'
              : 'Tick everything that sounds like you',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Which of these\nare you?',
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: Bamboo.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick as many as fit. You can change these later.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: Bamboo.inkSoft),
              ),
              const SizedBox(height: 24),
              for (final q in kQuiz) ...[
                _ChecklistRow(
                  question: q,
                  selected: controller.isSelected(q),
                  onTap: () => controller.toggle(q),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.question,
    required this.selected,
    required this.onTap,
  });

  final QuizQuestion question;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? Bamboo.green.withValues(alpha: 0.12)
                : Bamboo.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Bamboo.green : Bamboo.cardBorder,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(question.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  question.prompt,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Bamboo.ink,
                  ),
                ),
              ),
              _Check(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Bamboo.green : Colors.transparent,
        border: Border.all(
          color: selected ? Bamboo.green : Bamboo.cardBorder,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
