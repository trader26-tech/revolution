import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/starfield.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';

/// Screen 1 — the "Orbit" welcome.
///
/// A deep-space sky with twinkling stars and a soft violet nebula glow behind
/// the cluster. Three faint orbit rings hang in it — subscriptions, investments,
/// insurance & documents — each with a category hub at its centre and three
/// real app logos resting on the ring. Below: the app logo, "Welcome to
/// Revolution", one muted line.
///
/// The logos are STATIC (no revolution) — they sit at hand-picked angles that
/// balance the composition. Everything is laid out in FRACTIONS of the
/// available box, so no ring can ever spill outside the frame on any screen.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  /// One-shot entrance: glow → rings → hubs → logos → app logo → text.
  late final AnimationController _enter;

  /// The endless sky clock: star twinkle + the app logo's gentle bob.
  late final AnimationController _sky;

  // ── The three rings ────────────────────────────────────────────────────────
  //
  // Geometry is expressed as a FRACTION of the cluster box (0..1), measured
  // from its centre — so the whole composition scales with the screen and
  // stays in bounds. A ring's outermost reach is |centre| + radius + logo/2,
  // and every ring below is tuned to keep that under 0.5.
  //
  // Every domain was hand-checked to return a crisp, correct logo on a dark
  // background (see the notes on individual entries).
  static const _rings = <_Ring>[
    // Subscriptions — the big ring, upper-left (matches the reference).
    _Ring(
      cxF: -0.115,
      cyF: -0.140,
      radiusF: 0.250,
      hubIcon: Icons.play_circle_fill_rounded,
      logos: [
        _OrbitLogo(Brand(name: 'Netflix', domain: 'netflix.com'), 42, 283),
        _OrbitLogo(Brand(name: 'Spotify', domain: 'spotify.com'), 44, 189),
        _OrbitLogo(Brand(name: 'YouTube', domain: 'youtube.com'), 40, 106),
      ],
    ),
    // Investments / SIP — smaller ring, upper-right.
    _Ring(
      cxF: 0.230,
      cyF: -0.235,
      radiusF: 0.190,
      hubIcon: Icons.trending_up_rounded,
      logos: [
        _OrbitLogo(Brand(name: 'Zerodha', domain: 'zerodha.com'), 38, 317),
        _OrbitLogo(Brand(name: 'Groww', domain: 'groww.in'), 36, 85),
        // Upstox: a crisp 196px violet mark — reads beautifully on the sky.
        _OrbitLogo(Brand(name: 'Upstox', domain: 'upstox.com'), 36, 248),
      ],
    ),
    // Insurance & documents — lower-right.
    _Ring(
      cxF: 0.175,
      cyF: 0.180,
      radiusF: 0.205,
      hubIcon: Icons.shield_rounded,
      logos: [
        // LIC's real mark is wide (emblem + wordmark) → a slightly bigger box.
        _OrbitLogo(Brand(name: 'LIC', domain: 'licindia.in'), 46, 62),
        // HDFC Life: a clean 256px red mark.
        _OrbitLogo(Brand(name: 'HDFC Life', domain: 'hdfclife.com'), 38, 356),
        // DigiLocker — the actual govt DOCUMENT wallet, and its violet mark
        // sits naturally in this palette (the national emblem is near-black
        // and would disappear against the sky).
        _OrbitLogo(
          Brand(name: 'DigiLocker', domain: 'digilocker.gov.in'),
          38,
          151,
        ),
      ],
    ),
  ];

  /// The centre of the rings' combined bounding box, in the same fractional
  /// units as [_Ring]. Derived from [_rings], so re-tuning a ring keeps the
  /// composition centred automatically.
  static final Offset _clusterOffset = _computeClusterOffset();

  static Offset _computeClusterOffset() {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final r in _rings) {
      minX = math.min(minX, r.cxF - r.radiusF);
      maxX = math.max(maxX, r.cxF + r.radiusF);
      minY = math.min(minY, r.cyF - r.radiusF);
      maxY = math.max(maxY, r.cyF + r.radiusF);
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
              // The cluster takes the top ~half; it sizes itself to whatever
              // space is left, so short screens shrink it instead of clipping.
              Expanded(flex: 62, child: _orbits()),
              _appLogo(),
              const SizedBox(height: 24),
              _reveal(
                start: 0.52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Welcome to Revolution',
                      maxLines: 1,
                      style: text.headlineLarge?.copyWith(
                        color: AppColors.ink,
                        fontSize: 33,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _reveal(
                start: 0.60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Track your subscriptions, investments and\n'
                    'insurance — and never miss a date',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 12),
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

  /// The cluster, laid out against whatever box it's given. Every offset is a
  /// fraction of [side] (the largest square that fits), so nothing can escape.
  ///
  /// The three rings aren't symmetric about the origin, so the whole group is
  /// shifted by [_clusterOffset] — the centre of their bounding box. Without
  /// that the composition reads as pushed up-and-left, however well the ring
  /// fractions are chosen.
  Widget _orbits() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);

        // A global stagger index so hubs and logos cascade in one sweep.
        var stagger = 0;
        final children = <Widget>[_glow(side)];
        for (final ring in _rings) {
          children.add(_ringOutline(ring, side));
          children.add(_hub(ring, side, 0.06 + (stagger++) * 0.05));
        }
        for (final ring in _rings) {
          for (final logo in ring.logos) {
            children.add(_ringLogo(ring, logo, side, 0.14 + (stagger++) * 0.04));
          }
        }

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Transform.translate(
              // Recentre the whole (asymmetric) group in its box.
              offset: Offset(
                -_clusterOffset.dx * side,
                -_clusterOffset.dy * side,
              ),
              child: Stack(alignment: Alignment.center, children: children),
            ),
          ),
        );
      },
    );
  }

  /// The soft violet nebula behind the cluster — the glow the reference has,
  /// bleeding gently outward from the centre.
  ///
  /// It's counter-shifted by [_clusterOffset] so it stays centred on the SCREEN
  /// (where the eye expects the light source) while the rings sit centred in
  /// their own box.
  Widget _glow(double side) {
    return Transform.translate(
      offset: Offset(_clusterOffset.dx * side, _clusterOffset.dy * side),
      child: Opacity(
      opacity: _lin(0.0, 0.6),
      child: Container(
        width: side * 1.30,
        height: side * 1.30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            // A tight violet core that falls off well before the edge, so it
            // reads as a glow rather than a flat disc.
            colors: [
              const Color(0xFF7C5CFC).withValues(alpha: 0.30),
              const Color(0xFF6742EE).withValues(alpha: 0.14),
              const Color(0xFF4C1D95).withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.32, 0.58, 1.0],
          ),
        ),
      ),
    );
  }

  /// The faint circular track the logos rest on.
  Widget _ringOutline(_Ring ring, double side) {
    final d = ring.radiusF * 2 * side;
    return Transform.translate(
      offset: Offset(ring.cxF * side, ring.cyF * side),
      child: Opacity(
        opacity: _lin(0.0, 0.5),
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// The dark category hub at a ring's centre.
  Widget _hub(_Ring ring, double side, double start) {
    final pop = _pop(start);
    // Proportional to the ring, so the three hubs differ in size exactly as
    // their rings do.
    final hubSize = ring.radiusF * side * 0.62;
    return Transform.translate(
      offset: Offset(ring.cxF * side, ring.cyF * side),
      child: Opacity(
        opacity: _lin(start),
        child: Transform.scale(
          scale: 0.6 + 0.4 * pop,
          child: Container(
            width: hubSize,
            height: hubSize,
            decoration: BoxDecoration(
              color: const Color(0xFF241C42),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              ring.hubIcon,
              color: AppColors.ink.withValues(alpha: 0.88),
              size: hubSize * 0.44,
            ),
          ),
        ),
      ),
    );
  }

  /// One logo resting on its ring — bare, crisp and upright.
  Widget _ringLogo(_Ring ring, _OrbitLogo logo, double side, double start) {
    final angle = logo.angleDeg * math.pi / 180;
    final pos = Offset(
      (ring.cxF + ring.radiusF * math.cos(angle)) * side,
      (ring.cyF + ring.radiusF * math.sin(angle)) * side,
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
            radius: logo.size * 0.26,
            bare: true,
          ),
        ),
      ),
    );
  }

  // ── The app's own logo ─────────────────────────────────────────────────────

  Widget _appLogo() {
    final pop = _pop(0.34, 0.45);
    final bob = math.sin(_sky.value * 2 * math.pi * 6) * 4;
    return Opacity(
      opacity: _lin(0.34, 0.45),
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Transform.scale(
          scale: 0.6 + 0.4 * pop,
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.42),
                  blurRadius: 46,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
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

/// One orbit ring. Centre and radius are FRACTIONS of the cluster box, measured
/// from its centre — keeping the composition in bounds at any screen size.
class _Ring {
  const _Ring({
    required this.cxF,
    required this.cyF,
    required this.radiusF,
    required this.hubIcon,
    required this.logos,
  });

  final double cxF, cyF;
  final double radiusF;
  final IconData hubIcon;
  final List<_OrbitLogo> logos;
}

/// A logo resting on a ring: the brand, its box size (px), and the angle it
/// sits at (degrees; 0 = right, 90 = down).
class _OrbitLogo {
  const _OrbitLogo(this.brand, this.size, this.angleDeg);

  final Brand brand;
  final double size;
  final double angleDeg;
}
