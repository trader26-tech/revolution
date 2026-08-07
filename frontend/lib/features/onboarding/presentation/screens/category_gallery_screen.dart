import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_category.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// The onboarding category gallery: a grid of common bills/subscriptions with
/// the near-universal ones already ticked. Tapping toggles a category on/off;
/// tapping a selected one opens the confirm sheet to adjust its name/date/
/// frequency. The staged drafts are what we save (to the anonymous account) at
/// the end of onboarding.
///
/// [onChanged] reports the current set of drafts keyed by category so the flow
/// can show a running count and enable "Continue".
class CategoryGalleryScreen extends StatefulWidget {
  const CategoryGalleryScreen({super.key, this.onChanged});

  final ValueChanged<Map<String, ReminderDraft>>? onChanged;

  @override
  State<CategoryGalleryScreen> createState() => CategoryGalleryScreenState();
}

class CategoryGalleryScreenState extends State<CategoryGalleryScreen> {
  /// category.key → its staged draft. Presence == selected.
  final Map<String, ReminderDraft> _drafts = {};

  @override
  void initState() {
    super.initState();
    // Pre-select the common bills with their smart defaults.
    for (final c in kOnboardingCategories) {
      if (c.preselected) {
        _drafts[c.key] = ReminderDraft(
          name: c.defaultName,
          day: c.defaultDay,
          frequency: c.defaultFrequency,
        );
      }
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onChanged?.call(_drafts));
  }

  bool _isSelected(OnboardingCategory c) => _drafts.containsKey(c.key);

  Future<void> _tap(OnboardingCategory c) async {
    HapticFeedback.lightImpact();
    if (_isSelected(c)) {
      // Selected → open the confirm sheet to tweak (or toggle off from there is
      // not offered; a second tap on the tick toggles off — see the tile).
      final edited = await showReminderConfirmSheet(
        context,
        category: c,
        initial: _drafts[c.key],
      );
      if (edited != null) {
        setState(() => _drafts[c.key] = edited);
        widget.onChanged?.call(_drafts);
      }
    } else {
      // Not selected → stage it with defaults immediately (magic), no sheet.
      setState(() {
        _drafts[c.key] = ReminderDraft(
          name: c.defaultName,
          day: c.defaultDay,
          frequency: c.defaultFrequency,
        );
      });
      widget.onChanged?.call(_drafts);
    }
  }

  void _toggleOff(OnboardingCategory c) {
    HapticFeedback.lightImpact();
    setState(() => _drafts.remove(c.key));
    widget.onChanged?.call(_drafts);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What do you\npay for?',
                style: text.displaySmall?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                "We've ticked the usual ones. Tap to add or edit — "
                "we'll remind you before each is due.",
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: kOnboardingCategories.length,
            itemBuilder: (_, i) {
              final c = kOnboardingCategories[i];
              return _CategoryTile(
                category: c,
                selected: _isSelected(c),
                draft: _drafts[c.key],
                onTap: () => _tap(c),
                onRemove: () => _toggleOff(c),
              );
            },
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
    required this.draft,
    required this.onTap,
    required this.onRemove,
  });

  final OnboardingCategory category;
  final bool selected;
  final ReminderDraft? draft;
  final VoidCallback onTap;
  final VoidCallback onRemove;

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
                  // When selected, show the chosen day as a tiny hint.
                  if (selected && draft != null)
                    Text(
                      'the ${draft!.day}${_suffix(draft!.day)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: c.color,
                      ),
                    ),
                ],
              ),
            ),
            // Tick / remove badge, top-right.
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _suffix(int d) {
    if (d % 100 >= 11 && d % 100 <= 13) return 'th';
    return switch (d % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  }
}
