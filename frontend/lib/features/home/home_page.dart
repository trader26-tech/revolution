import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../categories/domain/category_catalog.dart';
import '../categories/domain/item_catalog.dart';
import '../categories/presentation/category_picker_sheet.dart';
import '../categories/presentation/item_list_page.dart';
import '../reminders/domain/reminder_draft.dart';
import '../settings/settings_page.dart';

/// The Home screen.
///
/// A glass top bar holds the two actions — Settings (left) and Add (right) —
/// with the content below. Kept intentionally minimal: this is the clean
/// template the app grows from.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _add(BuildContext context) async {
    // Tap Add → pick a category → its item list → the minimal entry sheet.
    final Category? category = await showCategoryPicker(context);
    if (category == null || !context.mounted) return;

    final items = kItemsByCategory[category.name];
    if (items == null || items.isEmpty) {
      // Categories without a detailed item list yet — placeholder for now.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${category.name} — items coming soon')),
      );
      return;
    }

    final draft = await Navigator.of(context).push<ReminderDraft>(
      MaterialPageRoute(
        builder: (_) => ItemListPage(
          categoryName: category.name,
          items: items,
        ),
      ),
    );
    if (draft != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added “${draft.title}” ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _TopBar(
            onSettings: () => _openSettings(context),
            onAdd: () => _add(context),
          ),
          const Expanded(child: _EmptyContent()),
        ],
      ),
    );
  }
}

/// The glass top bar: Settings on the left, a title, Add on the right.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings, required this.onAdd});

  final VoidCallback onSettings;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
          const Spacer(),
          Text(
            'Home',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
          const Spacer(),
          GlassIconButton(
            icon: Icons.add,
            tooltip: 'Add',
            accent: true,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

/// A calm, centred empty state for the fresh template.
class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      // Offset the floating nav's footprint (height + bottom gap) so the
      // content is centred in the VISIBLE area, not the area that runs under
      // the nav — otherwise it reads as pushed up / off-centre.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 44, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              'All clear',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap ﹢ to add your first item.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
