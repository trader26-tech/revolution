import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';

/// Screen 1 — what the app does, in one glance.
///
/// A constellation of *real* app logos — the things people forget to pay,
/// renew and remember — floats gently around a reminder bell. Everything pops
/// in with a soft stagger, then keeps drifting on a slow idle loop. Below it:
/// one bold promise and the five categories the app covers.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  /// One-shot entrance: bell → logo tiles → headline → chips → badge.
  late final AnimationController _enter;

  /// Endless idle loop that makes the tiles bob and the bell swing.
  late final AnimationController _float;

  // The five categories, each represented by the apps people actually know.
  // Birthdays and documents have no "brand", so they get emoji tiles that sit
  // naturally next to the real logos.
  static const _tiles = <_Tile>[
    // Subscriptions
    _Tile(
        brand: Brand(name: 'Netflix', domain: 'netflix.com'),
        size: 60, dx: -108, dy: -62, tilt: -0.10, phase: 0.0, speed: 1.0, amp: 6),
    _Tile(
        brand: Brand(name: 'Spotify', domain: 'spotify.com'),
        size: 52, dx: -6, dy: -116, tilt: 0.08, phase: 1.4, speed: 1.2, amp: 5),
    _Tile(
        brand: Brand(name: 'Hotstar', domain: 'hotstar.com'),
        size: 46, dx: 92, dy: -88, tilt: 0.12, phase: 2.6, speed: 0.9, amp: 7),
    // Insurance
    _Tile(
        brand: Brand(name: 'LIC', domain: 'licindia.in'),
        size: 58, dx: 118, dy: -6, tilt: -0.08, phase: 3.4, speed: 1.1, amp: 5),
    // SIP
    _Tile(
        brand: Brand(name: 'Zerodha', domain: 'zerodha.com'),
        size: 50, dx: 98, dy: 74, tilt: 0.10, phase: 4.2, speed: 1.0, amp: 6),
    _Tile(
        brand: Brand(name: 'Groww', domain: 'groww.in'),
        size: 46, dx: -88, dy: 92, tilt: -0.12, phase: 5.0, speed: 1.3, amp: 5),
    // Birthdays
    _Tile(
        emoji: '🎂',
        size: 54, dx: 10, dy: 112, tilt: 0.06, phase: 0.8, speed: 0.8, amp: 7),
    // Government documents
    _Tile(
        brand: Brand(name: 'DigiLocker', domain: 'digilocker.gov.in'),
        size: 48, dx: -124, dy: 22, tilt: 0.09, phase: 2.0, speed: 1.1, amp: 6),
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
            SizedBox(height: 300, child: _cluster()),
            const SizedBox(height: 18),
            _reveal(
              start: 0.42,
              child: Text(
                'Never forget\nanything again.',
                textAlign: TextAlign.center,
                style: text.displaySmall?.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 12),
            _reveal(
              start: 0.50,
              child: Text(
                'The dates that slip your mind — remembered\nfor you, reminded before they’re due.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
              ),
            ),
            const SizedBox(height: 22),
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
        width: 320,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _glow(),
            for (var i = 0; i < _tiles.length; i++) _floatingTile(i),
            _bell(),
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
        width: 280,
        height: 280,
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
    // Idle bob: every tile drifts on its own phase + speed, so the cluster
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
          child: Transform.scale(scale: 0.4 + 0.6 * pop, child: _tileBox(tile)),
        ),
      ),
    );
  }

  /// An app-icon style squircle: real logo, or an emoji for the brandless
  /// categories (birthdays, documents).
  Widget _tileBox(_Tile tile) {
    return Container(
      width: tile.size,
      height: tile.size,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(tile.size * 0.30),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: tile.brand != null
          ? BrandLogo(
              brand: tile.brand!,
              size: tile.size * 0.62,
              radius: tile.size * 0.16,
            )
          : Text(tile.emoji!, style: TextStyle(fontSize: tile.size * 0.48)),
    );
  }

  /// The centre bell — the app itself — with a slow, subtle swing and a badge
  /// that pops in last (five categories, five things it never forgets).
  Widget _bell() {
    final pop = _pop(0.0, 0.45);
    final fade = _lin(0.0, 0.45);
    final swing = math.sin(_float.value * 2 * math.pi) * 0.05 * fade;
    final badge = Curves.elasticOut.transform(_lin(0.78, 0.22));
    return Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: 0.5 + 0.5 * pop,
        child: SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 8,
                bottom: 8,
                left: 8,
                right: 8,
                child: Transform.rotate(
                  angle: swing,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.accent, AppColors.accentDeep],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.38),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
              // Notification badge — "5", one per category.
              Positioned(
                top: 0,
                right: 0,
                child: Transform.scale(
                  scale: badge,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2.5),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '5',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── The five category chips ────────────────────────────────────────────────

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

/// One tile in the constellation: a real brand logo (or an emoji for the
/// brandless categories), its resting position, static tilt, and the phase /
/// speed / amplitude of its idle bob.
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
