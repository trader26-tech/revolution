import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/widgets/starfield.dart';

/// The celebratory "you're verified" moment — a short, satisfying beat between
/// a correct OTP and landing in the app.
///
/// Timeline (one controller):
///   1. A ring bursts open and a checkmark draws itself, with a soft accent
///      glow — the "yes!" instant.
///   2. Revo pops in beneath it with a happy bob.
///   3. "You're in." + the verified number fade up.
///   4. After a short hold, [onDone] fires and the gate rebuilds into the app.
///
/// It's intentionally brief (~1.8s): long enough to feel rewarding, short
/// enough that it never feels like a wall between the user and their app.
class VerifiedSuccessPage extends StatefulWidget {
  const VerifiedSuccessPage({
    super.key,
    required this.phoneE164,
    required this.onDone,
  });

  final String phoneE164;

  /// Fired once, after the celebration settles — hand control back to the gate.
  final VoidCallback onDone;

  @override
  State<VerifiedSuccessPage> createState() => _VerifiedSuccessPageState();
}

class _VerifiedSuccessPageState extends State<VerifiedSuccessPage>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_done) {
        _done = true;
        // A brief hold on the finished frame, then advance.
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double start, double end) =>
      ((_c.value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Starfield(
        intensity: 0.9,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final ring = Curves.easeOutBack.transform(_seg(0.0, 0.45));
              final check = Curves.easeOutCubic.transform(_seg(0.22, 0.6));
              final revoT = Curves.easeOutBack.transform(_seg(0.42, 0.8));
              final textT = Curves.easeOutCubic.transform(_seg(0.62, 1.0));

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Spacer(flex: 3),
                    // ── The badge: glowing ring + drawn checkmark ──
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Soft outer glow that swells with the ring.
                          Container(
                            width: 132 * ring,
                            height: 132 * ring,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.45 * ring),
                                  blurRadius: 40,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          // The ring itself.
                          Transform.scale(
                            scale: ring,
                            child: Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: AppColors.accent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                          // The checkmark, drawn stroke-by-stroke.
                          CustomPaint(
                            size: const Size(64, 64),
                            painter: _CheckPainter(progress: check),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ── Revo, popping in to celebrate ──
                    Opacity(
                      opacity: revoT.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - revoT)),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * revoT,
                          child: const AnimatedMascot(size: 96),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    // ── The words ──
                    Opacity(
                      opacity: textT,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - textT)),
                        child: Column(
                          children: [
                            const Text(
                              "You're in.",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.phoneE164} verified',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Draws a checkmark along its path as [progress] goes 0 → 1.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width, h = size.height;
    // The two strokes of a check, as fractions of the box.
    final p1 = Offset(w * 0.22, h * 0.52);
    final p2 = Offset(w * 0.42, h * 0.70);
    final p3 = Offset(w * 0.78, h * 0.30);

    final len1 = (p2 - p1).distance;
    final len2 = (p3 - p2).distance;
    final total = len1 + len2;
    final drawn = total * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= len1) {
      final t = drawn / len1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = ((drawn - len1) / len2).clamp(0.0, 1.0);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }

    final paint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
