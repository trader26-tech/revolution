import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/data/brand_catalog.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../details/domain/currency.dart';
import '../../domain/task.dart';
import 'animated_check_circle.dart';

/// A single task in the home list.
///
/// Layout, left → right: the **brand logo**, the title + due-date subtitle, the
/// debited **amount**, then the **checkbox** that toggles done. Interaction:
///  * Tap the **row body** → open the details page to update it.
///  * **Long-press** the row → it expands downward to reveal a subtle Delete
///    action. Tap the row (or long-press again) to collapse. Fully reversible.
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpenDetails,
    required this.onDelete,
    this.occurrenceDate,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onOpenDetails;
  final VoidCallback onDelete;

  /// For a recurring task shown in the monthly agenda, the specific date of THIS
  /// occurrence — so the subtitle reads e.g. "Sep 1" in September, not the
  /// task's original due date. Null → use the task's own [Task.dueAt].
  final DateTime? occurrenceDate;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool _open = false;

  static const _dur = Duration(milliseconds: 240);
  static const _curve = Curves.easeOutCubic;

  void _toggleOpen() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return InkWell(
      // Tap the row → open details. Long-press → reveal the Delete section.
      // (When it's open, a tap closes it.)
      onTap: _open ? _toggleOpen : widget.onOpenDetails,
      onLongPress: _toggleOpen,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: task.done ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              // A single, consistent 20px inset — the list itself has no side
              // padding, so the row spreads across the FULL width (no more
              // double-inset squishing everything into the middle).
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Brand logo on the LEFT — falls back to a filled letter tile.
                  BrandLogo(brand: _brandOf(task), size: 44, radius: 12),
                  const SizedBox(width: 14),
                  // Title + date in the middle.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                task.done ? AppColors.inkFaint : AppColors.ink,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.inkFaint,
                          ),
                          child:
                              Text(task.title, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(height: 3),
                        _DueLine(text: _subtitle(task), scheduled: task.isScheduled),
                      ],
                    ),
                  ),
                  // Amount — money going out, shown as −₹1,000.
                  if (task.hasAmount) ...[
                    const SizedBox(width: 12),
                    _AmountLabel(amount: task.amount!, currencyCode: task.currency),
                  ],
                  // Checkbox on the RIGHT, after the amount — toggles done.
                  const SizedBox(width: 12),
                  AnimatedCheckCircle(
                    checked: task.done,
                    onTap: widget.onToggle,
                    size: 24,
                  ),
                ],
              ),
            ),
              // The subtle drop-down section — a single quiet Delete action,
              // revealed on long-press.
            AnimatedSize(
              duration: _dur,
              curve: _curve,
              alignment: Alignment.topCenter,
              child: _open
                  ? _DeleteSection(onDelete: widget.onDelete)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Task task) {
    if (!task.isScheduled) return 'Tap to set a date';
    final due = task.dueAt!;
    // Show THIS occurrence's date (agenda) or the task's own date. Date only —
    // no time, since the user only picks a date.
    final od = widget.occurrenceDate;
    final d = od == null ? due : DateTime(od.year, od.month, od.day);
    // "Today", "Tomorrow", "Mon, 12 Aug" — the date, no time.
    final base = _relativeDay(d);
    if (task.repeat != RepeatCadence.none) {
      return '$base · ${task.repeat.label}';
    }
    return base;
  }

  /// A human day label relative to today.
  static String _relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff < 7) return _weekdays[d.weekday - 1]; // this week
    if (diff < 0 && diff > -7) return '${-diff} days ago';
    // Otherwise a compact date; include the year only if it's not this year.
    final base = '${_weekdays[d.weekday - 1].substring(0, 3)}, ${d.day} ${_months[d.month - 1]}';
    return d.year == now.year ? base : '$base ${d.year}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  /// Build a Brand for the task's logo. If the task has a saved domain, use it
  /// directly; otherwise re-resolve the name (which also checks curated/custom
  /// logos), so bucket logos and aliases show correctly.
  Brand _brandOf(Task t) {
    final name = (t.iconName?.isNotEmpty ?? false) ? t.iconName! : t.title;
    final domain = t.iconDomain ?? '';
    if (domain.isNotEmpty) return Brand(name: name, domain: domain);
    return BrandCatalog.resolve(name);
  }
}

/// The amount on the right of a task, with an explicit SIGN so the money
/// direction is unmistakable:
///   • money going OUT (the usual case) → red  "−₹1,000"
///   • money coming IN / an increment    → green "+₹1,000"
/// The sign follows the amount: a negative amount is income (+), a positive
/// amount is an outgoing payment (−). Most tasks are outgoing.
class _AmountLabel extends StatelessWidget {
  const _AmountLabel({required this.amount, required this.currencyCode});

  final double amount;
  final String currencyCode;

  static const _out = Color(0xFFDC2626); // red  = money leaving
  static const _in = Color(0xFF059669); // green = money arriving

  @override
  Widget build(BuildContext context) {
    final c = currencyOf(currencyCode);
    // A negative stored amount = income (+); otherwise it's an outgoing payment (−).
    final isIncome = amount < 0;
    final sign = isIncome ? '+' : '−';
    final color = isIncome ? _in : _out;

    final grouped = groupDigits(
      amount.truncate().abs().toString(),
      c.grouping,
    );
    // Show paise/cents only when they're non-zero.
    final frac = amount.abs() - amount.abs().truncate();
    final decimals = frac == 0
        ? ''
        : '.${(frac * 100).round().toString().padLeft(2, '0')}';
    return Text(
      '$sign${c.symbol}$grouped$decimals',
      maxLines: 1,
      style: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// The due date/time line under a task — a small clock icon + calm text.
class _DueLine extends StatelessWidget {
  const _DueLine({required this.text, required this.scheduled});

  final String text;
  final bool scheduled;

  @override
  Widget build(BuildContext context) {
    // Scheduled tasks show their date in the accent blue so "Today / Sat / …"
    // pops; undated tasks stay a quiet grey prompt.
    final color = scheduled ? AppColors.accent : AppColors.inkFaint;
    return Row(
      children: [
        Icon(
          scheduled ? Icons.schedule_rounded : Icons.event_note_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: color,
              fontWeight: scheduled ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The subtle drop-down section under a task when its chevron is open. A quiet
/// hairline, then a single understated Delete action — nothing shouty.
class _DeleteSection extends StatelessWidget {
  const _DeleteSection({required this.onDelete});

  final VoidCallback onDelete;

  static const _red = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          indent: 20,
          endIndent: 20,
          color: AppColors.hairline,
        ),
        InkWell(
          onTap: onDelete,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 19, color: _red),
                SizedBox(width: 10),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: _red,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
