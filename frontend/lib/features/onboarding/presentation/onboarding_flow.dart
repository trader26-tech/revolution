import 'package:flutter/material.dart';

import '../../reminders/data/reminders_repository.dart';
import '../../reminders/domain/scheduling.dart';
import 'onboarding_controller.dart';
import 'phone_entry_page.dart';
import 'steps/addon_pick_step.dart';
import 'steps/primary_pick_step.dart';
import 'steps/reveal_step.dart';
import 'steps/welcome_step.dart';

/// Orchestrates the four onboarding beats — Welcome → Pick → Add-on → Reveal —
/// and, on finish, writes the resolved reminders through the repository.
///
/// [onDone] is called once everything is created (or if creation fails softly);
/// the caller marks onboarding complete and shows the app.
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

  static const _pageCount = 4;

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
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<bool> _onBack() async {
    if (_page == 0) return true; // allow system pop from the welcome screen
    _goTo(_page - 1);
    return false;
  }

  Future<void> _finish() async {
    // Collect the user's phone number before we set anything up. For now this
    // is take-their-word-for-it (see PhoneEntryPage.bypassVerification); real
    // WhatsApp verification lands later. Backing out returns them to the reveal
    // and onboarding stays incomplete.
    final verifiedPhone = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (routeContext) => PhoneEntryPage(
          onVerified: (phone) => Navigator.of(routeContext).pop(phone),
        ),
      ),
    );
    if (verifiedPhone == null || !mounted) return;

    setState(() => _busy = true);
    final now = DateTime.now();
    final drafts = _controller.resolvedItems
        .map((item) => Scheduling.draftFor(item, from: now))
        .toList();

    // Best-effort create. Even if the network is down, we don't trap the user
    // in onboarding — the flag is set and they land in the app.
    for (final draft in drafts) {
      try {
        await _repo.create(draft);
      } catch (_) {
        // Swallow individual failures; a later sync/retry can reconcile.
      }
    }

    await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                page: _page,
                pageCount: _pageCount,
                onBack: _page == 0 ? null : () => _goTo(_page - 1),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    WelcomeStep(onStart: () => _goTo(1)),
                    PrimaryPickStep(
                      controller: _controller,
                      onNext: () => _goTo(2),
                    ),
                    AddonPickStep(
                      controller: _controller,
                      onReveal: () => _goTo(3),
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
      ),
    );
  }
}

/// A slim top bar: a back affordance and progress dots.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.pageCount,
    required this.onBack,
  });

  final int page;
  final int pageCount;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: onBack == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: onBack,
                  ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pageCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i <= page
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
