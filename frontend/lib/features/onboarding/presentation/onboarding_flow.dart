import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'screens/benefits_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/quiz_screen.dart';

/// The 3-screen onboarding: what it does → a quick quiz → the personalised
/// money payoff. Minimal, stylised, visual. Call [showOnboarding] to present it.
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
  final Set<String> _picked = {};
  int _page = 0;

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
        return 'Show me how';
      case 1:
        return _picked.isEmpty ? 'Skip' : 'Show me why it matters';
      default:
        return 'Get started';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top: progress dots (left) + Skip (right).
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
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const IntroScreen(),
                  QuizScreen(picked: _picked, onToggle: _toggle),
                  BenefitsScreen(picked: _picked),
                ],
              ),
            ),
            // Bottom CTA.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_cta),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
