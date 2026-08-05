import 'package:flutter/material.dart';

import '../../data/reminders_repository.dart';
import '../../domain/catalog.dart';
import '../../domain/reminder.dart';
import 'reminder_form.dart';

/// Opens the add-reminder flow as a draggable bottom sheet and resolves to the
/// created [Reminder] (or null if dismissed).
Future<Reminder?> showAddReminderSheet(
  BuildContext context, {
  required RemindersRepository repository,
}) {
  return showModalBottomSheet<Reminder>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddReminderSheet(repository: repository),
  );
}

enum _Step { category, item, form }

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet({required this.repository});
  final RemindersRepository repository;

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  _Step _step = _Step.category;
  ReminderCategory? _category;
  CatalogItem? _item;
  bool _submitting = false;

  void _openCategory(ReminderCategory c) {
    setState(() {
      _category = c;
      _step = _Step.item;
    });
  }

  void _openItem(CatalogItem i) {
    setState(() {
      _item = i;
      _step = _Step.form;
    });
  }

  void _back() {
    setState(() {
      switch (_step) {
        case _Step.form:
          _step = _Step.item;
          break;
        case _Step.item:
          _step = _Step.category;
          break;
        case _Step.category:
          break;
      }
    });
  }

  Future<void> _submit(ReminderDraft draft) async {
    setState(() => _submitting = true);
    try {
      final created = await widget.repository.create(draft);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: $e')),
        );
      }
    }
  }

  String get _titleForStep {
    switch (_step) {
      case _Step.category:
        return 'What do you want to track?';
      case _Step.item:
        return _category!.label;
      case _Step.form:
        return 'Set it up';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            _SheetHeader(
              title: _titleForStep,
              showBack: _step != _Step.category,
              onBack: _back,
            ),
            const Divider(height: 1),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(anim);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.category:
        return _CategoryList(
          key: const ValueKey('category'),
          onSelect: _openCategory,
        );
      case _Step.item:
        return _ItemList(
          key: const ValueKey('item'),
          category: _category!,
          onSelect: _openItem,
        );
      case _Step.form:
        return ReminderForm(
          key: ValueKey('form-${_item!.key}'),
          category: _category!,
          item: _item!,
          submitting: _submitting,
          onSubmit: _submit,
        );
    }
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
  });
  final String title;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({super.key, required this.onSelect});
  final ValueChanged<ReminderCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: kCategories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (_, i) {
        final c = kCategories[i];
        return ListTile(
          leading: _IconBadge(icon: c.icon, color: c.color),
          title: Text(c.label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${c.items.length} things you can track'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelect(c),
        );
      },
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({super.key, required this.category, required this.onSelect});
  final ReminderCategory category;
  final ValueChanged<CatalogItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: category.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final item = category.items[i];
        return ListTile(
          leading: _IconBadge(icon: item.icon, color: category.color),
          title: Text(item.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_subtitle(item)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelect(item),
        );
      },
    );
  }

  String _subtitle(CatalogItem item) {
    switch (item.validityKind) {
      case ValidityKind.fixedYears:
        return 'Valid ${item.defaultValidityYears} yrs · '
            'remind ${item.defaultRemindDaysBefore} days before';
      case ValidityKind.evergreen:
        return 'No expiry · periodic review reminder';
      case ValidityKind.expiryOnly:
        return 'Remind ${item.defaultRemindDaysBefore} days before expiry';
    }
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}
