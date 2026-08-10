import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';

/// Screen 2 — the reassurance stat.
///
/// A single striking figure counts up ("450 things a day"), the honest line that
/// nobody can hold all that in their head, then Revo's promise: *don't worry — I
/// was made to remember.* One button takes you straight to verify + login.
///
/// No pickers, no preselected details — the point is to move the user forward
/// with a warm, confident beat.
class StatScreen extends StatefulWidget {
  const StatScreen({super.key, this.onContinue});

  /// Advance to the phone verify/login step. Null in previews → the button hides.
  final VoidCallback? onContinue;

  @override
  State<StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends State<StatScreen> with TickerProviderStateMixin {
  // The big number counts up 0 → 450 for impact.
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  // A staged entrance for the copy + Revo + button.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  static const _target = 450;

  @override
  void initState() {
    super.initState();
    _enter.forward();
    // Let the screen settle, then run the count-up.
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _count.forward();
    });
  }

  @override
  void dispose() {
    _count.dispose();
    _enter.dispose();
    super.dispose();
  }

  double _seg(double start, double end) =>
      ((_enter.value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: AnimatedBuilder(
          animation: Listenable.merge([_count, _enter]),
          builder: (context, _) {
            final revoT = Curves.easeOutBack.transform(_seg(0.0, 0.5));
            final headT = _seg(0.15, 0.6);
            final numT = _seg(0.3, 0.75);
            final subT = _seg(0.55, 0.95);
            final btnT = _seg(0.7, 1.0);
            final count =
                (Curves.easeOutCubic.transform(_count.value) * _target).round();

            return Column(
              children: [
                // Balanced, modest breathing room top and bottom — the content
                // is grouped tightly in the middle so it reads as one compact,
                // deliberate block rather than floating in empty space.
                const Spacer(flex: 3),
                // Revo, popping in.
                Opacity(
                  opacity: revoT.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * revoT,
                    child: const AnimatedMascot(size: 74),
                  ),
                ),
                const SizedBox(height: 20),
                // The lead-in line.
                _fade(
                  headT,
                  const Text(
                    'On an average day, people juggle',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // The big counting number + its label, on one baseline.
                _fade(
                  numT,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [AppColors.ink, Color(0xFFB9A8FF)],
                        ).createShader(r),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 60,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'things',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                _fade(
                  numT,
                  const Text(
                    'worth remembering',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // Revo's reassurance.
                _fade(
                  subT,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.28)),
                    ),
                    child: const Text(
                      'You can’t hold all that in your head — and you don’t have to. Revo remembers, so you never have to.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 4),
                if (widget.onContinue != null)
                  _fade(
                    btnT,
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: widget.onContinue,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.accent, AppColors.accentDeep]),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Let Revo remember',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  )),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fade(double t, Widget child) {
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    );
  }
}
