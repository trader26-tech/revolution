import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../family/domain/family_member.dart';
import '../../domain/catalog.dart';
import '../../domain/reminder.dart';

/// A single reminder in the home list, colour-coded by urgency.
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onDelete,
    this.member,
  });

  final Reminder reminder;
  final VoidCallback onDelete;

  /// The family member this reminder is for. When set, a small "· Name" chip is
  /// shown so the head can tell whose renewal this is at a glance.
  final FamilyMember? member;

  CatalogItem? get _catalogItem {
    for (final c in kCategories) {
      for (final i in c.items) {
        if (i.key == reminder.itemKey) return i;
      }
    }
    return null;
  }

  Color get _categoryColor {
    for (final c in kCategories) {
      if (c.key == reminder.category) return c.color;
    }
    return const Color(0xFF4F46E5);
  }

  _Urgency get _urgency {
    final days = reminder.daysUntilExpiry;
    if (days < 0) return _Urgency.expired;
    if (reminder.isDueSoon) return _Urgency.due;
    if (days <= reminder.remindDaysBefore) return _Urgency.soon;
    return _Urgency.ok;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _catalogItem;
    final u = _urgency;
    final status = u.resolve(context);
    final days = reminder.daysUntilExpiry;

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Remove reminder?'),
                content: Text('“${reminder.title}” will be removed.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item?.icon ?? Icons.event,
                    color: _categoryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (member != null) ...[
                          _MemberChip(member: member!),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            '${status.expiryLabel} ${DateFmt.medium(reminder.expiryDate)}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                color: status.color,
                text: DateFmt.relativeDays(days),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Urgency { expired, due, soon, ok }

extension on _Urgency {
  _StatusStyle resolve(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (this) {
      case _Urgency.expired:
        return _StatusStyle(scheme.error, 'Expired on');
      case _Urgency.due:
        return const _StatusStyle(Color(0xFFF59E0B), 'Renew by');
      case _Urgency.soon:
        return const _StatusStyle(Color(0xFF6366F1), 'Expires on');
      case _Urgency.ok:
        return const _StatusStyle(Color(0xFF10B981), 'Expires on');
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.color, this.expiryLabel);
  final Color color;
  final String expiryLabel;
}

/// A tiny colour-coded pill naming the family member a reminder belongs to.
class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final color = member.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            member.isSelf ? 'You' : member.name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
