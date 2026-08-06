import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_quiz.dart';

/// Screen 3 — the payoff, told as BENEFITS, not money. For each area the user
/// picked, one short line on what they'd lose by forgetting it (life cover
/// lapsing, a silent renewal charging them…). Short text; big meaning. The
/// lines fade/slide in one by one.
class BenefitsScreen extends StatefulWidget {
  const BenefitsScreen({super.key, required this.picked});

  final Set<String> picked;

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// How many benefit lines we show before the list would run off-screen. All
  /// selected items are shown up to this; beyond it we add a quiet "& much more".
  static const _maxLines = 5;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant BenefitsScreen old) {
    super.didUpdateWidget(old);
    _c.forward(from: 0); // re-run the stagger if the picks changed
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<QuizOption> get _selected {
    final chosen =
        kQuizOptions.where((o) => widget.picked.contains(o.key)).toList();
    // Skipped the quiz → show a representative default set.
    return chosen.isNotEmpty ? chosen : kQuizOptions.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = _selected;
    // Show all selected benefits, but cap so the list never runs off-screen.
    // When capped, a quiet "& much more" sits just above the closing line.
    final visibleCount =
        items.length > _maxLines ? _maxLines : items.length;
    final overflowed = items.length > _maxLines;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'Here’s what Revolution\nkeeps safe for you.',
            style: text.displaySmall?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < visibleCount; i++)
            _BenefitLine(
              option: items[i],
              anim: _c,
              index: i,
              total: visibleCount,
            ),
          const Spacer(flex: 2),
          // "& much more" — quiet text, only when more were selected than shown.
          // Sits just above the closing line.
          if (overflowed)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                '& much more',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: AppColors.inkFaint,
                ),
              ),
            ),
          Text(
            'Miss one of these and it costs you. '
            'We make sure you never do.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({
    required this.option,
    required this.anim,
    required this.index,
    required this.total,
  });

  final QuizOption option;
  final Animation<double> anim;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final start = (index / (total + 1)).clamp(0.0, 0.85);
    final curved = CurvedAnimation(
      parent: anim,
      curve: Interval(start, 1, curve: Curves.easeOut),
    );
    final c = option.color;

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 12),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(option.icon, color: c, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: AppColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.benefit,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
