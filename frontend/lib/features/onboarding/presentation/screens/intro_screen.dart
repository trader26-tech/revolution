import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/starfield.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';

/// Screen 1 — the "Orbit" welcome.
///
/// A deep-space sky with twinkling stars. Three faint orbit rings hang in it —
/// subscriptions, investments, insurance & documents — each with a category
/// hub at its centre and real, crisp app logos slowly orbiting it. Below: the
/// app logo as a floating planet, "Welcome to Revolution", one muted line.
/// Minimal text, maximum motion — all of it slow and calm.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  /// One-shot entrance: rings → hubs → logos → planet → text.
  late final AnimationController _enter;

  /// The endless sky clock: orbital motion, star twinkle, planet bob.
  /// One full revolution of the orbits per cycle — slow enough to feel like
  /// space, alive enough to catch the eye.
  late final AnimationController _sky;

  // The three rings. Every domain hand-checked to return a crisp, correct
  // logo (web.whatsapp.com serves 194px where whatsapp.com serves 23px, etc.).
  static const _rings = <_Ring>[
    // Subscriptions — mid-left, the biggest ring (like the screenshot).
    _Ring(
      cx: -70,
      cy: 10,
      radius: 100,
      hubSize: 74,
      hubIcon: Icons.subscriptions_rounded,
      dir: 1,
      logos: [
        _OrbitLogo(Brand(name: 'Netflix', domain: 'netflix.com'), 52, -10),
        _OrbitLogo(Brand(name: 'Spotify', domain: 'spotify.com'), 56, 128),
        _OrbitLogo(Brand(name: 'YouTube', domain: 'youtube.com'), 44, 243),
      ],
    ),
    // Investments / SIP — top-right, bleeding off the edge like the original.
    _Ring(
      cx: 95,
      cy: -125,
      radius: 82,
      hubSize: 68,
      hubIcon: Icons.trending_up_rounded,
      dir: -1,
      logos: [
        _OrbitLogo(Brand(name: 'Zerodha', domain: 'zerodha.com'), 50, 195),
        _OrbitLogo(Brand(name: 'Groww', domain: 'groww.in'), 44, 20),
      ],
    ),
    // Insurance & documents — bottom-right.
    _Ring(
      cx: 85,
      cy: 120,
      radius: 84,
      hubSize: 68,
      hubIcon: Icons.verified_user_rounded,
      dir: 1,
      logos: [
        // LIC's real mark is wide (emblem + wordmark) → bigger box.
        _OrbitLogo(Brand(name: 'LIC', domain: 'licindia.in'), 62, 155),
        _OrbitLogo(
          Brand(name: 'Policybazaar', domain: 'policybazaar.com'),
          42,
          -30,
        ),
        _OrbitLogo(
          Brand(name: 'India', domain: 'services.india.gov.in'),
          44,
          75,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _sky = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _enter.dispose();
    _sky.dispose();
    super.dispose();
  }

  /// Eased entrance progress for a slice of the timeline, with back-overshoot.
  double _pop(double start, [double window = 0.40]) {
    final t = ((_enter.value - start) / window).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(t);
  }

  /// Linear (clampable) progress — safe for opacity.
  double _lin(double start, [double window = 0.40]) =>
      ((_enter.value - start) / window).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _sky]),
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          // The twinkling starfield behind everything — driven by this screen's
          // own sky clock, so stars and orbits share one animation.
          RepaintBoundary(
            child: CustomPaint(
              painter: StarfieldPainter(
                t: _sky.value,
                stars: StarfieldPainter.starsFor(90, 7),
              ),
            ),
          ),
          Column(
            children: [
              const Spacer(flex: 2),
              SizedBox(height: 380, child: _orbits()),
              const Spacer(flex: 1),
              _planet(),
              const SizedBox(height: 26),
              _reveal(
                start: 0.48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Welcome to Revolution',
                      maxLines: 1,
                      style: text.headlineLarge?.copyWith(
                        color: AppColors.ink,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _reveal(
                start: 0.58,
                child: Text(
                  'Track your subscriptions, investments and\n'
                  'insurance — and never miss a date',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.inkSoft,
                    fontSize: 16.5,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }

  /// Fade + slide-up reveal driven by the entrance timeline.
  Widget _reveal({required double start, required Widget child}) {
    final t = Curves.easeOutCubic.transform(_lin(start, 0.35));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
    );
  }

  // ── The three orbit rings ──────────────────────────────────────────────────

  Widget _orbits() {
    // A global stagger index so hubs and logos cascade in one sweep.
    var stagger = 0;
    final children = <Widget>[];
    for (final ring in _rings) {
      children.add(_ringOutline(ring));
      children.add(_hub(ring, 0.08 + (stagger++) * 0.06));
      for (final logo in ring.logos) {
        children.add(_orbitingLogo(ring, logo, 0.16 + (stagger++) * 0.06));
      }
    }
    return Center(
      child: SizedBox(
        width: 340,
        height: 380,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: children,
        ),
      ),
    );
  }

  /// The faint circular track a ring's logos travel on.
  Widget _ringOutline(_Ring ring) {
    return Transform.translate(
      offset: Offset(ring.cx, ring.cy),
      child: Opacity(
        opacity: _lin(0.0, 0.5),
        child: Container(
          width: ring.radius * 2,
          height: ring.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// The dark category hub at a ring's centre.
  Widget _hub(_Ring ring, double start) {
    final pop = _pop(start);
    return Transform.translate(
      offset: Offset(ring.cx, ring.cy),
      child: Opacity(
        opacity: _lin(start),
        child: Transform.scale(
          scale: 0.5 + 0.5 * pop,
          child: Container(
            width: ring.hubSize,
            height: ring.hubSize,
            decoration: BoxDecoration(
              color: const Color(0xFF221B3F),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              ring.hubIcon,
              color: AppColors.ink.withValues(alpha: 0.85),
              size: ring.hubSize * 0.42,
            ),
          ),
        ),
      ),
    );
  }

  /// One logo travelling its ring — bare, crisp, upright (the position orbits;
  /// the logo itself never rotates).
  Widget _orbitingLogo(_Ring ring, _OrbitLogo logo, double start) {
    final angle =
        logo.angleDeg * math.pi / 180 + _sky.value * 2 * math.pi * ring.dir;
    final pos = Offset(
      ring.cx + ring.radius * math.cos(angle),
      ring.cy + ring.radius * math.sin(angle),
    );
    final pop = _pop(start);
    return Transform.translate(
      offset: pos,
      child: Opacity(
        opacity: _lin(start),
        child: Transform.scale(
          scale: 0.4 + 0.6 * pop,
          child: BrandLogo(
            brand: logo.brand,
            size: logo.size,
            radius: logo.size * 0.24,
            bare: true,
          ),
        ),
      ),
    );
  }

  // ── The planet: the app's own logo ─────────────────────────────────────────

  Widget _planet() {
    final pop = _pop(0.30, 0.45);
    final bob = math.sin(_sky.value * 2 * math.pi * 6) * 4;
    return Opacity(
      opacity: _lin(0.30, 0.45),
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Transform.scale(
          scale: 0.6 + 0.4 * pop,
          child: Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 44,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

/// One orbit ring: its centre (relative to the cluster centre), radius, the
/// category hub at its middle, orbit direction, and the logos travelling it.
class _Ring {
  const _Ring({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.hubSize,
    required this.hubIcon,
    required this.dir,
    required this.logos,
  });

  final double cx, cy;
  final double radius;
  final double hubSize;
  final IconData hubIcon;

  /// 1 = clockwise, -1 = counter-clockwise — alternating keeps it organic.
  final int dir;
  final List<_OrbitLogo> logos;
}

/// A logo on a ring: the brand, its box size, and its starting angle (deg).
class _OrbitLogo {
  const _OrbitLogo(this.brand, this.size, this.angleDeg);

  final Brand brand;
  final double size;
  final double angleDeg;
}
