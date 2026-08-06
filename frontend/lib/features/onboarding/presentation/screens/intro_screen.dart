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

  // Each card: a CATEGORY header on top, then logo + payee + amount due below.
  // The LAST item is the centre hero (on top, fully visible); the rest fan out,
  // half-covered.
  static const _brands = <_Item>[
    _Item('Life insurance', Brand(name: 'LIC', domain: 'licindia.in'), 2400),
    _Item('Health cover',
        Brand(name: 'Star Health', domain: 'starhealth.in'), 18000),
    _Item('Electricity',
        Brand(name: 'Tata Power', domain: 'tatapower.com'), 1860),
    _Item('SIP', Brand(name: 'Zerodha', domain: 'zerodha.com'), 5000),
    // Centre, on top — the actionable hero.
    _Item('Loan EMI', Brand(name: 'HDFC Bank', domain: 'hdfcbank.com'), 24500),
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
          SizedBox(height: 262, child: _Cluster(anim: _c, items: _brands)),
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
  const _Item(this.category, this.brand, this.amount);

  /// The category header at the top of the card (e.g. "Loan EMI").
  final String category;
  final Brand brand;

  /// Amount due (₹) — shown as a red "−₹x,xxx".
  final int amount;
}

/// Indian grouping: 24500 → 24,500 · 120000 → 1,20,000.
String _inr(int v) {
  final s = v.toString();
  if (s.length <= 3) return s;
  final head = s.substring(0, s.length - 3);
  final tail = s.substring(s.length - 3);
  final buf = StringBuffer();
  for (var i = 0; i < head.length; i++) {
    if (i != 0 && (head.length - i) % 2 == 0) buf.write(',');
    buf.write(head[i]);
  }
  return '${buf.toString()},$tail';
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

/// A compact bill card: a small CATEGORY header on top ("Loan EMI"), then a row
/// of logo + payee + amount due. Same footprint as the version that lightly
/// overlapped the headline.
class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.item, required this.center});
  final _Item item;
  final bool center;

  static const _due = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: center ? 164 : 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header.
          Text(
            item.category.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.inkFaint,
            ),
          ),
          const SizedBox(height: 8),
          // Logo + payee.
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: BrandLogo(brand: item.brand, size: 22, radius: 6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.brand.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Amount due — on its own line so nothing truncates on narrow cards.
          Text(
            '−₹${_inr(item.amount)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _due,
            ),
          ),
        ],
      ),
    );
  }
}
