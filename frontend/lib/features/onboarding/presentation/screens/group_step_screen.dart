import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_category.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// One step of the grouped onboarding wizard: shows a single [OnboardingGroup]'s
/// categories as a grid of tappable tiles. Tapping toggles a category on/off —
/// details (name/date/frequency) are set later. The common ones arrive ticked.
///
/// The wizard owns the shared [drafts] map and passes it in; this screen just
/// reads/writes the entries for its own group's categories and reports changes
/// via [onChanged].
class GroupStepScreen extends StatelessWidget {
  const GroupStepScreen({
    super.key,
    required this.group,
    required this.drafts,
    required this.onChanged,
  });

  final OnboardingGroup group;

  /// category.key → its staged draft. Presence == selected. Shared across all
  /// steps and owned by the wizard.
  final Map<String, ReminderDraft> drafts;
  final VoidCallback onChanged;

  void _toggle(OnboardingCategory c) {
    HapticFeedback.lightImpact();
    if (drafts.containsKey(c.key)) {
      drafts.remove(c.key);
    } else {
      drafts[c.key] = ReminderDraft(
        name: c.defaultName,
        day: c.defaultDay,
        frequency: c.defaultFrequency,
      );
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cats = group.categories;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: group.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(group.icon, color: group.color, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  group.subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final c = cats[i];
                return _CategoryTile(
                  category: c,
                  selected: drafts.containsKey(c.key),
                  onTap: () => _toggle(c),
                );
              },
              childCount: cats.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final OnboardingCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? c.color.withValues(alpha: 0.10) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? c.color : AppColors.cardBorder,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: selected ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(c.icon, color: c.color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration:
                      BoxDecoration(color: c.color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
