import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart' show Grouping, formatAmount;
import '../../../tasks/data/task_store.dart';
import '../../../tasks/domain/category_visuals.dart';
import '../../domain/glance_stats.dart';

/// The GLANCE — the ★'s opening view: the user's money + reminders at a glance,
/// aggregated app-wide. A hero "monthly spend" figure, then compact rows for
/// what's overdue, due this week, and the next payment. Live-updates with the
/// store. Tapping "overdue" runs [onOverdue] (drops the details into the chat).
class GlanceView extends StatelessWidget {
  const GlanceView({
    super.key,
    required this.store,
    required this.progress,
    this.onOverdue,
  });

  final TaskStore store;

  /// 0→1 shimmer/entrance progress (fades the content in).
  final double progress;

  final VoidCallback? onOverdue;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final g = GlanceStats.from(store.tasks);
        final reveal = Curves.easeOut.transform(progress.clamp(0.0, 1.0));

        if (g.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
            child: Opacity(
              opacity: reveal,
              child: const _EmptyGlance(),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Opacity(
            opacity: reveal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero — monthly spend.
                _HeroSpend(monthlyInr: g.monthlyInr),
                const SizedBox(height: 16),
                // Overdue (only when there is any) — tappable for details.
                if (g.overdue.isNotEmpty)
                  _GlanceRow(
                    icon: Icons.error_outline_rounded,
                    tint: const Color(0xFFFF6B6B),
                    label: '${g.overdue.length} overdue',
                    trailing: 'Tap to see',
                    onTap: onOverdue,
                  ),
                // This week.
                _GlanceRow(
                  icon: Icons.event_rounded,
                  tint: AppColors.accent,
                  label: g.thisWeek.isEmpty
                      ? 'Nothing due this week'
                      : '${g.thisWeek.length} due this week',
                  trailing: g.thisWeekInr > 0 ? '₹${_grp(g.thisWeekInr)}' : null,
                ),
                // Next payment / reminder.
                if (g.nextTask != null)
                  _GlanceRow(
                    icon: g.nextTask!.category.icon,
                    tint: AppColors.accent,
                    label: g.nextTask!.title,
                    trailing: _nextTrailing(g),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _nextTrailing(GlanceStats g) {
    final bits = <String>[];
    if (g.nextTask!.hasAmount) {
      bits.add('₹${_grp(g.nextTask!.amount!)}');
    }
    if (g.nextDate != null) bits.add(_dateLabel(g.nextDate!));
    return bits.isEmpty ? null : bits.join(' · ');
  }
}

/// The hero monthly-spend figure.
class _HeroSpend extends StatelessWidget {
  const _HeroSpend({required this.monthlyInr});
  final double monthlyInr;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You spend about',
          style: TextStyle(
            color: AppColors.inkSoft.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '₹${_grp(monthlyInr)}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 40,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: '  / month',
                style: TextStyle(
                  color: AppColors.inkSoft.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One compact glance row — a tinted glyph, a label, an optional trailing value,
/// and (when tappable) a subtle press highlight.
class _GlanceRow extends StatelessWidget {
  const _GlanceRow({
    required this.icon,
    required this.tint,
    required this.label,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 21, color: tint),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(
              trailing!,
              style: TextStyle(
                color: AppColors.inkSoft.withValues(alpha: 0.95),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.inkFaint),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}

class _EmptyGlance extends StatelessWidget {
  const _EmptyGlance();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nothing tracked yet',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add your first reminder below and your spend, '
          'due dates, and next payment will show up here.',
          style: TextStyle(
            color: AppColors.inkSoft.withValues(alpha: 0.9),
            fontSize: 14.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Group a ₹ amount with Indian grouping (rounded to whole rupees for the glance).
String _grp(double amount) =>
    formatAmount(amount.round().toString(), Grouping.indian);

/// "Today" / "Tomorrow" / "Fri 22 Aug" — a compact date label.
String _dateLabel(DateTime d) {
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
    'Oct', 'Nov', 'Dec'];
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) return wd[day.weekday - 1];
  return '${wd[day.weekday - 1]} ${d.day} ${mo[d.month - 1]}';
}
