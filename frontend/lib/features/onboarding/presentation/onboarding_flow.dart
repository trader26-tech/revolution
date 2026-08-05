import 'package:flutter/material.dart';

import '../../reminders/data/reminders_repository.dart';
import '../../reminders/domain/scheduling.dart';
import '../domain/quiz.dart';
import 'onboarding_controller.dart';
import 'steps/quiz_step.dart';
import 'steps/reveal_step.dart';
import 'steps/welcome_step.dart';

/// Orchestrates onboarding: Welcome → a few quiz taps → Reveal.
///
/// On finish it writes the resolved reminders through the repository, then
/// calls [onDone] so the caller can mark onboarding complete.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onDone,
    this.repository,
  });

  final Future<void> Function() onDone;
  final RemindersRepository? repository;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _controller = OnboardingController();
  late final RemindersRepository _repo =
      widget.repository ?? RemindersRepository();

  int _page = 0;
  bool _busy = false;

  // Welcome + one page per quiz question + reveal.
  int get _pageCount => kQuiz.length + 2;

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _next() => _goTo(_page + 1);

  Future<void> _finish() async {
    setState(() => _busy = true);
    final now = DateTime.now();
    final drafts = _controller.resolvedItems
        .map((item) => Scheduling.draftFor(item, from: now))
        .toList();

    // Best-effort — never trap the user in onboarding if the network is down.
    for (final draft in drafts) {
      try {
        await _repo.create(draft);
      } catch (_) {}
    }
    await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(page: _page, pageCount: _pageCount),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  WelcomeStep(onStart: _next),
                  for (final q in kQuiz)
                    QuizStep(
                      question: q,
                      controller: _controller,
                      onAnswered: _next,
                    ),
                  RevealStep(
                    controller: _controller,
                    busy: _busy,
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin top progress bar that fills as the user advances.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.page, required this.pageCount});

  final int page;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (page + 1) / pageCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}
