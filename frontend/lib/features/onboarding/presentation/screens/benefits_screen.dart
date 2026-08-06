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

  /// How many benefits to show before collapsing the rest behind "& N more".
  static const _previewCount = 2;
  bool _expanded = false;

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
    _expanded = false;
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
    // The user shouldn't have to read a long list — show the top few, tuck the
    // rest behind a "& N more" that reveals them on tap.
    final hasMore = items.length > _previewCount;
    final visibleCount =
        _expanded || !hasMore ? items.length : _previewCount;
    final remaining = items.length - _previewCount;

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
          if (hasMore && !_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 46),
              child: _MorePill(
                count: remaining,
                onTap: () => setState(() => _expanded = true),
              ),
            ),
          const Spacer(flex: 2),
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

/// A subtle "& N more" pill that reveals the rest of the benefits on tap.
class _MorePill extends StatelessWidget {
  const _MorePill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '& $count more',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accentDeep,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 18, color: AppColors.accentDeep),
          ],
        ),
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
