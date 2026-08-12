import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// A row of quick-access buttons that sits just ABOVE the Browse section — the
/// launcher strip for things that aren't categories (Documents today; more
/// tiles can slot in beside it later without touching the layout).
///
/// Each tile is a compact glass pill with an icon + label; the row scrolls
/// horizontally so it holds any number of future entries.
class QuickAccessBar extends StatelessWidget {
  const QuickAccessBar({super.key, required this.items});

  final List<QuickAccessItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _QuickTile(item: items[i]),
              if (i != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// One quick-access entry.
class QuickAccessItem {
  const QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.accent,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  /// An optional small count (e.g. how many documents) shown as a pill.
  final String? badge;
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.item});
  final QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          item.onTap();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 19, color: item.color),
              ),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.badge!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
