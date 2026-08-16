import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../tasks/data/task_store.dart';
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/glance_stats.dart';

/// The ★ GLANCE — a "what's coming up" agenda for the next 7 days: overdue items
/// pinned on top, then each day's reminders in order. Tap an item to mark it
/// done, right here. Live-updates with the store.
class GlanceView extends StatelessWidget {
  const GlanceView({
    super.key,
    required this.store,
    required this.progress,
    this.onOverdue,
  });

  final TaskStore store;

  /// 0→1 entrance progress (fades + rises the content in).
  final double progress;

  /// Tapping the overdue header runs this (e.g. show overdue details in chat).
  final VoidCallback? onOverdue;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final g = GlanceStats.from(store.tasks);
        final reveal = Curves.easeOut.transform(progress.clamp(0.0, 1.0));

        return Opacity(
          opacity: reveal,
          child: Transform.translate(
            offset: Offset(0, (1 - reveal) * 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: _content(context, g),
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, GlanceStats g) {
    if (g.isEmpty) return const _EmptyGlance();
    if (g.hasNothingSoon) return const _AllClear();

    final children = <Widget>[];

    // ── Overdue (urgent) — pinned on top when present ──
    if (g.overdue.isNotEmpty) {
      children.add(_SectionHeader(
        label: '${g.overdue.length} overdue',
        tint: const Color(0xFFFF6B6B),
        onTap: onOverdue,
      ));
      for (final t in g.overdue.take(4)) {
        children.add(_GlanceItem(
          task: t,
          overdue: true,
          onDone: () => store.toggleDone(t),
        ));
      }
      if (g.overdue.length > 4) {
        children.add(_MoreLine('+${g.overdue.length - 4} more overdue'));
      }
      children.add(const SizedBox(height: 14));
    }

    // ── The next 7 days, grouped by day ──
    for (final day in g.days) {
      children.add(_SectionHeader(label: _dayLabel(day.date)));
      for (final t in day.tasks) {
        children.add(_GlanceItem(
          task: t,
          onDone: () => store.toggleDone(t),
        ));
      }
      children.add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// A day / section header ("TODAY", "FRI 22 AUG", or the overdue banner).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.tint, this.onTap});
  final String label;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.inkFaint;
    final header = Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: color),
          ],
        ],
      ),
    );
    if (onTap == null) return header;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: header,
    );
  }
}

/// One reminder row in the agenda: a tappable check circle (mark done), the
/// category icon, the title, and a compact meta tail (time · amount).
class _GlanceItem extends StatelessWidget {
  const _GlanceItem({
    required this.task,
    required this.onDone,
    this.overdue = false,
  });
  final Task task;
  final VoidCallback onDone;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final meta = _meta(task, overdue: overdue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Tap the circle to mark done.
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onDone();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Icon(task.category.icon,
              size: 19,
              color: overdue
                  ? const Color(0xFFFF6B6B)
                  : AppColors.accent.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              meta,
              style: TextStyle(
                color: overdue
                    ? const Color(0xFFFF6B6B)
                    : AppColors.inkSoft.withValues(alpha: 0.95),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The tail: time (when set) · amount (when set). Overdue rows show how late.
  String _meta(Task t, {required bool overdue}) {
    final bits = <String>[];
    if (overdue && t.dueAt != null) {
      bits.add(_agoLabel(t.dueAt!));
    } else if (t.dueAt != null) {
      final hasTime = !(t.dueAt!.hour == 0 && t.dueAt!.minute == 0);
      if (hasTime) bits.add(_timeLabel(t.dueAt!));
    }
    if (t.hasAmount) bits.add(_money(t));
    return bits.join(' · ');
  }

  String _money(Task t) {
    final cur = currencyOf(t.currency);
    final a = t.amount!;
    final body = a == a.roundToDouble()
        ? formatAmount(a.round().toString(), cur.grouping)
        : a.toStringAsFixed(2);
    return '${cur.symbol}$body';
  }
}

class _MoreLine extends StatelessWidget {
  const _MoreLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 39, top: 2, bottom: 2),
      child: Text(text,
          style: TextStyle(
            color: AppColors.inkFaint,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

/// Nothing tracked at all.
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
          'Add your first reminder below and your week ahead will show up here.',
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

/// Tracked items exist, but nothing overdue and nothing in the next 7 days.
class _AllClear extends StatelessWidget {
  const _AllClear();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded,
                size: 24, color: AppColors.accent.withValues(alpha: 0.9)),
            const SizedBox(width: 10),
            const Text(
              "You're all clear",
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Nothing due in the next 7 days. Enjoy the calm.',
          style: TextStyle(
            color: AppColors.inkSoft.withValues(alpha: 0.9),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Date/time labels ─────────────────────────────────────────────────────────

const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
  'Oct', 'Nov', 'Dec'];
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Today" / "Tomorrow" / "Fri 22 Aug" — a day header.
String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) return _wd[d.weekday - 1];
  return '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';
}

/// "6 PM" / "6:30 PM" — the time tail.
String _timeLabel(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  return '$h$m $ampm';
}

/// "2 days ago" / "3 wks ago" — how overdue an item is.
String _agoLabel(DateTime due) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'due';
  if (days == 1) return '1 day ago';
  if (days < 14) return '$days days ago';
  if (days < 60) return '${(days / 7).round()} wks ago';
  return '${(days / 30).round()} mo ago';
}
