import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';

/// Screen 1 — what the app does, in one glance. A soft fan of cards, each with a
/// *real* brand logo, gently animates in — showing the actual, actionable
/// things the app tracks. Then one bold line. Minimal text.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Money-serious, actionable areas — the ones that cost you if you forget.
  // The LAST item is the centre card (on top, fully visible), so it leads with
  // an EMI / loan payment. The rest fan out around it, half-covered.
  static const _brands = <_Item>[
    _Item(Brand(name: 'LIC', domain: 'licindia.in'), 'Life insurance'),
    _Item(Brand(name: 'Star Health', domain: 'starhealth.in'), 'Health cover'),
    _Item(Brand(name: 'Tata Power', domain: 'tatapower.com'), 'Electricity'),
    _Item(Brand(name: 'Zerodha', domain: 'zerodha.com'), 'SIP / stocks'),
    // Centre, on top — the actionable hero: a loan / card EMI.
    _Item(Brand(name: 'HDFC Bank', domain: 'hdfcbank.com'), 'Loan EMI'),
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

/// The fan cluster: five logo cards fan out from the centre, each with a slight
/// offset + rotation, staggered in. The last card sits centred and on top.
class _Cluster extends StatelessWidget {
  const _Cluster({required this.anim, required this.items});
  final Animation<double> anim;
  final List<_Item> items;

  // Fixed positions/rotations for a pleasant, deliberate scatter (dx, dy, rot).
  // The 5th entry is the centred hero card.
  static const _slots = <List<double>>[
    [-84, -34, -0.14],
    [86, -20, 0.12],
    [-58, 66, 0.10],
    [70, 74, -0.10],
    [0, 4, 0.0], // centre, on top
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Center(
        child: SizedBox(
          width: 280,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < items.length; i++)
                _card(i, items[i], _slots[i], center: i == items.length - 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(int i, _Item item, List<double> slot, {required bool center}) {
    final start = i * 0.12;
    final t = ((anim.value - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(t);
    return Transform.translate(
      offset: Offset(slot[0] * eased, slot[1] * eased),
      child: Transform.rotate(
        angle: slot[2] * eased,
        child: Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.6 + 0.4 * eased,
            child: _LogoCard(item: item, center: center),
          ),
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.item, required this.center});
  final _Item item;
  final bool center;

  @override
  Widget build(BuildContext context) {
    // The centre card is a touch larger and lifts higher, so it clearly reads
    // as the hero; the logo sits in a padded rounded tile so it never looks
    // cropped or misplaced.
    return Container(
      width: center ? 164 : 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: center ? 0.14 : 0.08),
            blurRadius: center ? 28 : 22,
            offset: Offset(0, center ? 12 : 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // A neutral tile behind the logo keeps every brand mark centred and
          // consistently sized — fixes the "misplaced logo" on the centre card.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: BrandLogo(brand: item.brand, size: 30, radius: 8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.brand.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
