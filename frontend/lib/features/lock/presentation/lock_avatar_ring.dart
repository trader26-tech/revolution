import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/presentation/widgets/profile_avatar.dart';
import '../data/app_lock_store.dart';
import 'lock_timer_pill.dart' show showAutoLockSheet;

/// The App Lock countdown, wrapped AROUND the user's profile avatar — a thin
/// accent progress ring that drains as the session runs down, with the remaining
/// time as "M:SS" shown just below. One tidy cluster in the Home greeting: the
/// avatar stays tappable (add/change photo), and tapping the TIME opens the
/// auto-lock settings.
///
/// When the lock is off (or no session is live) it renders the bare avatar, so
/// nothing extra intrudes.
class LockAvatarRing extends StatefulWidget {
  const LockAvatarRing({super.key, this.avatarSize = 44});

  /// The inner avatar diameter. The ring + time sit around/under it.
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
    // Lock off / no live session → just the avatar, no ring, no time.
    final now = DateTime.now();
    final remaining = _store.enabled ? _store.remainingAt(now) : Duration.zero;
    final showRing = _store.enabled && remaining > Duration.zero;

    if (!showRing) {
      return ProfileAvatar(size: size);
    }

    final total = _store.sessionLength.inSeconds;
    final progress =
        total == 0 ? 0.0 : (remaining.inSeconds / total).clamp(0.0, 1.0);
    // The ring hugs the avatar with a small breathing gap.
    const gap = 5.0;
    const stroke = 3.0;
    final ringSize = size + gap * 2 + stroke * 2;
    // Ring warms to a warning tint in the final stretch, so "almost locking"
    // reads at a glance without a separate alert.
    final ringColor = progress <= 0.12
        ? const Color(0xFFFF6B6B) // soft red near the end
        : AppColors.accent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The draining ring.
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: stroke,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: AlwaysStoppedAnimation(ringColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // The avatar sits inside the ring, still fully tappable.
              ProfileAvatar(size: size),
            ],
          ),
        ),
        const SizedBox(height: 5),
        // The remaining time — tap to change the auto-lock duration.
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            showAutoLockSheet(context);
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock_rounded,
                  size: 11, color: ringColor.withValues(alpha: 0.9)),
              const SizedBox(width: 3),
              Text(
                _fmt(remaining),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: ringColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
