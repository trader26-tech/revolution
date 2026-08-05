import 'package:flutter/material.dart';

import '../../../reminders/domain/catalog.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../reminders/domain/scheduling.dart';
import '../onboarding_controller.dart';

/// The payoff. The moment the user feels "yes, I need this."
///
/// Two beats:
///   1. A number counts up — "I'll watch N things for you" — so the value is
///      felt as a quantity, instantly.
///   2. Those N things unfold as a personalised 12-month timeline, nearest
///      first, each with the real prefilled due date. Nothing was typed; it's
///      all already there.
class RevealStep extends StatefulWidget {
  const RevealStep({
    super.key,
    required this.controller,
    required this.onFinish,
    this.busy = false,
  });

  final OnboardingController controller;
  final VoidCallback onFinish;
  final bool busy;

  @override
  State<RevealStep> createState() => _RevealStepState();
}

class _RevealStepState extends State<RevealStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final List<_RevealEntry> _entries;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _entries = widget.controller.resolvedItems
        .map((item) => _RevealEntry(
              item: item,
              draft: Scheduling.draftFor(item, from: now),
            ))
        .toList()
      ..sort((a, b) => a.draft.expiryDate.compareTo(b.draft.expiryDate));

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  int get _count => _entries.length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Beat 1: the count-up headline.
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final shown = (_anim.value * _count).round().clamp(0, _count);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    '$shown',
                    style: text.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shown == 1
                        ? 'thing I’ll never let you forget'
                        : 'things I’ll never let you forget',
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All set up for you — no typing. '
                    'Here’s your next 12 months.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Beat 2: the timeline, items fading/sliding in one after another.
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            itemCount: _entries.length,
            itemBuilder: (context, i) {
              return _TimelineRow(
                entry: _entries[i],
                isFirst: i == 0,
                isLast: i == _entries.length - 1,
                anim: _anim,
                order: i,
                total: _entries.length,
              );
            },
          ),
        ),
        _FinishFooter(busy: widget.busy, onFinish: widget.onFinish),
      ],
    );
  }
}

class _RevealEntry {
  _RevealEntry({required this.item, required this.draft});
  final CatalogItem item;
  final ReminderDraft draft;
}

/// A single timeline row with a connector rail, a coloured node, and the item.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.anim,
    required this.order,
    required this.total,
  });

  final _RevealEntry entry;
  final bool isFirst;
  final bool isLast;
  final Animation<double> anim;
  final int order;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = kCategoryByItemKey[entry.item.key];
    final color = category?.color ?? scheme.primary;
    final months = _monthsAway(entry.draft.expiryDate);

    // Stagger: each row appears slightly after the previous one.
    final start = (order / (total + 2)).clamp(0.0, 0.9);
    final curved = CurvedAnimation(
      parent: anim,
      curve: Interval(start, 1, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 16),
            child: child,
          ),
        );
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Rail(color: color, isFirst: isFirst, isLast: isLast),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? color.withValues(alpha: 0.12)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFirst
                          ? color.withValues(alpha: 0.5)
                          : scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(entry.item.icon, color: color, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              months,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (isFirst)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'FIRST UP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthsAway(DateTime due) {
    final now = DateTime.now();
    final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days <= 0) return 'Due now';
    if (days < 14) return 'In $days days';
    if (days < 60) return 'In ${(days / 7).round()} weeks';
    final months = (days / 30).round();
    return 'In $months months';
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.color, required this.isFirst, required this.isLast});

  final Color color;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final track = color.withValues(alpha: 0.25);
    return SizedBox(
      width: 20,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 2,
              color: isFirst ? Colors.transparent : track,
            ),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 3),
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              color: isLast ? Colors.transparent : track,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishFooter extends StatelessWidget {
  const _FinishFooter({required this.busy, required this.onFinish});

  final bool busy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: busy ? null : onFinish,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text('Start tracking these'),
        ),
      ),
    );
  }
}
