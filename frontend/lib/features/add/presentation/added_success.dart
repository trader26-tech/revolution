import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mascot.dart';

/// A brief, joyful "Added!" moment — a happy Revo pops in with a ring of little
/// sparks (all drawn, no emoji), a checkmark badge, and a message. Auto-
/// dismisses. Await it before navigating on.
Future<void> showAddedSuccess(
  BuildContext context, {
  required String label, // e.g. "Subscription added"
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _AddedSuccessOverlay(label: label),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _AddedSuccessOverlay extends StatefulWidget {
  const _AddedSuccessOverlay({required this.label});
  final String label;

  @override
  State<_AddedSuccessOverlay> createState() => _AddedSuccessOverlayState();
}

class _AddedSuccessOverlayState extends State<_AddedSuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pop; // one-shot entrance + spark burst
  late final AnimationController _life; // Revo's happy bob while it shows

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _life = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    // Auto-dismiss and return to the caller.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1650));
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap anywhere to skip straight through.
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pop, _life]),
          builder: (context, _) {
            final p = _pop.value;
            // Revo pops with an over-shoot, then settles.
            final scale = Curves.easeOutBack.transform(p.clamp(0.0, 1.0));
            final t = _life.value;
            final breath = math.sin(t * 2 * math.pi);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Revo + sparks + check badge.
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The spark burst behind Revo.
                      CustomPaint(
                        size: const Size(200, 200),
                        painter: _SparkPainter(p),
                      ),
                      // Happy Revo, bobbing, glowing.
                      Transform.translate(
                        offset: Offset(0, breath * 5),
                        child: Transform.scale(
                          scale: 0.5 + 0.5 * scale,
                          child: _HappyRevo(t: t, size: 116),
                        ),
                      ),
                      // A checkmark badge on the lower-right of Revo.
                      Positioned(
                        right: 30,
                        bottom: 34,
                        child: Transform.scale(
                          scale: Curves.easeOutBack
                              .transform((p * 1.4 - 0.4).clamp(0.0, 1.0)),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                AppColors.accent,
                                AppColors.accentDeep
                              ]),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.bg, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.5),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // The message, sliding up + fading in slightly after Revo.
                Opacity(
                  opacity: ((p - 0.25) / 0.5).clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [AppColors.ink, Color(0xFFB9A8FF)],
                        ).createShader(r),
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Nice — Revo’s got it from here.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Revo wearing his happiest face — a lively bob, wide gaze, glow on.
class _HappyRevo extends StatelessWidget {
  const _HappyRevo({required this.t, required this.size});
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    final phase = t * 2 * math.pi;
    double blink() {
      final d = (t - 0.5).abs();
      return d > 0.03 ? 0 : 1 - d / 0.03;
    }

    return Mascot(
      size: size,
      blink: blink(),
      look: Offset(math.sin(phase) * 0.12, -0.12), // looking up, pleased
      squash: math.sin(phase * 2) * 0.06,
      tilt: math.sin(phase) * 0.05,
      glow: true,
    );
  }
}

/// A one-shot ring of little sparks bursting outward — drawn, no emoji.
class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.p);
  final double p; // 0..1 progress

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 6);
    // Ease-out expansion + fade near the end.
    final e = Curves.easeOut.transform(p.clamp(0.0, 1.0));
    final fade = (1 - ((p - 0.55) / 0.45)).clamp(0.0, 1.0);
    if (fade <= 0) return;

    const count = 12;
    final maxR = size.width * 0.46;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + 0.3;
      final r = maxR * e;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * r;
      final len = 10.0 * (1 - e * 0.5);
      final tail = pos -
          Offset(math.cos(angle), math.sin(angle)) * len;
      final paint = Paint()
        ..color = (i.isEven ? AppColors.accent : const Color(0xFFB9A8FF))
            .withValues(alpha: fade)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, pos, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.p != p;
}
