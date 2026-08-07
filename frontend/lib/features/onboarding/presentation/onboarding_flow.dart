import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/starfield.dart';
import 'screens/chip_select_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/payoff_screen.dart';

/// The 3-screen onboarding: what it does → the chip picker ("what should we
/// remember?") → the big-number payoff. Minimal, stylised, visual. Call
/// [showOnboarding] to present it.
Future<void> showOnboarding(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const OnboardingFlow(),
    ),
  );
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.onDone});

  /// Called when the user finishes (or skips). Defaults to popping the route.
  final VoidCallback? onDone;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();

  /// Picked chip keys — the commonest ones arrive already selected.
  final Set<String> _picked = preselectedChipKeys();
  int _page = 0;

  /// True only while a PROGRAMMATIC page transition is in flight. The wizard
  /// page normally blocks user swipes with NeverScrollableScrollPhysics — but
  /// that physics also blocks [PageController.animateToPage], so finishing the
  /// wizard (page 1 → payoff page 2) would silently fail and snap back to the
  /// intro. Flipping this true for the duration of a driven transition lets the
  /// controller move the viewport, then it flips back so the wizard is locked
  /// to the user again.
  bool _animating = false;

  static const _pageCount = 3;

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
      _finish();
    }
  }

  void _finish() {
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _toggle(String key) => setState(() {
    _picked.contains(key) ? _picked.remove(key) : _picked.add(key);
  });

  String get _cta {
    switch (_page) {
      case 0:
        return 'Start tracking';
      case 1:
        return _picked.isEmpty ? 'Skip' : 'Add it up for me';
      default:
        return 'Get started';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Page 1 is the category wizard, which owns its own progress bar + bottom
    // button, so the flow's shared top dots and bottom CTA hide on that page.
    final wizardPage = _page == 1;
    // Page 0 (the intro) now carries its OWN "Start tracking" button, sitting
    // right under its copy — so the flow's shared bottom CTA only belongs to the
    // final payoff page. Without this the intro showed a dead-end (no button in
    // view) and the bar would double up.
    final showBottomCta = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // ONE sky behind all three pages — swiping moves through the same space
      // instead of swapping backgrounds. (The intro paints its own stars on its
      // orbit clock, so it sits on top of this without a seam.)
      body: Starfield(
        child: SafeArea(
          child: Column(
            children: [
              // Top: progress dots (left) + Skip (right). Hidden on the wizard.
              if (!wizardPage)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: [
                      _ProgressDots(page: _page, count: _pageCount),
                      const Spacer(),
                      if (_page < _pageCount - 1)
                        TextButton(
                          onPressed: _finish,
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
                  // The wizard drives its own paging; block manual swipes on it
                  // so the category flow stays in charge — but NOT while a
                  // programmatic transition is running, or the controller's own
                  // animateToPage off the wizard would be blocked too.
                  physics: (wizardPage && !_animating)
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    IntroScreen(onStart: _next),
                    ChipSelectWizard(
                      picked: _picked,
                      onToggle: _toggle,
                      onComplete: (_) => _goToPage(2),
                      onExit: () => _goToPage(0),
                    ),
                    PayoffScreen(picked: _picked),
                  ],
                ),
              ),
              // Bottom CTA — only the payoff page uses the shared bar now; the
              // intro carries its own button and the wizard has its own.
              if (showBottomCta)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _next, child: Text(_cta)),
                  ),
                ),
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
