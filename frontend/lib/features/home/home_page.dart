import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../categories/domain/category_catalog.dart';
import '../categories/presentation/category_picker_sheet.dart';
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
    // Tap Add → the category picker: all catalog categories (expandable to
    // their items), plus an "Add category" button to create a custom one.
    final CategoryItem? item = await showCategoryPicker(context);
    if (item != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Picked ${item.emoji} ${item.label}')),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
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
