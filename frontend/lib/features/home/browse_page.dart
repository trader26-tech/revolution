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
/// Vibrancy comes ENTIRELY from MOTION — every tile shares the one violet
/// accent (no per-category colour). Each destination fades and rises in on open,
/// springs on press, and its icon ALWAYS animates: a soft accent ring pulses
/// outward and the icon gently bobs, phase-shifted per row so motion ripples
/// down the list and the screen never feels stagnant. "General" leads — the
/// open, easy "just remember anything" entry with a note.
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

  /// A continuous loop driving every icon's pulse ring + bob — so the Browse
  /// screen always has motion and never feels stagnant.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _documents.load();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    // A continuous forward loop (NOT reversing) — each cycle sweeps a pulse
    // ring outward and bobs the icon, so there is always motion on screen.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
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
          // ONE colour throughout — the violet accent. Every destination looks
          // the same; the ONLY differentiation is the icon + label, never hue.
          final destinations = <_Dest>[
            _Dest(
              icon: TaskCategory.other.icon,
              label: 'General',
              subtitle: 'Anything you want to remember — with a note.',
              count: _countFor(TaskCategory.other),
              onTap: () => _openCollection(TaskCategory.other),
              highlight: true,
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
              icon: Icons.folder_rounded,
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
                    pulse: _pulse,
                    // Offset each row's pulse phase so the motion ripples down
                    // the list instead of firing in unison.
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

/// One destination row: an always-animating accent icon, the label + subtitle,
/// a count, and a chevron. Springs on press.
class _DestTile extends StatefulWidget {
  const _DestTile({
    required this.dest,
    required this.pulse,
    required this.phase,
  });

  final _Dest dest;
  final AnimationController pulse;
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
              // The always-animating icon — the same accent for every tile.
              _LiveIcon(
                icon: d.icon,
                pulse: widget.pulse,
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
                  color:
                      count == 0 ? AppColors.inkFaint : AppColors.accent,
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

/// The always-on animated icon chip — the whole point of the redesign: the
/// Browse screen must NEVER feel stagnant. Every icon continuously:
///   • gently bobs up and down,
///   • emits a soft accent RING that expands and fades outward (a steady
///     "pulse" that says "tap me — add something"),
/// all in the single violet accent (no per-category colour). Each row's motion
/// is phase-shifted so the pulses ripple down the list instead of firing in
/// unison — the screen always has something moving somewhere.
class _LiveIcon extends StatelessWidget {
  const _LiveIcon({
    required this.icon,
    required this.pulse,
    required this.phase,
  });

  final IconData icon;
  final AnimationController pulse; // continuous 0→1 loop
  final double phase; // 0..1 offset so rows don't move in lockstep

  static const _accent = AppColors.accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        // A single continuous 0→1 phase for this row.
        final p = (pulse.value + phase) % 1.0;
        // Expanding ring: grows 1.0→1.7 and fades as it goes.
        final ringT = Curves.easeOut.transform(p);
        final ringScale = 1.0 + 0.7 * ringT;
        final ringOpacity = (1 - ringT) * 0.5;
        // A gentle vertical bob on a full sine, so it never stalls.
        final bob = -2.2 * _sin01(p);
        // A soft glow that swells with the ring's start.
        final glow = 0.3 + 0.3 * (1 - ringT);

        return SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The expanding, fading pulse ring.
              Opacity(
                opacity: ringOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              // The icon chip itself, gently bobbing.
              Transform.translate(
                offset: Offset(0, bob),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: _accent.withValues(alpha: 0.34)),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.30 * glow),
                        blurRadius: 14 * glow,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: _accent, size: 22),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 0→1→0 over p∈[0,1] (a raised sine), for the gentle bob.
  static double _sin01(double p) {
    // sin(pi * p) → 0 at ends, 1 at middle.
    final s = p <= 0 || p >= 1 ? 0.0 : _fastSin(3.14159265 * p);
    return s;
  }

  static double _fastSin(double x) {
    // Good-enough sine on [0, pi] via a parabola (Bhaskara) — no dart:math dep.
    final t = x / 3.14159265; // 0..1
    return 4 * t * (1 - t);
  }
}
