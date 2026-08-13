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
/// Vibrancy comes from MOTION, not colour blocks: each destination fades and
/// rises into place in a gentle stagger when the tab opens, springs on press,
/// and carries a soft, slowly-breathing accent glow behind its icon. "General"
/// leads — the open, easy "just remember anything" entry with a note.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key, required this.store});

  final TaskStore store;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage>
    with TickerProviderStateMixin {
  final _documents = DocumentsStore();

  /// Drives the one-time entrance stagger for the destinations.
  late final AnimationController _intro;

  /// A slow, always-on breath for the accent glows — keeps the page feeling
  /// alive without ever being busy. Deliberately gentle + low frequency.
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _documents.load();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
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
          // Build the destination list. "General" leads (the open catch-all),
          // then the tailored categories, then Documents.
          final destinations = <_Dest>[
            _Dest(
              icon: TaskCategory.other.icon,
              tint: TaskCategory.other.color,
              label: 'General',
              subtitle: 'Anything you want to remember — with a note.',
              count: _countFor(TaskCategory.other),
              onTap: () => _openCollection(TaskCategory.other),
              highlight: true,
            ),
            for (final c in kBrowseCategoriesNoGeneral)
              _Dest(
                icon: c.icon,
                tint: c.color,
                label: c.label,
                subtitle: _subtitleFor(c),
                count: _countFor(c),
                onTap: () => _openCollection(c),
              ),
            _Dest(
              icon: Icons.folder_rounded,
              tint: AppColors.accent,
              label: 'Documents',
              subtitle: 'Your files — policies, receipts, photos.',
              count: _documents.totalCount,
              onTap: _openDocuments,
            ),
          ];

          return ListView(
            padding: const EdgeInsets.only(top: 18, bottom: 120),
            children: [
              _header(),
              const SizedBox(height: 10),
              for (var i = 0; i < destinations.length; i++)
                _StaggerIn(
                  // Each row starts a beat after the previous → a gentle cascade.
                  intro: _intro,
                  index: i,
                  total: destinations.length,
                  child: _DestTile(
                    dest: destinations[i],
                    breath: _breath,
                    // Offset each glow's breath phase so they don't pulse in
                    // lockstep — reads as organic, not a metronome.
                    phase: i / destinations.length,
                  ),
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

/// A destination’s data.
class _Dest {
  const _Dest({
    required this.icon,
    required this.tint,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final Color tint;
  final String label;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  /// The lead "General" tile gets a touch more presence (a filled accent wash).
  final bool highlight;
}

/// Wraps a child in a one-time staggered fade + rise, driven by the shared
/// [intro] controller. Row [index] starts a fraction later than the one above,
/// so the list assembles in a smooth cascade the first time you land on Browse.
class _StaggerIn extends StatelessWidget {
  const _StaggerIn({
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
        // Each row owns a sub-window of the intro timeline; windows overlap so
        // the cascade flows rather than stepping one-by-one.
        final start = total <= 1 ? 0.0 : (index / total) * 0.6;
        final t = ((intro.value - start) / 0.4).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - eased)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// One destination row: a breathing accent glow behind its icon, the label +
/// subtitle, a count, and a chevron. Springs on press.
class _DestTile extends StatefulWidget {
  const _DestTile({
    required this.dest,
    required this.breath,
    required this.phase,
  });

  final _Dest dest;
  final AnimationController breath;
  final double phase;

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
                ? d.tint.withValues(alpha: 0.10)
                : AppColors.card.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: d.highlight
                  ? d.tint.withValues(alpha: 0.32)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              // The breathing icon chip.
              _BreathingIcon(
                icon: d.icon,
                tint: d.tint,
                breath: widget.breath,
                phase: widget.phase,
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
                  color: count == 0 ? AppColors.inkFaint : d.tint,
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

/// The icon chip with a soft accent glow that slowly breathes (swells and
/// fades) — the source of the page's quiet, ambient life.
class _BreathingIcon extends StatelessWidget {
  const _BreathingIcon({
    required this.icon,
    required this.tint,
    required this.breath,
    required this.phase,
  });

  final IconData icon;
  final Color tint;
  final AnimationController breath;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breath,
      builder: (context, _) {
        // A phase-shifted 0→1→0 breath. Kept shallow so it's felt, not watched.
        final v = ((breath.value + phase) % 1.0);
        final b = (0.5 - (v - 0.5).abs()) * 2; // triangle 0→1→0
        final glow = 0.35 + 0.25 * b;
        return Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.28 * glow),
                blurRadius: 16 * glow,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: tint, size: 23),
        );
      },
    );
  }
}
