import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/widgets/starfield.dart';

/// The full-screen lock overlay shown when the App Lock session has expired.
///
/// Orbit space theme done right: the app's REAL mascot (Revo) over a calm
/// starfield, a soft accent glow, a clear lock chip, and one confident Unlock
/// button. The native biometric/PIN prompt fires automatically on mount (and on
/// return-to-foreground) so the OS sheet appears without an extra tap; the button
/// is the manual retry. Kept deliberately minimal so it reads as premium, not
/// busy.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock});

  /// Runs the native auth prompt; on success the parent gate unlocks.
  final Future<void> Function() onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    // Prompt immediately — the user is here to get back in. (The parent gate
    // owns resume-handling and an in-flight guard, so we don't double-fire.)
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onUnlock());
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Opaque space background so the app underneath is fully hidden while locked.
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Deep space gradient + a quiet starfield — the app's signature sky.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.bgTop, AppColors.bg],
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: Starfield(starCount: 40, intensity: 0.7)),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _in,
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  // Revo — the REAL brand mark — happy and bouncing inside a warm
                  // accent halo. This is the hero of the screen; no chip clutter.
                  _HaloMascot(anim: _in),
                  const SizedBox(height: 30),
                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 44),
                    child: Text(
                      'Unlock to pick up right where you left off.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const Spacer(flex: 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                    child: _UnlockButton(onTap: widget.onUnlock),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fingerprint, face, or device PIN',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkFaint,
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A HAPPY, bouncing Revo inside a warm accent halo — the delight of the screen.
/// A springy vertical bob with matching squash-and-stretch (the classic "happy
/// hop"), a cheerful tilt, and the occasional double-blink, over a soft glowing
/// bloom. Runs its own loop so it feels alive the whole time you're locked.
class _HaloMascot extends StatefulWidget {
  const _HaloMascot({required this.anim});

  /// The screen's entrance animation — used for the initial pop-in scale.
  final Animation<double> anim;

  @override
  State<_HaloMascot> createState() => _HaloMascotState();
}

class _HaloMascotState extends State<_HaloMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      // Slow + calm — one gentle float per ~5s, not a busy bounce.
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popIn = Tween(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: widget.anim, curve: Curves.easeOutBack));
    return ScaleTransition(
      scale: popIn,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final t = _loop.value; // 0..1
          // ONE slow, gentle float per loop — a soft rise and settle, no hop.
          final wave = math.sin(t * math.pi * 2); // -1..1, single smooth cycle
          final lift = -6.0 * (0.5 + 0.5 * wave); // drifts up ~6px and back
          // A whisper of squash, in sympathy with the drift — barely there.
          final squash = -0.05 * wave;
          final tilt = 0.02 * math.sin(t * math.pi * 2); // faint sway
          // A calm double-blink once per loop.
          final blink = _blinkAt(t);
          // Halo breathes very softly.
          final glowA = 0.22 + 0.06 * (0.5 + 0.5 * wave);

          return SizedBox(
            width: 176,
            height: 176,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: glowA),
                        AppColors.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, lift),
                  child: Mascot(
                    size: 120,
                    squash: squash,
                    tilt: tilt,
                    blink: blink,
                    // A slow, small wander of the gaze — calm, not darting.
                    look: Offset(0.07 * math.sin(t * math.pi * 2), -0.06),
                    glow: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// One quick double-blink centred at ~70% through the loop.
  double _blinkAt(double t) {
    double pulse(double c) {
      final d = (t - c).abs();
      return d < 0.03 ? (1 - d / 0.03) : 0.0;
    }

    return (pulse(0.70) + pulse(0.78)).clamp(0.0, 1.0);
  }
}

class _UnlockButton extends StatefulWidget {
  const _UnlockButton({required this.onTap});
  final Future<void> Function() onTap;

  @override
  State<_UnlockButton> createState() => _UnlockButtonState();
}

class _UnlockButtonState extends State<_UnlockButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint_rounded, size: 23, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Unlock',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
