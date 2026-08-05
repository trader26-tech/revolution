import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/category_catalog.dart';

/// Opens the category picker as a bottom sheet.
///
/// Plain and minimal: a list of category buttons, nothing else. Tapping a
/// category selects it and closes the sheet. Returns the chosen [Category], or
/// null if dismissed.
Future<Category?> showCategoryPicker(
  BuildContext context, {
  List<Category> extraCategories = const [],
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CategoryPickerSheet(extraCategories: extraCategories),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.extraCategories});

  final List<Category> extraCategories;

  List<Category> get _categories => [...kCatalog, ...extraCategories];

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose a category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                indent: 24,
                endIndent: 24,
                color: AppColors.hairline,
              ),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                return _CategoryRow(
                  category: cat,
                  onTap: () => Navigator.of(context).pop(cat),
                );
              },
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            indent: 24,
            endIndent: 24,
            color: AppColors.hairline,
          ),
          // "Add category" as a matching flat row, in the accent colour.
          InkWell(
            onTap: () => _createCategory(context),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                18 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 16),
                  Text(
                    'Add category',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCategory(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${name.trim()}” category created')),
      );
    }
  }
}

/// A single flat category row — a unified-colour icon + the name, tappable,
/// with only a thin divider between rows. No cards, no boxes, no pills.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Icon(category.icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. Subscriptions',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
