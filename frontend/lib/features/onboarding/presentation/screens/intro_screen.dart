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

  // A rich, varied deck so the fan fills the width and layers behind the
  // headline. Categories repeat across brands (Loan EMI from several banks) so
  // it feels real. The LAST item is the centre hero (on top, fully visible).
  static const _brands = <_Item>[
    // Loan EMI — multiple banks.
    _Item('Loan EMI', Brand(name: 'ICICI Bank', domain: 'icicibank.com'), 15200),
    _Item('Loan EMI', Brand(name: 'Axis Bank', domain: 'axisbank.com'), 9800),
    // Insurance.
    _Item('Life insurance', Brand(name: 'LIC', domain: 'licindia.in'), 2400),
    _Item('Health cover',
        Brand(name: 'Star Health', domain: 'starhealth.in'), 18000),
    // Bills.
    _Item('Electricity',
        Brand(name: 'Tata Power', domain: 'tatapower.com'), 1860),
    _Item('Mobile bill', Brand(name: 'Airtel', domain: 'airtel.in'), 799),
    // Investing.
    _Item('SIP', Brand(name: 'Zerodha', domain: 'zerodha.com'), 5000),
    _Item('SIP', Brand(name: 'Groww', domain: 'groww.in'), 3000),
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
    return Column(
      children: [
        const Spacer(flex: 3),
        // Full-width so the wide fan can spread across and layer behind the text.
        SizedBox(height: 250, child: _Cluster(anim: _c, items: _brands)),
        // Small gap so the fanned cards sit right on top of the headline.
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
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

  // Positions/rotations (dx, dy, rot) for a full, wide fan that fills the width
  // and layers behind the headline. Order = paint order (earliest at the back);
  // the LAST entry is the centred hero on top. Outer cards sit wider + lower so
  // the stack reaches down onto the text.
  static const _slots = <List<double>>[
    [-118, -18, -0.20], // far left, back
    [118, -12, 0.20], // far right, back
    [-92, 44, -0.13], // left
    [92, 48, 0.13], // right
    [-46, -46, -0.08], // upper-left
    [50, -44, 0.08], // upper-right
    [-40, 78, 0.06], // lower-left, reaches down
    [44, 80, -0.06], // lower-right, reaches down
    [0, 12, 0.0], // centre, on top
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Center(
        child: SizedBox(
          width: 360,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
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
    // Stagger across the whole deck so every card animates in (max start 0.5).
    final start = (i / items.length) * 0.5;
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

/// A bill card: a BOLD category header on top ("LOAN EMI"), then just the logo
/// and the amount due — no brand name (the logo already says who). Big enough
/// that the fanned cards overlap each other and the headline below.
class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.item, required this.center});
  final _Item item;
  final bool center;

  static const _due = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: center ? 184 : 170,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: center ? 0.16 : 0.10),
            blurRadius: center ? 30 : 24,
            offset: Offset(0, center ? 14 : 11),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bold category header.
          Text(
            item.category.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          // Logo + amount — no brand name.
          Row(
            children: [
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
              const Spacer(),
              Text(
                '−₹${_inr(item.amount)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _due,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
