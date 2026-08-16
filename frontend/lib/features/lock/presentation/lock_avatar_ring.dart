import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/presentation/widgets/profile_avatar.dart';
import '../data/app_lock_store.dart';
import 'lock_timer_pill.dart' show showAutoLockSheet;

/// The App Lock countdown drawn AS the profile avatar's edge: a thin accent arc
/// that sits flush at the rim of the photo circle and slowly SPINS, its swept
/// length shrinking as the session drains. A small time PILL clings to the
/// bottom of the avatar showing "M:SS". Tapping the pill opens the auto-lock
/// presets (change the duration / lock now).
///
/// When the lock is off (or no session is live) it renders the bare avatar.
class LockAvatarRing extends StatefulWidget {
  const LockAvatarRing({super.key, this.avatarSize = 44});

  /// The avatar diameter. The ring hugs its rim; the pill overlaps its base.
  final double avatarSize;

  @override
  State<LockAvatarRing> createState() => _LockAvatarRingState();
}

class _LockAvatarRingState extends State<LockAvatarRing> {
  final _store = AppLockStore.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 1s tick advances the countdown digits + the draining arc. No spin — the
    // ring is a calm countdown, not a busy spinner.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.avatarSize;
    final now = DateTime.now();
    final remaining = _store.enabled ? _store.remainingAt(now) : Duration.zero;
    final showRing = _store.enabled && remaining > Duration.zero;

    if (!showRing) {
      return ProfileAvatar(size: size);
    }

    final total = _store.sessionLength.inSeconds;
    final progress =
        total == 0 ? 0.0 : (remaining.inSeconds / total).clamp(0.0, 1.0);
    // Warm to red in the final stretch so "almost locking" reads at a glance.
    final color =
        progress <= 0.12 ? const Color(0xFFFF6B6B) : AppColors.accent;

    // The ring is painted right at the avatar's rim (a hair outside), so the
    // whole control is barely larger than the photo itself.
    const stroke = 2.6;
    final ringBox = size + stroke * 2; // just the stroke beyond the rim

    // The pill overlaps the avatar's bottom edge, so it reads as attached.
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showAutoLockSheet(context);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        // Extra height so the pill can hang below the avatar without clipping.
        width: ringBox,
        height: ringBox + 12,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Avatar + the flush countdown ring.
            SizedBox(
              width: ringBox,
              height: ringBox,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The countdown arc at the rim — full from the top, draining
                  // anticlockwise. Repaints only when `progress` changes (once a
                  // second), so it's cheap.
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(ringBox, ringBox),
                      painter: _RimRingPainter(
                        progress: progress,
                        color: color,
                        stroke: stroke,
                      ),
                    ),
                  ),
                  // The avatar itself — still tappable to change the photo.
                  ProfileAvatar(size: size),
                ],
              ),
            ),
            // The time pill, clinging to the avatar's bottom.
            Positioned(
              bottom: 0,
              child: _TimePill(label: _fmt(remaining), color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The little "M:SS" pill that clings to the avatar's base — a compact status
/// badge with a subtle border so it lifts off the photo.
class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Paints the countdown arc right at the avatar's rim. It starts FULL from the
/// TOP (12 o'clock) and DRAINS ANTICLOCKWISE as time runs down — a normal, calm
/// countdown, no spinning. A faint full-circle track sits under it so the rim
/// always reads as a ring.
class _RimRingPainter extends CustomPainter {
  _RimRingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  final double progress; // 1 → full, 0 → empty
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full-circle track.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.cardBorder.withValues(alpha: 0.6);
    canvas.drawCircle(center, radius, track);

    // The live arc: anchored at the TOP (−90°), sweeping ANTICLOCKWISE (negative
    // sweep). Its length is the remaining fraction, so it shrinks back toward the
    // top as the countdown drains.
    const startTop = -math.pi / 2;
    final sweep = -2 * math.pi * progress.clamp(0.0, 1.0);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, startTop, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RimRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.stroke != stroke;
}
