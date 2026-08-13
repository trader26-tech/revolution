import 'dart:math' as math;

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
          // the same; the ONLY differentiation is the icon, label, and each
          // icon's OWN meaningful motion (never hue).
          final destinations = <_Dest>[
            _Dest(
              icon: TaskCategory.other.icon,
              label: 'General',
              subtitle: 'Anything you want to remember — with a note.',
              count: _countFor(TaskCategory.other),
              onTap: () => _openCollection(TaskCategory.other),
              motion: _Motion.twinkle, // sparkles gently twinkle
              highlight: true,
            ),
            for (final c in kBrowseCategoriesNoGeneral)
              _Dest(
                icon: c.icon,
                label: c.label,
                subtitle: _subtitleFor(c),
                count: _countFor(c),
                onTap: () => _openCollection(c),
                motion: _motionFor(c),
              ),
            _Dest(
              icon: Icons.folder_rounded,
              label: 'Documents',
              subtitle: 'Your files — policies, receipts, photos.',
              count: _documents.totalCount,
              onTap: _openDocuments,
              motion: _Motion.flip, // the folder peeks open
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

  /// Each category's OWN motion — chosen to MEAN something about the category,
  /// so the animation reads as purposeful, not decorative noise.
  _Motion _motionFor(TaskCategory c) => switch (c) {
        TaskCategory.subscription => _Motion.recur, // recurring cycle spin
        TaskCategory.birthday => _Motion.celebrate, // a happy little wobble
        TaskCategory.investment => _Motion.grow, // savings rise upward
        TaskCategory.policies => _Motion.guard, // steady, solid breath
        TaskCategory.insurance => _Motion.guard,
        TaskCategory.bills => _Motion.recur,
        TaskCategory.other => _Motion.twinkle,
      };
}

/// The distinct, meaningful motions an icon can carry.
enum _Motion {
  twinkle,   // General — sparkle points flicker
  recur,     // Subscriptions/Bills — a slow recurring rotation, like a cycle
  celebrate, // Occasions — a gentle celebratory wobble
  grow,      // SIPs — a repeated upward "growth" nudge
  guard,     // Policies/Insurance — a calm, steady protective breath
  flip,      // Documents — the folder peeks open and closes
}

/// A destination’s data. No colour here — every tile uses the one accent.
class _Dest {
  const _Dest({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.onTap,
    required this.motion,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  /// This icon's own meaningful motion.
  final _Motion motion;

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
              // The icon, animated with its OWN meaningful motion.
              _LiveIcon(
                icon: d.icon,
                motion: d.motion,
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

/// The animated icon chip. The chip itself is calm and static (a soft accent
/// square) — the LIFE is in the GLYPH, which moves in a way that MEANS something
/// about the category, so the motion reads as purposeful rather than a random
/// effect stamped on everything:
///   • twinkle  (General)     — a soft breathe + brighten, like an idea sparking
///   • recur    (Subscriptions/Bills) — a slow full rotation, the recurring cycle
///   • celebrate(Occasions)   — a happy little wobble + hop
///   • grow     (SIPs)        — a repeated upward rise, savings growing
///   • guard    (Policies)    — a calm, steady protective breath
///   • flip     (Documents)   — the folder periodically peeks open (Y-flip)
///
/// All in the single violet accent; each row is phase-shifted so the screen
/// always has gentle, coherent movement without ever feeling busy.
class _LiveIcon extends StatelessWidget {
  const _LiveIcon({
    required this.icon,
    required this.motion,
    required this.pulse,
    required this.phase,
  });

  final IconData icon;
  final _Motion motion;
  final AnimationController pulse; // continuous 0→1 loop
  final double phase; // 0..1 offset so rows don't move in lockstep

  static const _accent = AppColors.accent;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final p = (pulse.value + phase) % 1.0; // this icon's own 0→1 loop
          return Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.34)),
            ),
            child: _animatedGlyph(p),
          );
        },
      ),
    );
  }

  /// The glyph with its category-specific transform applied at loop position [p].
  Widget _animatedGlyph(double p) {
    final glyph = Icon(icon, color: _accent, size: 22);
    switch (motion) {
      case _Motion.twinkle:
        // Breathe brighter/bigger then settle — like a thought sparking.
        final t = _wave(p); // 0→1→0
        return Transform.scale(
          scale: 0.94 + 0.12 * t,
          child: Icon(icon, size: 22,
              color: Color.lerp(_accent, Colors.white, 0.35 * t)),
        );

      case _Motion.recur:
        // A slow, continuous full rotation — the recurring billing cycle.
        return Transform.rotate(angle: p * 2 * math.pi, child: glyph);

      case _Motion.celebrate:
        // A happy wobble (rock left↔right) with a tiny hop at the peak.
        final wobble = math.sin(p * 2 * math.pi) * 0.18; // radians
        final hop = -2.5 * _wave(p);
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform.rotate(angle: wobble, child: glyph),
        );

      case _Motion.grow:
        // Rise up and fade back to the bottom, on repeat — savings growing.
        final rise = -6 * p; // travels up across the loop
        final fade = (1 - p).clamp(0.0, 1.0) * 0.5 + 0.5;
        return Opacity(
          opacity: fade,
          child: Transform.translate(offset: Offset(0, rise), child: glyph),
        );

      case _Motion.guard:
        // A calm, slow protective breath — solid and reassuring.
        final t = _wave(p);
        return Transform.scale(scale: 0.96 + 0.06 * t, child: glyph);

      case _Motion.flip:
        // The folder periodically peeks open — a Y-axis flip that eases back.
        final open = _wave(p); // 0→1→0
        final angle = open * 0.9; // up to ~50°
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(angle),
          child: glyph,
        );
    }
  }

  /// A smooth 0→1→0 over p∈[0,1] using a real sine (raised).
  static double _wave(double p) => math.sin(p * math.pi);
}
