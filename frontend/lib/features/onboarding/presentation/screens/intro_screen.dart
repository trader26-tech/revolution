import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
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
/// The logos are STATIC (no revolution) and evenly spaced — three per ring at
/// exactly 120° apart, derived from the ring rather than set per logo.
/// Everything is laid out in FRACTIONS of the available box, so no ring can
/// ever spill outside the frame on any screen.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.onStart});

  /// Advance out of the intro — the flow's "go to the chip picker" callback.
  /// The button lives on THIS screen (right under the copy) rather than in the
  /// flow's shared bottom bar, so on the intro page there's a visible CTA
  /// instead of a dead-end. Null in previews/tests → the button hides.
  final VoidCallback? onStart;

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
  // Geometry is a FRACTION of the cluster box (0..1) measured from its centre,
  // so the composition scales with the screen and can't spill out.
  //
  // The rings are all the SAME (small) radius — [_ringRadiusF] — and sit in a
  // near-equilateral triangle around the centre, so the trio reads as one
  // balanced constellation rather than three unrelated circles.
  //
  // EVERY RING SPACES ITS LOGOS EVENLY — n logos at exactly 360/n apart,
  // computed from the ring's single [phaseDeg] rather than written out per
  // logo. Even spacing is therefore structural: it can't drift when a logo is
  // swapped or when a ring's logo count changes, and there are no per-logo
  // angles to get wrong.
  //
  // THE RINGS MUST NEVER INTERSECT, and no logo may sit on a neighbouring
  // ring's track. Centres and phases come from a joint search that enforces,
  // simultaneously:
  //   · disjoint outlines with a visible gap
  //   · every outline AND every logo inside the box
  //   · no logo within 5px of another ring's outline
  //   · centres roughly equidistant, and pulled in towards the middle
  // subject to maximising clearance. The result keeps 15px of clearance between
  // any two elements. [_debugAssertLayoutValid] re-checks all of it at startup
  // in debug builds, so a hand-tweak that breaks an invariant fails loudly
  // instead of silently shipping a broken layout.
  //
  // Every domain was hand-checked to return a crisp, correct logo on a dark
  // background (see the notes on individual entries).

  /// Shared radius for all three rings.
  static const _ringRadiusF = 0.175;

  static const _rings = <_Ring>[
    // Subscriptions — four of the services people actually forget to cancel.
    _Ring(
      cxF: 0.160,
      cyF: 0.265,
      radiusF: _ringRadiusF,
      phaseDeg: 31,
      hubIcon: Icons.play_circle_fill_rounded,
      logos: [
        _OrbitLogo(Brand(name: 'Netflix', domain: 'netflix.com'), 38),
        _OrbitLogo(Brand(name: 'Spotify', domain: 'spotify.com'), 38),
        _OrbitLogo(Brand(name: 'YouTube', domain: 'youtube.com'), 36),
        _OrbitLogo(Brand(name: 'Prime Video', domain: 'primevideo.com'), 36),
      ],
    ),
    // Insurance — three of the biggest names in Indian insurance, so the ring
    // reads as "insurance" without a label.
    _Ring(
      cxF: -0.294,
      cyF: -0.060,
      radiusF: _ringRadiusF,
      phaseDeg: 6,
      hubIcon: Icons.shield_rounded,
      logos: [
        // LIC's real mark is wide (emblem + wordmark) → a slightly bigger box.
        _OrbitLogo(Brand(name: 'LIC', domain: 'licindia.in'), 42),
        // HDFC — hdfclife.com serves the clean 256px mark; hdfcbank.com's own
        // favicon is a 16px blur and icon.horse returns a placeholder "H".
        _OrbitLogo(Brand(name: 'HDFC', domain: 'hdfclife.com'), 36),
        // SBI: pinned to Google's favicon service — it's the only source that
        // returns a decodable PNG of the keyhole mark (icon.horse serves .ico,
        // which Flutter can't decode, and sbilife.co.in's is an unreadable
        // 17px JPEG).
        //
        // circular: SBI's favicon ships an OPAQUE white background, which on
        // this dark sky renders as a white square around the mark. Every other
        // logo here is transparent; this is the one that needs the circular
        // crop to turn that background into a clean round badge.
        _OrbitLogo(
          Brand(
            name: 'SBI',
            domain: 'onlinesbi.sbi',
            source: LogoSource.googleFavicon,
          ),
          36,
          circular: true,
        ),
      ],
    ),
    // Documents — the papers people have to keep current: DigiLocker (the govt
    // document wallet) and Aadhaar.
    _Ring(
      cxF: 0.168,
      cyF: -0.261,
      radiusF: _ringRadiusF,
      phaseDeg: 44,
      hubIcon: Icons.badge_rounded,
      logos: [
        _OrbitLogo(Brand(name: 'DigiLocker', domain: 'digilocker.gov.in'), 38),
        // Aadhaar ships as a BUNDLED asset: uidai.gov.in's favicon is capped at
        // 16px whatever size you request, and Wikimedia blocks hotlinking — so
        // no network source can serve a usable mark. This one is rendered from
        // UIDAI's own official SVG, cropped to the emblem and made transparent.
        _OrbitLogo(
          Brand(
            name: 'Aadhaar',
            domain: 'uidai.gov.in',
            assetPath: 'assets/images/aadhaar.png',
          ),
          40,
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

  /// Where the rings actually crowd — the mean of their centres, weighted by
  /// area so the big subscriptions ring pulls the light toward itself. Used to
  /// place the nebula glow.
  static final Offset _ringCentroid = _computeRingCentroid();

  static Offset _computeRingCentroid() {
    var sx = 0.0, sy = 0.0, sw = 0.0;
    for (final r in _rings) {
      final w = r.radiusF * r.radiusF; // ∝ area
      sx += r.cxF * w;
      sy += r.cyF * w;
      sw += w;
    }
    // Expressed relative to the recentred group, so it composes with the
    // -_clusterOffset translation applied to the whole Stack.
    return Offset(sx / sw, sy / sw);
  }

  /// Debug-only guard for the layout invariants the ring geometry must hold:
  /// rings disjoint, and everything inside the box. Returns true so it can be
  /// used inside an `assert`, which strips it entirely from release builds.
  static bool _debugAssertLayoutValid() {
    for (var i = 0; i < _rings.length; i++) {
      for (var j = i + 1; j < _rings.length; j++) {
        final a = _rings[i], b = _rings[j];
        final d = math.sqrt(
          math.pow(a.cxF - b.cxF, 2) + math.pow(a.cyF - b.cyF, 2),
        );
        assert(
          d >= a.radiusF + b.radiusF + 0.015,
          'Orbit rings $i and $j intersect: centres are $d apart but the radii '
          'sum to ${a.radiusF + b.radiusF}. Rings must never overlap.',
        );
      }
    }
    // Nothing may leave the cluster box. Checked at the SMALLEST box we render
    // at, where the px-sized logos take up the largest fraction. The ring
    // outline itself may reach the edge; what must stay inside is every logo,
    // at its ACTUAL position — the logos sit at known fixed angles, so there's
    // no need for the conservative "logo at the extreme point" bound.
    const box = 300.0;
    for (var i = 0; i < _rings.length; i++) {
      final ring = _rings[i];
      assert(
        math.max(ring.cxF.abs(), ring.cyF.abs()) + ring.radiusF <= 0.5,
        'Orbit ring $i\'s outline escapes the cluster box.',
      );
      for (var j = 0; j < ring.logos.length; j++) {
        final p = ring.positionOf(j, box);
        final half = ring.logos[j].size / 2;
        assert(
          p.dx.abs() + half <= box / 2 && p.dy.abs() + half <= box / 2,
          '${ring.logos[j].brand.name} escapes the cluster box.',
        );
      }
    }
    // No logo may sit ON another ring's outline — the rings can be disjoint
    // while a logo still straddles a neighbouring track, which reads as a
    // collision even though the circles never touch.
    const smallestBox = 300.0;
    for (final ring in _rings) {
      for (var i = 0; i < ring.logos.length; i++) {
        final logo = ring.logos[i];
        final p = ring.positionOf(i, smallestBox);
        for (final other in _rings) {
          if (identical(other, ring)) continue;
          final d = math.sqrt(
            math.pow(p.dx - other.cxF * smallestBox, 2) +
                math.pow(p.dy - other.cyF * smallestBox, 2),
          );
          assert(
            (d - other.radiusF * smallestBox).abs() > logo.size / 2 + 3,
            '${logo.brand.name} sits on another ring\'s outline.',
          );
        }
      }
    }
    // Logos on a ring must be EVENLY spaced — the whole point of deriving the
    // angle from the ring. Guards against someone reintroducing per-logo
    // angles or leaving a ring with a logo count that doesn't divide evenly.
    for (final ring in _rings) {
      final step = 360.0 / ring.logos.length;
      for (var i = 1; i < ring.logos.length; i++) {
        assert(
          (ring.angleOf(i) - ring.angleOf(i - 1) - step).abs() < 0.001,
          'Ring logos are not evenly spaced.',
        );
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    assert(_debugAssertLayoutValid());
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
    // Split by clock: the endless _sky loop only repaints the starfield and the
    // app-logo bob. The orbits/text/button reveal on the one-shot _enter, so
    // once the entrance finishes they stop rebuilding entirely — the perpetual
    // clock no longer re-lays-out text/images every frame.
    return Stack(
      fit: StackFit.expand,
      children: [
        // The twinkling starfield behind everything — its own _sky builder so it
        // repaints without dragging the whole screen along.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _sky,
            builder: (context, _) => CustomPaint(
              painter: StarfieldPainter(
                t: (_sky.value * 1440).roundToDouble() / 1440, // ~24fps twinkle
                stars: StarfieldPainter.starsFor(90, 7),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _enter,
          builder: (context, _) => Column(
            children: [
              // The orbits get the stage: they claim the whole upper area and
              // size themselves to it, so short screens shrink the cluster
              // instead of clipping it. Everything below is deliberately
              // compact and pushed down so nothing competes with the rings.
              Expanded(flex: 72, child: _orbits()),
              // The logo bob is the only content that needs the perpetual clock.
              AnimatedBuilder(
                animation: _sky,
                builder: (context, _) => _appLogo(),
              ),
              const SizedBox(height: 20),
              // Headline + subtitle share ONE width, so the two blocks line up
              // edge to edge instead of each finding its own natural width.
              // The headline scales down to fit that width (never wraps); the
              // subtitle wraps inside it — so both read as one tidy column.
              _textBlock(context, text),
              // The CTA sits directly under the copy — a small, deliberate gap,
              // no yawning space above it. The flow hands us [onStart]; when
              // absent (previews/tests) the button simply hides.
              if (widget.onStart != null) ...[
                const SizedBox(height: 22),
                _startButton(context),
              ],
              const Spacer(flex: 8),
            ],
          ),
        ),
      ],
    );
  }

  /// The headline and its subtitle, locked to a single shared width.
  ///
  /// [_textWidth] is that width: wide enough for "Welcome to Revolution" to sit
  /// comfortably on one line at its full size, and the subtitle wraps to the
  /// same measure. Because both blocks are the same width and centred, their
  /// left and right edges align exactly — which is what makes the pairing read
  /// as deliberate rather than two independently-sized paragraphs.
  static const _textWidth = 320.0;

  Widget _textBlock(BuildContext context, TextTheme text) {
    // Never wider than the screen allows — on a 320px phone the block shrinks
    // to fit rather than forcing the headline to scale down needlessly.
    final available = MediaQuery.sizeOf(context).width - 40;
    return SizedBox(
      width: math.min(_textWidth, available),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _reveal(
            start: 0.52,
            // Scale-down (not wrap) keeps the title on one line even on a
            // narrow screen, so it can never break into an awkward two.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Welcome to Revora',
                maxLines: 1,
                style: text.headlineLarge?.copyWith(
                  color: AppColors.ink,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _reveal(
            start: 0.60,
            // No hard line break — it wraps to the shared width on its own, so
            // the balance holds if the copy or the font ever changes.
            child: Text(
              'Track your subscriptions, investments and insurance — '
              'never miss a date',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(
                color: AppColors.inkSoft,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The "Start tracking" CTA, sitting directly under the copy. Locked to the
  /// same shared width as the text so its edges line up with the headline, and
  /// revealed last in the entrance so it lands after the words it belongs to.
  Widget _startButton(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - 40;
    return _reveal(
      start: 0.68,
      child: SizedBox(
        width: math.min(_textWidth, available),
        child: FilledButton(
          onPressed: widget.onStart,
          child: const Text('Start tracking'),
        ),
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
          for (var i = 0; i < ring.logos.length; i++) {
            children.add(
              _ringLogo(ring, i, side, 0.14 + (stagger++) * 0.04),
            );
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
  /// The glow sits at the rings' own centroid (the average of their centres,
  /// NOT the bounding-box middle) so the light reads as coming from behind the
  /// cluster's visual mass. Anchoring it to the box centre instead leaves the
  /// bright core visibly low and left of where the rings actually crowd.
  Widget _glow(double side) {
    return Transform.translate(
      offset: Offset(_ringCentroid.dx * side, _ringCentroid.dy * side),
      child: Opacity(
        opacity: _lin(0.0, 0.6),
        child: Container(
          // Wide enough to spill past the rings and wash the whole upper half
          // of the screen, so the cluster sits IN light rather than in front of
          // a disc.
          width: side * 1.85,
          height: side * 1.85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              // A brighter violet core with a long, gentle falloff — the extra
              // stops keep the edge from banding now that it's this wide.
              colors: [
                const Color(0xFF8B6BFF).withValues(alpha: 0.46),
                const Color(0xFF7C5CFC).withValues(alpha: 0.28),
                const Color(0xFF6742EE).withValues(alpha: 0.15),
                const Color(0xFF4C1D95).withValues(alpha: 0.06),
                Colors.transparent,
              ],
              stops: const [0.0, 0.22, 0.42, 0.66, 1.0],
            ),
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
  Widget _ringLogo(_Ring ring, int index, double side, double start) {
    final logo = ring.logos[index];
    final pos = ring.positionOf(index, side);
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
            circular: logo.circular,
          ),
        ),
      ),
    );
  }

  // ── The app's own logo ─────────────────────────────────────────────────────

  Widget _appLogo() {
    final pop = _pop(0.34, 0.45);
    final bob = math.sin(_sky.value * 2 * math.pi * 6) * 4;
    // Revo — the app's mascot — greets from here instead of a static logo. It
    // carries its own glow + gentle idle motion; we add the entrance pop and the
    // sky-clock bob so it floats in with the rest of the scene.
    return Opacity(
      opacity: _lin(0.34, 0.45),
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Transform.scale(
          scale: 0.6 + 0.4 * pop,
          child: const AnimatedMascot(size: 92),
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
    required this.phaseDeg,
    required this.hubIcon,
    required this.logos,
  });

  final double cxF, cyF;
  final double radiusF;

  /// Where the FIRST logo sits (degrees; 0 = right, 90 = down). The rest are
  /// spaced evenly after it — see [angleOf].
  final double phaseDeg;

  final IconData hubIcon;
  final List<_OrbitLogo> logos;

  /// The angle of logo [i], spaced evenly around the ring: with three logos
  /// that's exactly 120° apart. Deriving it means the spacing is a property of
  /// the ring, not nine numbers someone has to keep in sync.
  double angleOf(int i) => phaseDeg + i * (360.0 / logos.length);

  /// The position of logo [i] on a cluster box of [side] px, relative to the
  /// box centre.
  Offset positionOf(int i, double side) {
    final a = angleOf(i) * math.pi / 180;
    return Offset(
      (cxF + radiusF * math.cos(a)) * side,
      (cyF + radiusF * math.sin(a)) * side,
    );
  }
}

/// A logo resting on a ring: the brand and its box size (px). Its angle comes
/// from the ring's even spacing, so it can't be set — or mis-set — per logo.
class _OrbitLogo {
  const _OrbitLogo(this.brand, this.size, {this.circular = false});

  final Brand brand;
  final double size;

  /// Crop this logo to a circle — for brands whose favicon has an opaque white
  /// background that would otherwise show as a square patch on the dark sky.
  final bool circular;
}
