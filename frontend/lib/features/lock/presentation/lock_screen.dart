import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
                  // A calm glowing lock emblem — the hero of the screen. (The
                  // mascot was removed here per product direction; the lock glyph
                  // keeps the screen premium and on-theme without it.)
                  _LockEmblem(anim: _in),
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

/// A calm glowing lock emblem — a lock glyph on an accent-tinted disc, wrapped
/// in a soft radial halo that breathes very gently. Pops in with the screen's
/// entrance, then rests: premium and quiet, no looping motion to distract.
class _LockEmblem extends StatefulWidget {
  const _LockEmblem({required this.anim});

  /// The screen's entrance animation — used for the initial pop-in scale.
  final Animation<double> anim;

  @override
  State<_LockEmblem> createState() => _LockEmblemState();
}

class _LockEmblemState extends State<_LockEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    // A very slow halo breath — barely perceptible, just enough life.
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popIn = Tween(begin: 0.86, end: 1.0)
        .animate(CurvedAnimation(parent: widget.anim, curve: Curves.easeOutBack));
    return ScaleTransition(
      scale: popIn,
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, _) {
          final glowA = 0.20 + 0.10 * _breathe.value;
          return SizedBox(
            width: 168,
            height: 168,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft accent bloom.
                Container(
                  width: 168,
                  height: 168,
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
                // The disc + lock glyph.
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9B7CFF), AppColors.accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.45),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_rounded,
                      size: 42, color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
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
