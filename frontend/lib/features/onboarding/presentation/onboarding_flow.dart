import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/starfield.dart';
import '../../auth/data/auth_store.dart';
import '../../auth/presentation/auth_gate.dart';
import '../data/onboarding_store.dart';
import 'screens/intro_screen.dart';
import 'screens/stat_screen.dart';

/// The onboarding flow — deliberately short:
///
///   1. Intro     — the "Orbit" welcome (what Revolution is).
///   2. Stat      — the reassurance beat ("people juggle 450 things a day —
///                  don't worry, I'll remember"), one button forward.
///   → then straight to phone verify + login, and into the app.
///
/// No pickers, no preselected details, nothing to configure. The point is to
/// welcome, reassure, and get the user moving.
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

  /// Called when the user finishes (marks onboarding complete). Null in the dev
  /// "replay" path, where we sign out first so login always shows.
  final VoidCallback? onDone;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Leave onboarding for the auth gate (phone verify + login → app). Marks
  /// onboarding complete so it never reappears; signs out first on the dev
  /// replay path (no [onDone]) so the login page always shows.
  Future<void> _toAuth() async {
    OnboardingStore.instance.markComplete();
    widget.onDone?.call();
    if (widget.onDone == null) {
      await AuthStore.instance.logout();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // One sky behind both pages — swiping moves through the same space.
      body: Starfield(
        child: SafeArea(
          child: Column(
            children: [
              // Progress dots (left) + Skip (right).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    _ProgressDots(page: _page, count: _pageCount),
                    const Spacer(),
                    if (_page < _pageCount - 1)
                      TextButton(
                        onPressed: _toAuth,
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
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    IntroScreen(onStart: _next),
                    StatScreen(onContinue: _toAuth),
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

/// The progress indicator: the current page is a long accent bar.
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
