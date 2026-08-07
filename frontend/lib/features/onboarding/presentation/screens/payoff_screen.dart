import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_quiz.dart';

/// Screen 3 — the payoff, as one unforgettable number.
///
/// Every area the user picked recurs on its own clock (bills monthly, PUC
/// twice a year…). We multiply each pick by how often it fires and count the
/// total up LIVE: each category chip ticks in as its share joins the sum, so
/// the user watches "Bills ×36, EMIs ×24…" pile up into "147 reminders a
/// year." Then the landing: don't worry — Revolution has got you covered.
class PayoffScreen extends StatefulWidget {
  const PayoffScreen({super.key, required this.picked});

  final Set<String> picked;

  @override
  State<PayoffScreen> createState() => _PayoffScreenState();
}

class _PayoffScreenState extends State<PayoffScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Timeline: headline first, then the chips tick in across the count window
  // (the number climbing with them), a settle-pop, and finally the promise.
  static const _countStart = 0.10;
  static const _countEnd = 0.68;
  static const _cardStart = 0.80;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _duration)..forward();
  }

  @override
  void didUpdateWidget(covariant PayoffScreen old) {
    super.didUpdateWidget(old);
    // The parent rebuilds when the user lands on this page (and when picks
    // change) — replay so arriving always shows the count-up.
    _c
      ..duration = _duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<QuizOption> get _selected {
    final chosen =
        kQuizOptions.where((o) => widget.picked.contains(o.key)).toList();
    // Skipped the quiz → count just the near-universal basics.
    return chosen.isNotEmpty ? chosen : kQuizOptions.take(4).toList();
  }

  /// Longer lists get a touch more time so every chip still reads.
  Duration get _duration =>
      Duration(milliseconds: 1100 + 170 * _selected.length);

  /// Eased progress of chip [i]'s slice of the count-up window.
  double _chipT(int i, int n) {
    final span = (_countEnd - _countStart) / n;
    final t = ((_c.value - (_countStart + span * i)) / span).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  /// Fade + slide-up reveal for a slice of the timeline.
  Widget _reveal(double start, Widget child, {double window = 0.20}) {
    final t = Curves.easeOutCubic
        .transform(((_c.value - start) / window).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = _selected;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // The running total: each area's yearly count joins the sum as its
        // chip ticks in — the multiplication happens before the user's eyes.
        var running = 0.0;
        for (var i = 0; i < items.length; i++) {
          running += items[i].perYear * _chipT(i, items.length);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _reveal(
                0.0,
                Text(
                  "That's",
                  style: text.headlineSmall?.copyWith(color: AppColors.inkSoft),
                ),
              ),
              _bigNumber(running.round()),
              _reveal(
                0.04,
                Text(
                  'reminders a year.',
                  style: text.headlineMedium?.copyWith(color: AppColors.ink),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _chip(items[i], _chipT(i, items.length)),
                ],
              ),
              if (widget.picked.isEmpty) ...[
                const SizedBox(height: 14),
                _reveal(
                  _countEnd,
                  const Text(
                    'Just the everyday basics — most people juggle more.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ),
              ],
              const Spacer(flex: 2),
              _promiseCard(),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  // ── The number — the whole point of the page ───────────────────────────────

  Widget _bigNumber(int value) {
    // A quick settle-pop the moment the count completes.
    final settle = ((_c.value - _countEnd) / 0.10).clamp(0.0, 1.0);
    final pop = math.sin(settle * math.pi) * 0.05;
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Soft accent halo so the number glows off the page.
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.12),
                  AppColors.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Transform.scale(
            scale: 1 + pop,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.accent, AppColors.accentDeep],
                ).createShader(r),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -4,
                    height: 1.0,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── One category's share: "Bills ×36" ──────────────────────────────────────

  Widget _chip(QuizOption o, double t) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - t)),
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: o.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: o.color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(o.icon, size: 14, color: o.color),
                const SizedBox(width: 6),
                Text(
                  o.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '×${o.perYear}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: o.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── The landing: the promise ───────────────────────────────────────────────

  Widget _promiseCard() {
    final t = Curves.easeOutCubic
        .transform(((_c.value - _cardStart) / (1 - _cardStart)).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - t)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Don't worry — Revolution has got you covered.",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'The right nudge at the right moment. Every single time.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
