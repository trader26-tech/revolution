import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';

/// Screen 1 — what the app does, in one glance. A soft cluster of cards, each
/// with a *real* brand logo, gently animates in — showing the actual things the
/// app tracks. Then one bold line. Minimal text.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // The serious, money-relevant areas the app covers — insurance first, then
  // utilities, cards/banks, and investing. (Not a subscription tracker.)
  static const _brands = <_Item>[
    _Item(Brand(name: 'LIC', domain: 'licindia.in'), 'Life insurance'),
    _Item(Brand(name: 'Star Health', domain: 'starhealth.in'),
        'Health insurance'),
    _Item(Brand(name: 'Tata Power', domain: 'tatapower.com'),
        'Electricity bill'),
    _Item(Brand(name: 'HDFC Bank', domain: 'hdfcbank.com'), 'Card bill'),
    _Item(Brand(name: 'Zerodha', domain: 'zerodha.com'), 'SIP / stocks'),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SizedBox(height: 250, child: _Cluster(anim: _c, items: _brands)),
          const Spacer(),
          Text(
            'Everything you’d\nforget, remembered.',
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          Text(
            'Insurance, bills, EMIs, investments — '
            'one calm list, never a missed date.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _Item {
  const _Item(this.brand, this.label);
  final Brand brand;
  final String label;
}

/// A centred cluster: the first (priority — insurance) card sits big in the
/// middle; the rest are smaller logo pills tucked symmetrically around it, so
/// the logos are the hero and everything reads centred, not off in a corner.
class _Cluster extends StatelessWidget {
  const _Cluster({required this.anim, required this.items});
  final Animation<double> anim;
  final List<_Item> items;

  // Positions for the 4 satellite pills around the centre card (dx, dy, rot).
  static const _slots = <List<double>>[
    [-92, -58, -0.12],
    [92, -58, 0.12],
    [-92, 62, 0.10],
    [92, 62, -0.10],
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Center(
        child: SizedBox(
          width: 300,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Satellites first (behind), then the hero centre card on top.
              for (var i = 1; i < items.length; i++)
                _satellite(i, items[i], _slots[i - 1]),
              _hero(items.first),
            ],
          ),
        ),
      ),
    );
  }

  // The big, central, primary card — full logo + name + label.
  Widget _hero(_Item item) {
    final t = anim.value.clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(t);
    return Opacity(
      opacity: t,
      child: Transform.scale(
        scale: 0.7 + 0.3 * eased,
        child: Container(
          width: 176,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(brand: item.brand, size: 56, radius: 15),
              const SizedBox(height: 12),
              Text(
                item.brand.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A small logo pill orbiting the hero.
  Widget _satellite(int i, _Item item, List<double> slot) {
    final start = i * 0.1;
    final t = ((anim.value - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(t);
    return Transform.translate(
      offset: Offset(slot[0] * eased, slot[1] * eased),
      child: Transform.rotate(
        angle: slot[2] * eased,
        child: Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.5 + 0.5 * eased,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: BrandLogo(brand: item.brand, size: 38, radius: 11),
            ),
          ),
        ),
      ),
    );
  }
}
