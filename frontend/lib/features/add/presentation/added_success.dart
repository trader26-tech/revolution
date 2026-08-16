import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/widgets/starfield.dart';
import '../../tasks/domain/task.dart';

/// The success headline for a just-added item — the singular noun, capitalised:
/// "Subscription added", "SIP added", "Occasion added".
String addedLabel(TaskCategory category) {
  final s = category.singular;
  final titled = s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  return '$titled added';
}

/// The celebratory "Added!" moment — the same satisfying beat as the "You're
/// in." verified screen, reused for adding a reminder: a glowing ring bursts
/// open, a checkmark draws itself, Revo pops in happy, and the words fade up.
///
/// It's a full opaque page (dark Orbit sky + starfield), pushed on the root
/// navigator, so there's no see-through overlay and no debug-yellow text — it
/// looks like a real screen. Auto-advances after a short hold, then completes
/// the returned Future so the caller can navigate on.
Future<void> showAddedSuccess(
  BuildContext context, {
  required String label, // e.g. "Subscription added"
  String subtitle = 'Remo’s keeping an eye on it.',
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      // Appear INSTANTLY — no fade-in — so the moment the form closes the
      // celebration is already on screen (the ring/check/Revo IS the entrance).
      // No flash of the page underneath.
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _AddedSuccessPage(label: label, subtitle: subtitle),
    ),
  );
}

class _AddedSuccessPage extends StatefulWidget {
  const _AddedSuccessPage({required this.label, required this.subtitle});
  final String label;
  final String subtitle;

  @override
  State<_AddedSuccessPage> createState() => _AddedSuccessPageState();
}

class _AddedSuccessPageState extends State<_AddedSuccessPage>
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
        Future<void>.delayed(const Duration(milliseconds: 550), _close);
      }
    });
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
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
        child: GestureDetector(
          // Tap to skip straight through.
          onTap: _close,
          behavior: HitTestBehavior.opaque,
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
                                  color:
                                      AppColors.accent.withValues(alpha: 0.14),
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
                              Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.subtitle,
                                textAlign: TextAlign.center,
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
