import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/add_category.dart';

/// The first step of adding something from home: pick WHAT you're adding. A
/// clean grid of category cards, each in its own accent, so the next screen can
/// ask for only the fields that category needs.
///
/// Returns the chosen [AddCategory], or null if dismissed.
Future<AddCategory?> showCategoryPicker(BuildContext context) {
  return showModalBottomSheet<AddCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _CategoryPickerSheet(),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet();

  @override
  Widget build(BuildContext context) {
    final cats = AddCategory.available;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'What are you adding?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pick a type — we’ll only ask what it needs.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 20),
            // Two-up grid of category cards. Wraps to more rows as categories
            // are added, so the layout scales without change.
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                for (final c in cats)
                  _CategoryCard(
                    category: c,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(c);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable category card — icon chip in the category's accent, its label,
/// and a short blurb. Lifts on press.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final AddCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = category.color;
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(category.icon, color: accent, size: 24),
              ),
              const Spacer(),
              Text(
                category.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                category.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
