import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/starfield.dart';
import '../../auth/data/auth_store.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../tasks/data/task_store.dart';
import '../data/onboarding_commit.dart';
import '../data/onboarding_store.dart';
import 'screens/chip_select_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/onboarding_finish_screen.dart';
import 'screens/payoff_screen.dart';
import 'screens/schedule_screen.dart';
import 'widgets/reminder_confirm_sheet.dart';

/// The onboarding flow: what it does → the chip picker ("what should we
/// remember?") → the big-number payoff → the schedule step (day + how often for
/// each pick) → the app. Minimal, stylised, visual. Call [showOnboarding] to
/// present it; pass [onFinish] to turn the collected drafts into real tasks.
Future<void> showOnboarding(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const OnboardingFlow(),
    ),
  );
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.onDone, this.onFinish});

  /// Called when the user finishes (or skips). Defaults to popping the route.
  final VoidCallback? onDone;

  /// Called on the final "Finish" with a ready-to-save draft per picked item —
  /// the host turns these into real tasks. Fired before [onDone]/pop. Null in
  /// previews (nothing is created).
  final ValueChanged<Map<String, ReminderDraft>>? onFinish;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();

  /// Picked chip keys — the commonest ones arrive already selected.
  final Set<String> _picked = preselectedChipKeys();

  /// The per-item schedule drafts (day/frequency/every), keyed by chip key.
  /// Seeded by the wizard's onComplete, then edited on the schedule screen.
  final Map<String, ReminderDraft> _drafts = {};

  int _page = 0;

  /// True only while a PROGRAMMATIC page transition is in flight. The wizard
  /// page normally blocks user swipes with NeverScrollableScrollPhysics — but
  /// that physics also blocks [PageController.animateToPage], so finishing the
  /// wizard (page 1 → payoff page 2) would silently fail and snap back to the
  /// intro. Flipping this true for the duration of a driven transition lets the
  /// controller move the viewport, then it flips back so the wizard is locked
  /// to the user again.
  bool _animating = false;

  // Five progress dots — the five stages of onboarding: intro, chips, payoff,
  // schedule, then the app itself. The PageView holds the first FOUR (indices
  // 0..3); the fifth dot lights the instant the user finishes, as the app
  // takes over.
  static const _dotCount = 5;

  /// The number of swipeable pages in the PageView (the app "stage" isn't one).
  static const _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // The last page (schedule) drives its own "Finish"; this branch is a
      // safety net only.
      _skip();
    }
  }

  /// Leave onboarding WITHOUT saving anything (the Skip affordance). Used by the
  /// top-right "Skip" on the pre-schedule pages.
  ///
  /// Skip goes straight to the "What's your number?" phone login page. We push
  /// [AuthGate] (which shows PhoneLoginPage while logged OUT, with its OTP
  /// verification wired up) and REPLACE the onboarding route so Back can't return
  /// to it. Onboarding is also marked complete so it won't reappear next launch.
  ///
  /// [AuthGate] only shows the phone login page when logged out — if a session
  /// is already saved it jumps to the app. So when onboarding was opened WITHOUT
  /// an [onDone] handler (the dev "spark" replay button on Home), we sign out
  /// first, guaranteeing the phone login page every single time — the whole
  /// point of that dev shortcut is to test login again and again.
  Future<void> _skip() async {
    await _leaveToAuth();
  }

  /// Mark onboarding done and replace this route with the auth gate. [child] is
  /// the logged-out screen: null → the plain phone login (Skip path); the
  /// onboarding finish screen on the real Finish path. Signing out first when
  /// there's no [onDone] keeps the dev replay button landing on login every time.
  Future<void> _leaveToAuth({Widget? child}) async {
    OnboardingStore.instance.markComplete();
    if (widget.onDone == null) {
      await AuthStore.instance.logout();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AuthGate(child: child)),
    );
  }

  /// The real finish — fired from the schedule step's "Finish". We navigate to
  /// the finish screen IMMEDIATELY (no waiting on the network), then create the
  /// tasks in the BACKGROUND. The finish screen's Home preview is driven by the
  /// [TaskStore] (a ChangeNotifier), so reminders pop in the instant each commit
  /// lands — the user never stares at a spinner after tapping Finish.
  Future<void> _complete(Map<String, ReminderDraft> drafts) async {
    widget.onFinish?.call(drafts);
    // Light the fifth dot — "arriving at the app" — before we go.
    if (mounted) setState(() => _page = _pageCount);

    // The store the finish screen (and, after claim, the app) will use. Handed
    // to the finish screen straight away, still empty; the background commit
    // fills it and the preview repaints as each reminder is created.
    final store = TaskStore();
    // Fire-and-forget: create the drafts (concurrently) under the anonymous
    // account. Best-effort — failures are swallowed per draft. Not awaited, so
    // the transition is instant — but REGISTERED with the ApiClient so login's
    // claim waits for every save to land before re-keying rows. Without that
    // barrier, a save still in flight during verification loses its data.
    final commit = commitOnboardingDrafts(store, drafts);
    ApiClient.instance.trackPendingWrite(commit);
    unawaited(commit);

    if (!mounted) return;
    await _leaveToAuth(
      child: OnboardingFinishScreen(store: store),
    );
  }

  void _toggle(String key) => setState(() {
    _picked.contains(key) ? _picked.remove(key) : _picked.add(key);
  });

  @override
  Widget build(BuildContext context) {
    // Page 1 is the category wizard. It no longer owns a top bar — the flow's
    // 3-dot header + Skip is now COMMON to all three screens, so the macro
    // progress (intro → categories → payoff) reads the same everywhere. The
    // wizard shows its own "which category of five" as a small inline counter
    // in its content, not a rival progress bar.
    final wizardPage = _page == 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // ONE sky behind all three pages — swiping moves through the same space
      // instead of swapping backgrounds. (The intro paints its own stars on its
      // orbit clock, so it sits on top of this without a seam.)
      body: Starfield(
        child: SafeArea(
          child: Column(
            children: [
              // Top: progress dots (left) + Skip (right). COMMON to every
              // onboarding screen, the wizard included — one consistent header.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    _ProgressDots(page: _page, count: _dotCount),
                    const Spacer(),
                    // Skip is available up to (but not on) the schedule step —
                    // once there, "Finish" is the only forward move.
                    if (_page < _pageCount - 1)
                      TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.inkFaint,
                        ),
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  // The picker (page 1) must advance only via its Continue
                  // button, not a stray swipe to the payoff — so block manual
                  // swipes there, EXCEPT while a programmatic transition runs, or
                  // the controller's own animateToPage off it would be blocked
                  // too.
                  physics: (wizardPage && !_animating)
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    IntroScreen(onStart: _next),
                    ChipSelectWizard(
                      picked: _picked,
                      onToggle: _toggle,
                      // Continue hands us a draft per picked item; merge into the
                      // shared map so the schedule step edits the same set, then
                      // advance to the payoff.
                      onComplete: (drafts) {
                        _drafts
                          ..clear()
                          ..addAll(drafts);
                        _goToPage(2);
                      },
                    ),
                    // Payoff's CTA now advances to the schedule step (page 3)
                    // instead of finishing.
                    PayoffScreen(
                      picked: _picked,
                      onDone: () => _goToPage(3),
                    ),
                    // The schedule step — day + frequency + every-N per pick.
                    ScheduleScreen(
                      picked: _picked,
                      drafts: _drafts,
                      onFinish: _complete,
                    ),
                  ],
                ),
              ),
              // No shared bottom CTA: EVERY page now carries its own button —
              // the intro ("Start tracking"), the wizard ("Continue"/"Finish"),
              // and the payoff ("Get started"). That's what stops a stray bar
              // from bleeding onto the wrong page during a transition.
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToPage(int i) async {
    // Unlock the PageView for the driven scroll (see [_animating]), animate,
    // then re-lock. Without the unlock, a transition that STARTS on the wizard
    // page — finishing the categories (1 → 2) or backing out (1 → 0) — is
    // rejected by the wizard's NeverScrollableScrollPhysics and never lands.
    setState(() => _animating = true);
    try {
      await _controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      if (mounted) setState(() => _animating = false);
    }
  }
}

/// The wide-pill progress indicator: the current page is a long accent bar.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(right: 6),
            width: i == page ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= page
                  ? AppColors.accent
                  : AppColors.inkFaint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
