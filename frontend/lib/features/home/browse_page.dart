import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../documents/data/documents_store.dart';
import '../documents/presentation/documents_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/category_visuals.dart';
import '../tasks/domain/task.dart';
import 'presentation/collection_page.dart';

/// The Browse tab — the launcher to every category's collection (General,
/// Subscriptions, Occasions, SIPs, Policies…) and the local Documents library.
///
/// The whole surface is ONE violet accent — no per-category colour, and no
/// fussy per-icon motion. The life is a single, tasteful touch: when you land
/// on the tab, the rows arrive ONE AT A TIME, each sliding up and fading in a
/// beat after the one above it. That gentle cascade makes the screen feel
/// hand-assembled and considered. "General" leads — the easy "just remember
/// anything" entry with a note.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key, required this.store, this.isActive = true});

  final TaskStore store;

  /// True when Browse is the visible tab. Each time it flips back to true, the
  /// row-entrance cascade re-plays — so switching to Browse always greets you
  /// with the rows arriving one at a time, not a static list.
  final bool isActive;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage>
    with SingleTickerProviderStateMixin {
  final _documents = DocumentsStore();

  /// Drives the one-at-a-time entrance cascade of the rows.
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _documents.load();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Play on first mount only if Browse is the visible tab; otherwise wait
    // until it becomes active (didUpdateWidget) so the cascade isn't "used up"
    // invisibly while Home is showing.
    if (widget.isActive) _intro.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant BrowsePage old) {
    super.didUpdateWidget(old);
    // Switched TO Browse → replay the row cascade from the top.
    if (widget.isActive && !old.isActive) {
      _intro.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _documents.dispose();
    super.dispose();
  }

  void _openDocuments() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentsPage(store: _documents)),
    );
  }

  void _openCollection(TaskCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionPage(store: widget.store, category: category),
      ),
    );
  }

  int _countFor(TaskCategory c) =>
      widget.store.tasks.where((t) => t.category == c).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.store, _documents]),
        builder: (context, _) {
          // Documents leads, then the tailored categories, and General sits at
          // the BOTTOM. ONE colour throughout — differentiation is icon + label
          // only, never hue.
          final destinations = <_Dest>[
            _Dest(
              icon: Icons.folder_rounded,
              label: 'Documents',
              subtitle: 'Your files — policies, receipts, photos.',
              count: _documents.totalCount,
              onTap: _openDocuments,
            ),
            for (final c in kBrowseCategoriesNoGeneral)
              _Dest(
                icon: c.icon,
                label: c.label,
                subtitle: _subtitleFor(c),
                count: _countFor(c),
                onTap: () => _openCollection(c),
              ),
            _Dest(
              icon: TaskCategory.other.icon,
              label: 'General',
              subtitle: 'Anything you want to remember — with a note.',
              count: _countFor(TaskCategory.other),
              onTap: () => _openCollection(TaskCategory.other),
              highlight: true,
            ),
          ];

          return ListView(
            padding: const EdgeInsets.only(top: 18, bottom: 120),
            children: [
              _header(),
              const SizedBox(height: 10),
              for (var i = 0; i < destinations.length; i++)
                _CascadeIn(
                  intro: _intro,
                  index: i,
                  total: destinations.length,
                  child: _DestTile(dest: destinations[i]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browse',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Everything you track — tap in, or add something new.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(TaskCategory c) => switch (c) {
        TaskCategory.subscription => 'Netflix, Spotify, and the rest.',
        TaskCategory.birthday => 'Birthdays & the dates that matter.',
        TaskCategory.investment => 'SIPs and recurring investments.',
        TaskCategory.policies => 'Savings & endowment plans.',
        TaskCategory.insurance => 'Renewals and cover.',
        TaskCategory.bills => 'Recurring bills & payments.',
        TaskCategory.other => 'Anything else.',
      };
}

/// A destination’s data. No colour here — every tile uses the one accent.
class _Dest {
  const _Dest({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  /// The lead "General" tile gets a touch more presence (a filled accent wash).
  final bool highlight;
}

/// The entrance cascade: row [index] slides up + fades in a beat AFTER the row
/// above it, so the list assembles one row at a time. Each row owns a
/// sub-window of the shared [intro] timeline; the windows barely overlap, so
/// the arrival reads as one-then-the-next rather than everything at once.
class _CascadeIn extends StatelessWidget {
  const _CascadeIn({
    required this.intro,
    required this.index,
    required this.total,
    required this.child,
  });

  final AnimationController intro;
  final int index;
  final int total;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      builder: (context, child) {
        // A CLEARLY-STAGGERED wave: each row starts a distinct beat after the
        // one above, then springs up into place — you SEE them arrive one by one.
        const perRow = 0.11;
        const maxStart = 0.6;
        const window = 0.4;
        final start = (index * perRow).clamp(0.0, maxStart);
        final raw = ((intro.value - start) / window).clamp(0.0, 1.0);
        final eased = Curves.easeOutBack.transform(raw);
        final fade = Curves.easeOut.transform(raw);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(14 * (1 - fade), 44 * (1 - eased)),
            child: Transform.scale(
              scale: 0.88 + 0.12 * eased,
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// One destination row: a calm static accent icon, the label + subtitle, a
/// count, and a chevron. Springs softly on press. No looping motion.
class _DestTile extends StatefulWidget {
  const _DestTile({required this.dest});
  final _Dest dest;

  @override
  State<_DestTile> createState() => _DestTileState();
}

class _DestTileState extends State<_DestTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.dest;
    final count = d.count;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        d.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 5, 18, 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: d.highlight
                ? AppColors.accent.withValues(alpha: 0.10)
                : AppColors.card.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: d.highlight
                  ? AppColors.accent.withValues(alpha: 0.32)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              // A calm, static accent icon chip.
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.34)),
                ),
                child: Icon(d.icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                count == 0 ? '—' : '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: count == 0 ? AppColors.inkFaint : AppColors.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.inkFaint.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
