import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../domain/task.dart';
import 'animated_check_circle.dart';

/// A single task in the home list.
///
/// Layout: the **logo on the left** (a coloured letter-avatar when the task has
/// no real logo), the title + due-date subtitle, and a **checkbox on the right**
/// that toggles done. Interaction:
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                  children: [
                  // Left icon: the real brand logo when the task has one,
                  // otherwise a clean on-brand blue tile (not a random letter).
                  _LeadingIcon(task: task),
                  const SizedBox(width: 14),
                  // Title + subtitle.
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
                  const SizedBox(width: 12),
                  // The checkbox on the right — toggles done.
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
    // Show THIS occurrence's date (agenda) but keep the task's time-of-day.
    final od = widget.occurrenceDate;
    final d = od == null
        ? due
        : DateTime(od.year, od.month, od.day, due.hour, due.minute);
    // "Today · 1:50 PM", "Tomorrow · 9 AM", "Mon, 12 Aug · 9 AM" — friendly and
    // readable, not a stiff "Aug 12, 2026 · 01:50 PM".
    final base = '${_relativeDay(d)} · ${_time(d)}';
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

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    // Drop ":00" for on-the-hour times → "9 AM" reads cleaner than "9:00 AM".
    if (d.minute == 0) return '$h $ampm';
    return '$h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
}

/// The due date/time line under a task — a small clock icon + calm text, so it
/// reads clearly without the harsh blue.
/// The tile's leading icon. A real brand logo when the task has a domain;
/// otherwise a clean blue tile with a bell (on-brand, matches the app icon) —
/// never a random letter avatar.
class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final hasLogo = task.iconDomain != null && task.iconDomain!.isNotEmpty;
    if (hasLogo) {
      return BrandLogo(
        brand: Brand(
          name: task.iconName?.isNotEmpty == true ? task.iconName! : task.title,
          domain: task.iconDomain!,
        ),
        size: 40,
        radius: 11,
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(
        Icons.notifications_rounded,
        color: AppColors.accent,
        size: 22,
      ),
    );
  }
}

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
          indent: 16,
          endIndent: 16,
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
