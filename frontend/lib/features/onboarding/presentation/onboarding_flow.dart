import 'package:flutter/material.dart';

import '../../reminders/data/reminders_repository.dart';
import '../../reminders/domain/scheduling.dart';
import 'onboarding_controller.dart';
import 'steps/checklist_step.dart';
import 'steps/reveal_step.dart';
import 'steps/stat_step.dart';
import 'steps/welcome_step.dart';

/// Orchestrates onboarding: Welcome → Stat → Checklist → Reveal.
///
/// On finish it writes the resolved reminders through the repository, then
/// calls [onDone] so the caller can mark onboarding complete.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onDone,
    this.ownerId,
    this.repository,
  });

  final Future<void> Function() onDone;

  /// The signed-in user's id — reminders created during onboarding are scoped
  /// to this account.
  final String? ownerId;
  final RemindersRepository? repository;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _controller = OnboardingController();
  late final RemindersRepository _repo =
      widget.repository ?? RemindersRepository(ownerId: widget.ownerId);

  int _page = 0;
  bool _busy = false;

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
    // Each step owns its full screen (bamboo background + CTA) via
    // OnboardingScaffold, so the flow is just the PageView.
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          WelcomeStep(onStart: _next),
          StatStep(onNext: _next),
          ChecklistStep(
            controller: _controller,
            onContinue: _next,
          ),
          RevealStep(
            controller: _controller,
            busy: _busy,
            onFinish: _finish,
          ),
        ],
      ),
    );
  }
}
