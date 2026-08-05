import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_quiz.dart';

/// Screen 3 — the payoff. A big animated ₹ number, personalised to the quiz
/// picks (sum of each option's typical yearly loss), then a short breakdown.
/// Minimal text; the number does the talking.
class BenefitsScreen extends StatefulWidget {
  const BenefitsScreen({super.key, required this.picked});

  final Set<String> picked;

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant BenefitsScreen old) {
    super.didUpdateWidget(old);
    // Re-run the count-up whenever the picks change (e.g. user goes back).
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<QuizOption> get _selected {
    final chosen =
        kQuizOptions.where((o) => widget.picked.contains(o.key)).toList();
    // If they skipped the quiz, show a representative default set.
    return chosen.isNotEmpty
        ? chosen
        : kQuizOptions.where((o) => o.annualSaving > 0).take(3).toList();
  }

  int get _total =>
      _selected.fold(0, (sum, o) => sum + o.annualSaving);

  String _inr(int v) {
    // Indian grouping: 1,20,000.
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final withMoney = _selected.where((o) => o.annualSaving > 0).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            'You could keep',
            style: text.titleMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          // The big animated number.
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final shown = (_c.value * _total).round();
              return Text(
                '₹${_inr(shown)}',
                style: text.displayLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 56,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'a year, roughly.',
            style: text.titleMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          // A short, calm breakdown of where it comes from.
          ...withMoney.map((o) => _BreakdownRow(option: o, inr: _inr)),
          const Spacer(flex: 2),
          Text(
            'Never a late fee, a lapse, or a silent renewal again.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.option, required this.inr});

  final QuizOption option;
  final String Function(int) inr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(option.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${option.label} · ${option.blurb}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '₹${inr(option.annualSaving)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: option.color,
            ),
          ),
        ],
      ),
    );
  }
}
