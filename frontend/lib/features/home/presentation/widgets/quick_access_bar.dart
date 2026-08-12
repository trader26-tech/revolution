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
      padding: const EdgeInsets.only(top: 12),
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
    this.morphFrom,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  /// An optional small count (e.g. how many documents) shown as a pill.
  final String? badge;

  /// When set, the tile's glyph plays a one-time MORPH from [morphFrom] to
  /// [icon] on first appearance — used to signal "this is a different kind of
  /// plus" (a plain + turning into a document-plus).
  final IconData? morphFrom;
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
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: _MorphIcon(
                  from: item.morphFrom,
                  to: item.icon,
                  color: item.color,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 14,
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

/// A glyph that, when [from] is set, plays a ONE-TIME morph from [from] to [to]
/// on first appearance: the plain "+" spins/scales/fades out as the destination
/// icon (a document-plus) spins/scales/fades in — a clear "this + is different"
/// cue. With no [from] it's just a static icon.
class _MorphIcon extends StatefulWidget {
  const _MorphIcon({
    required this.from,
    required this.to,
    required this.color,
    required this.size,
  });

  final IconData? from;
  final IconData to;
  final Color color;
  final double size;

  @override
  State<_MorphIcon> createState() => _MorphIconState();
}

class _MorphIconState extends State<_MorphIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    if (widget.from != null) {
      // A brief beat so the eye registers the plain "+" first, THEN it morphs.
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _c.forward();
      });
    } else {
      _c.value = 1; // no morph → show the destination icon immediately
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.from;
    if (from == null) {
      return Icon(widget.to, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutBack.transform(_c.value.clamp(0.0, 1.0));
        // The outgoing "+" fades/rotates/shrinks in the first half; the
        // document-plus rises in the second half — a clean hand-off.
        final outOpacity = (1 - (_c.value * 1.6)).clamp(0.0, 1.0);
        final inOpacity = ((_c.value - 0.4) / 0.6).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: outOpacity,
              child: Transform.rotate(
                angle: t * 0.9,
                child: Transform.scale(
                  scale: 1 - 0.4 * t,
                  child: Icon(from, size: widget.size, color: widget.color),
                ),
              ),
            ),
            Opacity(
              opacity: inOpacity,
              child: Transform.rotate(
                angle: (t - 1) * 0.9,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * t,
                  child: Icon(widget.to, size: widget.size, color: widget.color),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
