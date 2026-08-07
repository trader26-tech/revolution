import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';

/// Screen 1 — what the app does, in one glance.
///
/// Maximum logo, minimum text: big, bare app logos (no cards, no boxes) float
/// gently around the REAL app logo (bell + green tick). Below: one bold line
/// and the five category chips. That's it.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  /// One-shot entrance: app logo → brand logos → headline → chips.
  late final AnimationController _enter;

  /// Endless idle loop that keeps every logo drifting.
  late final AnimationController _float;

  // Big, instantly recognisable apps only — bare logos, no backing cards.
  // Birthdays get the cake emoji (no brand exists for that).
  static const _tiles = <_Tile>[
    // Subscriptions
    _Tile(
        brand: Brand(name: 'Netflix', domain: 'netflix.com'),
        size: 74, dx: -106, dy: -86, tilt: -0.08, phase: 0.0, speed: 1.0, amp: 7),
    _Tile(
        brand: Brand(name: 'Spotify', domain: 'spotify.com'),
        size: 62, dx: 6, dy: -132, tilt: 0.06, phase: 1.4, speed: 1.2, amp: 6),
    _Tile(
        brand: Brand(name: 'YouTube', domain: 'youtube.com'),
        size: 58, dx: 108, dy: -96, tilt: 0.10, phase: 2.6, speed: 0.9, amp: 7),
    // Insurance
    _Tile(
        brand: Brand(name: 'LIC', domain: 'licindia.in'),
        size: 60, dx: 134, dy: 4, tilt: -0.06, phase: 3.4, speed: 1.1, amp: 6),
    // Subscriptions
    _Tile(
        brand: Brand(name: 'Prime Video', domain: 'primevideo.com'),
        size: 52, dx: 104, dy: 100, tilt: 0.08, phase: 4.2, speed: 1.0, amp: 6),
    // Birthdays
    _Tile(
        emoji: '🎂',
        size: 64, dx: 0, dy: 134, tilt: 0.05, phase: 0.8, speed: 0.8, amp: 8),
    // SIP
    _Tile(
        brand: Brand(name: 'Groww', domain: 'groww.in'),
        size: 58, dx: -104, dy: 104, tilt: -0.10, phase: 5.0, speed: 1.3, amp: 6),
    _Tile(
        brand: Brand(name: 'Zerodha', domain: 'zerodha.com'),
        size: 64, dx: -134, dy: -2, tilt: 0.07, phase: 2.0, speed: 1.1, amp: 7),
  ];

  static const _categories = <(IconData, String)>[
    (Icons.autorenew_rounded, 'Subscriptions'),
    (Icons.cake_rounded, 'Birthdays'),
    (Icons.badge_rounded, 'Govt documents'),
    (Icons.trending_up_rounded, 'SIP'),
    (Icons.verified_user_rounded, 'Insurance'),
  ];

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
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
      animation: Listenable.merge([_enter, _float]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(flex: 5),
            SizedBox(height: 340, child: _cluster()),
            const SizedBox(height: 24),
            _reveal(
              start: 0.42,
              child: Text(
                'Never forget\nanything again.',
                textAlign: TextAlign.center,
                style: text.displaySmall?.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 20),
            _chips(),
            const Spacer(flex: 4),
          ],
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

  // ── The floating logo constellation ────────────────────────────────────────

  Widget _cluster() {
    return Center(
      child: SizedBox(
        width: 340,
        height: 340,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _glow(),
            for (var i = 0; i < _tiles.length; i++) _floatingTile(i),
            _appLogo(),
          ],
        ),
      ),
    );
  }

  /// A soft accent halo behind the whole cluster.
  Widget _glow() {
    return Opacity(
      opacity: _lin(0.0, 0.5),
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.10),
              AppColors.accent.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingTile(int i) {
    final tile = _tiles[i];
    final pop = _pop(0.10 + i * 0.055);
    final fade = _lin(0.10 + i * 0.055);
    // Idle bob: every logo drifts on its own phase + speed, so the cluster
    // feels alive but never busy.
    final bob = math.sin(
          _float.value * 2 * math.pi * tile.speed + tile.phase,
        ) *
        tile.amp;
    return Transform.translate(
      offset: Offset(tile.dx * pop, tile.dy * pop + bob * fade),
      child: Transform.rotate(
        angle: tile.tilt * pop,
        child: Opacity(
          opacity: fade,
          child: Transform.scale(scale: 0.4 + 0.6 * pop, child: _logo(tile)),
        ),
      ),
    );
  }

  /// The logo itself — big and bare. No card, no border, no backing box; real
  /// brand marks rounded like app icons, emoji drawn straight on the page.
  Widget _logo(_Tile tile) {
    if (tile.brand != null) {
      return BrandLogo(
        brand: tile.brand!,
        size: tile.size,
        radius: tile.size * 0.24,
        bare: true,
      );
    }
    return Text(
      tile.emoji!,
      style: TextStyle(fontSize: tile.size * 0.86, height: 1.0),
    );
  }

  /// The centre: the REAL app logo (blue bell + green tick), swinging ever so
  /// slightly — exactly the icon on the user's home screen.
  Widget _appLogo() {
    final pop = _pop(0.0, 0.45);
    final fade = _lin(0.0, 0.45);
    final swing = math.sin(_float.value * 2 * math.pi) * 0.04 * fade;
    return Opacity(
      opacity: fade,
      child: Transform.rotate(
        angle: swing,
        child: Transform.scale(
          scale: 0.5 + 0.5 * pop,
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
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

  // ── The five category chips — the only other text on the page ─────────────

  Widget _chips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _categories.length; i++)
          _reveal(
            start: 0.56 + i * 0.05,
            child: _chip(_categories[i].$1, _categories[i].$2),
          ),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// One floating logo: a real brand (or an emoji for the brandless categories),
/// its resting position, static tilt, and the phase / speed / amplitude of its
/// idle bob.
class _Tile {
  const _Tile({
    this.brand,
    this.emoji,
    required this.size,
    required this.dx,
    required this.dy,
    required this.tilt,
    required this.phase,
    required this.speed,
    required this.amp,
  }) : assert(brand != null || emoji != null);

  final Brand? brand;
  final String? emoji;
  final double size;
  final double dx, dy;
  final double tilt;
  final double phase, speed, amp;
}
