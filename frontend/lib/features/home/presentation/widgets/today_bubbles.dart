import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../onboarding/presentation/widgets/magic_text.dart'
    show MagicText;
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';

/// The Home hero: the screen starts EMPTY, then Revo conjures today's reminders
/// ONE AT A TIME, in slow motion — each line materialises word by word (the
/// onboarding shimmer), and the NEXT one only begins once the previous has
/// fully settled. You watch each thing being "thought up", so it reads as real
/// effort per item. When the sequence finishes it rests as a clean, usable list
/// (each line tappable, with a tick to dismiss).
class TodayBubbles extends StatefulWidget {
  const TodayBubbles({
    super.key,
    required this.replayTick,
    required this.greeting,
    required this.tasks,
    required this.doneTasks,
    required this.lineFor,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
    this.header,
  });

  /// An optional block rendered full-width BELOW the Revo+greeting row and above
  /// the reminders — used for the date header, so the top-to-bottom order reads
  /// Greeting → header → bubbles. Fades in with the greeting.
  final Widget? header;

  /// Bumped by the parent whenever Home becomes visible again — a change here
  /// restarts the conjuring from empty, so returning to Home always re-plays it.
  final int replayTick;

  /// The catchy one-liner for a task — the AI (Groq) line when the backend has
  /// generated one for today, else null so we fall back to a local sentence.
  final String? Function(Task) lineFor;

  /// The top line Revo says — "Good evening, Sanjeev".
  final String greeting;

  /// Everything due today, still ACTIVE (not done) — soonest first. These are
  /// the reminders that get conjured word-by-word.
  final List<Task> tasks;

  /// Everything due today the user has already marked DONE — shown in the
  /// "Done today" section, each tappable to bring it back.
  final List<Task> doneTasks;

  /// Tap a settled line → open its edit form.
  final ValueChanged<Task> onOpen;

  /// Toggle a task's done state (done ↔ undone). Persists to Supabase; the
  /// store rebuild then moves the task between the active and done groups.
  final ValueChanged<Task> onToggle;

  /// Delete a task (from a line's long-press menu). Persists + offers undo.
  final ValueChanged<Task> onDelete;

  @override
  State<TodayBubbles> createState() => _TodayBubblesState();
}

class _TodayBubblesState extends State<TodayBubbles>
    with SingleTickerProviderStateMixin {
  // ONE controller drives the whole conjuring run in real milliseconds. Every
  // stage owns an absolute [start,end) window; because each reminder's window
  // begins only AFTER the previous reminder's window ends, the reveal is
  // strictly sequential — never overlapping — so each line is clearly "thought
  // up" on its own before the next begins.
  late final AnimationController _run;

  // Intro (the greeting), then a beat, then the items — deliberately SLOW so
  // the effort is visible.
  static const _greetStartMs = 620;
  static const _greetEndMs = 1500;
  static const _firstItemMs = 1850;

  /// How long ONE reminder takes to fully materialise, and the gap before the
  /// next starts. Slow on purpose — the shimmer should visibly sweep across the
  /// line word by word, not flash past. This paces that reading sweep.
  static const _itemRevealMs = 1500;
  static const _itemGapMs = 300;
  static const _itemStrideMs = _itemRevealMs + _itemGapMs;

  List<Task> get _active => widget.tasks;
  List<Task> get _done => widget.doneTasks;

  int get _totalMs =>
      _firstItemMs +
      (_active.isEmpty ? 0 : (_active.length - 1) * _itemStrideMs) +
      _itemRevealMs;

  double get _ms => _run.value * _totalMs;

  /// How many active tasks the current run was choreographed for. On a cold
  /// launch the store loads tasks ASYNChronously, so the first build often has an
  /// EMPTY list — if the controller ran against that, the real tasks would arrive
  /// with it already finished and the reveal would look rushed/broken. So the
  /// first time the list goes from empty → populated we RE-choreograph and replay
  /// from the top, matching the actual list. (Tab-return replays via replayTick;
  /// ticking/deleting — a populated list SHRINKING — never replays.)
  int _runCount = -1;

  void _startRun() {
    _runCount = widget.tasks.length;
    _run.duration = Duration(milliseconds: _totalMs);
    _run.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _run = AnimationController(vsync: this, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_startRun); // choreograph for whatever's loaded on this frame
    });
  }

  @override
  void didUpdateWidget(covariant TodayBubbles old) {
    super.didUpdateWidget(old);
    // Home became visible again (tab return) → conjure it all over, from empty.
    if (widget.replayTick != old.replayTick) {
      _startRun();
      return;
    }
    // Cold-launch case: the run was choreographed for an EMPTY list, then the
    // async store load delivered the first tasks. Re-run once for the real list
    // so nothing is left half/instantly-revealed. Only fires on empty → non-empty
    // (a growth), so ticking/deleting (a shrink) never replays.
    if (_runCount == 0 && widget.tasks.isNotEmpty) {
      _startRun();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  /// 0→1 progress across an absolute ms window.
  double _win(num startMs, num endMs) =>
      ((_ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

  /// The absolute ms at which reminder [i] STARTS materialising. Each one waits
  /// a full stride after the previous, so they never overlap.
  num _itemStart(int i) => _firstItemMs + i * _itemStrideMs;

  /// Tick an active reminder → mark it done. The store flips `done` + persists
  /// to Supabase; on the rebuild the task moves out of [tasks] into [doneTasks]
  /// and slides into the "Done today" section below. A toast offers a quick undo
  /// for the fat-finger case, but it's no longer the ONLY way back — the Done
  /// section is always there.
  void _complete(Task task) {
    HapticFeedback.mediumImpact();
    widget.onToggle(task);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Done — ${task.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accent,
          onPressed: () {
            if (!mounted) return;
            widget.onToggle(task); // flip back to active
          },
        ),
      ),
    );
  }

  /// Tap a done item's check → bring it back to active (mark undone). Persists.
  void _restore(Task task) {
    HapticFeedback.selectionClick();
    widget.onToggle(task);
  }

  /// Long-press a line → a small action sheet with Edit + Delete. Keeps tap =
  /// edit intact while giving a clear, discoverable way to remove one item.
  Future<void> _showActions(Task task) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<_LineAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LineActionSheet(title: task.title),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _LineAction.edit:
        widget.onOpen(task);
      case _LineAction.delete:
        widget.onDelete(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _run,
      builder: (context, _) {
        final active = _active;
        final done = _done;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── The greeting, materialising word by word (no mascot here — the
            //    Revo character now lives on the ★ command chat page). ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _Greeting(
                greeting: widget.greeting,
                progress: _win(_greetStartMs, _greetEndMs),
              ),
            ),

            // ── Optional header (e.g. the date) — full-width below the greeting,
            //    fading in with it, then a beat before the reminders. ──
            if (widget.header != null) ...[
              const SizedBox(height: 14),
              Opacity(
                opacity: Curves.easeOut.transform(_win(_greetStartMs, _greetEndMs)),
                child: widget.header!,
              ),
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 22),

            // ── Today's reminders in ONE list. Active ones conjure word by
            //    word; a completed one simply CROSSES OFF in place — no separate
            //    "Done" bucket, no counts. Tap a crossed-off line to bring it
            //    back. ──
            if (active.isEmpty && done.isEmpty)
              Opacity(
                opacity: _win(_greetEndMs, _greetEndMs + 500),
                child: const _AllClearLine(),
              )
            else
              for (var i = 0; i < active.length; i++)
                _ConjuredLine(
                  key: ValueKey(active[i].id),
                  task: active[i],
                  sentence: sentenceFor(active[i], widget.lineFor(active[i])),
                  // This line's own 0→1 materialise window. Sequential: line i
                  // only starts once line i-1's window has closed.
                  progress: _win(_itemStart(i), _itemStart(i) + _itemRevealMs),
                  onTap: () => widget.onOpen(active[i]),
                  onLongPress: () => _showActions(active[i]),
                  onDone: () => _complete(active[i]),
                ),

            // Completed items — crossed off, in place, below the active ones.
            // No header, no count, no expand: just the struck-through lines.
            for (final t in done)
              _DoneLine(
                key: ValueKey('done-${t.id}'),
                task: t,
                sentence: sentenceFor(t, widget.lineFor(t)),
                onRestore: () => _restore(t),
                onTap: () => widget.onOpen(t),
                onLongPress: () => _showActions(t),
              ),
          ],
        );
      },
    );
  }
}

/// A completed reminder, CROSSED OFF in place — the same line as when it was
/// active (icon + its sentence), just struck through and dimmed, with a filled
/// check on the right. No separate section, no header, no count. Tap the check
/// to bring it back (mark undone); tap the row to open it.
class _DoneLine extends StatelessWidget {
  const _DoneLine({
    super.key,
    required this.task,
    required this.sentence,
    required this.onRestore,
    required this.onTap,
    required this.onLongPress,
  });

  /// The same unified sentence the line showed while active — now struck through.
  final String sentence;

  final Task task;
  final VoidCallback onRestore;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    // Same geometry as an active line so a completed one just "crosses off" in
    // place — the row doesn't jump or restyle beyond the strike + dim.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: 0.45,
                  child: _LineIcon(task: task),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    // The whole sentence, struck through + dimmed.
                    child: Text(
                      sentence,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkFaint,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.inkFaint,
                        decorationThickness: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filled check — tap to bring it back (mark undone).
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Tooltip(
                    message: 'Mark as not done',
                    child: GestureDetector(
                      onTap: onRestore,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 17, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two-tier greeting Revo says: a small, muted salutation ("Good evening,")
/// leading into the user's name — LARGE and painted with a violet→light
/// gradient so it reads as the hero of the screen, not an ordinary line. Both
/// tiers shimmer in word-by-word from the SAME [progress], so they materialise
/// together in sync with Revo's entrance.
class _Greeting extends StatefulWidget {
  const _Greeting({required this.greeting, required this.progress});

  /// The full line, e.g. "Good evening, Ranjeev".
  final String greeting;
  final double progress;

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting>
    with SingleTickerProviderStateMixin {
  // A slow perpetual loop that gives the settled sparkle its gentle breathing.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ONE clean line, ONE uniform ink colour — the whole "Good evening, Ranjeev"
    // shimmers in together, no gradient tint. A single special ✦ sparkle sits at
    // the end: it draws in as the line lands, then breathes gently forever, so
    // the greeting feels personal without any two-tone/colour-jump.
    final p = widget.progress;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: MagicText(
            text: widget.greeting,
            progress: p,
            style: const TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // The special sparkle — arrives with the tail of the line, then pulses.
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => _Sparkle(
              // Draw the sparkle in over the LAST slice of the line's reveal.
              arrive: Curves.easeOutBack
                  .transform(((p - 0.6) / 0.4).clamp(0.0, 1.0)),
              pulse: _pulse.value,
            ),
          ),
        ),
      ],
    );
  }
}

/// The user's NAME as the hero of the greeting: the gradient-filled, word-by-word
/// shimmering name, given a celebratory LANDING — it scales up with a springy
/// pop and blooms a soft violet glow as it settles — plus a personal ✦ sparkle
/// beside it that draws in on arrival and then gently, perpetually pulses. The
/// sparkle is what makes the name read as *yours*, not just text.
class _NameHero extends StatefulWidget {
  const _NameHero({required this.name, required this.progress});

  final String name;

  /// 0→1 across the NAME's slice of the greeting timeline (from _seg). Drives the
  /// shimmer + the landing pop/glow.
  final double progress;

  @override
  State<_NameHero> createState() => _NameHeroState();
}

class _NameHeroState extends State<_NameHero>
    with SingleTickerProviderStateMixin {
  // A slow, perpetual loop that gives the settled sparkle its gentle life.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    // Landing pop: a springy scale that overshoots ~1.05 then settles to 1.0 as
    // the name finishes arriving. easeOutBack gives the tasteful overshoot.
    final pop = 0.86 + 0.14 * Curves.easeOutBack.transform(p);
    // Glow blooms mid-arrival then fades to nothing once settled — a soft violet
    // halo behind the name, so it lands like it matters.
    final bloom = p >= 0.999 ? 0.0 : math.sin(p.clamp(0.0, 1.0) * math.pi);

    return Transform.scale(
      scale: pop,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.45 * bloom),
                    blurRadius: 26 * bloom,
                    spreadRadius: 1 * bloom,
                  ),
                ],
              ),
              child: ShaderMask(
                // Paint the materialising name with a violet→light sweep. The
                // mask recolours whatever MagicText draws, so the word-by-word
                // shimmer still plays underneath.
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEDE7FF), // near-white lavender
                    AppColors.accent, // vivid violet
                  ],
                ).createShader(rect),
                blendMode: BlendMode.srcIn,
                child: MagicText(
                  text: widget.name,
                  progress: widget.progress,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: Colors.white, // recoloured by the ShaderMask
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The personal ✦ sparkle — draws in as the name lands, then pulses.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => _Sparkle(
                arrive: Curves.easeOutBack
                    .transform(((p - 0.5) / 0.5).clamp(0.0, 1.0)),
                pulse: _pulse.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small four-point spark that scales/rotates IN as the name arrives, then
/// once settled breathes with a gentle scale + glow pulse. Pure paint — no
/// glyph font dependency, so it always renders crisp.
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.arrive, required this.pulse});

  /// 0→1 entrance as the name lands.
  final double arrive;

  /// 0→1 perpetual loop for the settled breathing.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    // [arrive] rides an easeOutBack curve upstream, so it can overshoot OUTSIDE
    // 0..1 (that's what gives the pop). Opacity + colour alpha must stay in
    // range, so clamp a dedicated fade value; the springy [arrive] still drives
    // the scale for the bouncy landing.
    final fade = arrive.clamp(0.0, 1.0);
    final breath = 0.5 - 0.5 * math.cos(pulse * 2 * math.pi); // 0..1..0
    final scale = (arrive * (1.0 + 0.08 * breath)).clamp(0.0, 2.0);
    final spin = (1 - fade) * 0.5; // a half-turn as it draws in
    final glow = ((0.35 + 0.65 * breath) * fade).clamp(0.0, 1.0);
    return Opacity(
      opacity: fade,
      child: Transform.rotate(
        angle: spin * math.pi,
        child: Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: const Size(18, 18),
            painter: _SparklePainter(glow: glow),
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.glow});
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // A four-point star: two crossed "diamonds" pinched at the centre.
    Path star(double scale) {
      final rr = r * scale;
      final w = rr * 0.30; // waist
      return Path()
        ..moveTo(c.dx, c.dy - rr)
        ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + rr, c.dy)
        ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + rr)
        ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - rr, c.dy)
        ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - rr)
        ..close();
    }

    // Soft glow underlay.
    if (glow > 0.01) {
      canvas.drawPath(
        star(1.15),
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.45 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * glow),
      );
    }
    // The bright spark, in the app accent → light gradient for a jewel feel.
    canvas.drawPath(
      star(1.0),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFEDE7FF), AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.glow != glow;
}

/// One reminder as Revo conjures it: a leading icon and a tick bloom in around
/// ONE unified sentence that MATERIALISES word by word. No name/subtitle split,
/// no chips — a single natural line ("Netflix's ₹649 slips out at 6pm — still
/// worth the binge?") that Revo appears to be thinking up. Settles into a plain,
/// tappable list row.
class _ConjuredLine extends StatelessWidget {
  const _ConjuredLine({
    super.key,
    required this.task,
    required this.sentence,
    required this.progress,
    required this.onTap,
    required this.onLongPress,
    required this.onDone,
  });

  final Task task;

  /// The single unified sentence to conjure (AI line or local fallback).
  final String sentence;

  /// 0→1 across THIS line's materialise window.
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tint = task.category.color;
    // The icon and tick bloom slightly AHEAD of the words settling, so the line
    // feels like it's being assembled: the vessel first, then the words fill in.
    final chrome = Curves.easeOut.transform((progress / 0.45).clamp(0.0, 1.0));
    final settled = progress >= 0.999;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: settled ? onTap : null,
          onLongPress: settled ? onLongPress : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading icon — fades/scales in first.
                Opacity(
                  opacity: chrome,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * chrome,
                    child: _LineIcon(task: task, tint: tint),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    // ONE unified sentence — written out left-to-right in
                    // reading order (reading mode), so it looks like it's being
                    // typed as your eye moves across it, not conjured in a
                    // scatter.
                    child: MagicText(
                      text: sentence,
                      progress: progress,
                      reading: true,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // The tick — appears only once the line has settled, so you
                // can't dismiss a thing that's still being written.
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: AnimatedOpacity(
                    opacity: settled ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: _TickButton(onDone: onDone, tint: tint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dismiss tick — a round outlined check that fills with the category tint
/// on press, then the parent removes the line.
class _TickButton extends StatefulWidget {
  const _TickButton({required this.onDone, required this.tint});
  final VoidCallback onDone;
  final Color tint;

  @override
  State<_TickButton> createState() => _TickButtonState();
}

class _TickButtonState extends State<_TickButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _pressed = true);
        Future.delayed(const Duration(milliseconds: 140), widget.onDone);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed ? widget.tint : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: _pressed ? widget.tint : AppColors.inkFaint,
            width: 1.6,
          ),
        ),
        child: Icon(
          Icons.check_rounded,
          size: 17,
          color: _pressed ? Colors.white : AppColors.inkFaint,
        ),
      ),
    );
  }
}

/// The leading icon — the real brand logo when the task carries one, else the
/// category glyph on a tile. The FALLBACK glyph uses ONE constant colour (the
/// app accent) for every category — no green-for-investment / red-for-bills
/// rainbow — so the icon column reads calm and uniform. (The [tint] is still
/// used elsewhere on the row, e.g. the tick; the fallback icon deliberately
/// ignores it.)
class _LineIcon extends StatelessWidget {
  const _LineIcon({required this.task, this.tint});
  final Task task;
  final Color? tint;

  /// The single, constant colour for every fallback category glyph.
  static const _iconColor = AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final hasBrand = (task.iconDomain ?? '').isNotEmpty;
    if (hasBrand) {
      return SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: BrandLogo(
            brand: Brand(name: task.title, domain: task.iconDomain!),
            size: 32,
            bare: true,
            circular: true,
          ),
        ),
      );
    }
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _iconColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(task.category.icon, size: 20, color: _iconColor),
    );
  }
}

/// The "nothing due" line — shown when today is clear (there may still be
/// upcoming items below, so this isn't the whole-app empty state).
class _AllClearLine extends StatelessWidget {
  const _AllClearLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.accent, size: 21),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Nothing due today — enjoy the calm.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Long-press action sheet (Edit / Delete) ──────────────────────────────────

enum _LineAction { edit, delete }

/// A small bottom sheet shown on long-press of a reminder line: the item's name,
/// then Edit and a destructive Delete. Frosted card styling to match the app.
class _LineActionSheet extends StatelessWidget {
  const _LineActionSheet({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            _ActionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              color: AppColors.ink,
              onTap: () => Navigator.pop(context, _LineAction.edit),
            ),
            const Divider(height: 1, color: AppColors.hairline, indent: 20, endIndent: 20),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: const Color(0xFFFF6B6B),
              onTap: () => Navigator.pop(context, _LineAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Derived copy: ONE conversational sentence per item ───────────────────────

/// The amount in the task's own currency — "₹119", "₹1,240". Empty if none.
String _amountPart(Task task) {
  final a = task.amount;
  if (a == null) return '';
  final cur = currencyOf(task.currency);
  final body = a == a.roundToDouble()
      ? formatAmount(a.round().toString(), cur.grouping)
      : a.toStringAsFixed(2);
  return '${cur.symbol}$body';
}

/// The ONE unified sentence to conjure for a reminder. Prefers the AI (Groq)
/// line the backend generated for today; when there's none (no key, offline,
/// or not generated yet) it falls back to a locally-built natural sentence that
/// still reads as one line, so the feed always looks intentional.
String sentenceFor(Task task, String? aiLine) {
  final ai = aiLine?.trim();
  if (ai != null && ai.isNotEmpty) return ai;
  return _localSentence(task);
}

/// A single, natural, TAILOR-MADE sentence woven from the item's name + amount
/// — never a generic "still worth it?", and deliberately WITHOUT any clock time
/// ("today" at most). This is the offline fallback for [sentenceFor].
String _localSentence(Task task) {
  final name = task.title.trim().isEmpty ? 'This' : task.title.trim();
  final amount = _amountPart(task);

  switch (task.category) {
    case TaskCategory.subscription:
      return amount.isNotEmpty
          ? '$name renews for $amount today — keep it, or cancel?'
          : '$name renews today — keep it, or cancel?';
    case TaskCategory.bills:
      return amount.isNotEmpty
          ? 'Pay $name\'s $amount today before it\'s late.'
          : 'Pay $name today before it\'s late.';
    case TaskCategory.insurance:
      return amount.isNotEmpty
          ? '$name renews for $amount today — stay covered.'
          : '$name renews today — stay covered.';
    case TaskCategory.investment:
      return amount.isNotEmpty
          ? 'Put $amount into $name today and keep compounding.'
          : 'Invest in $name today and keep compounding.';
    case TaskCategory.policies:
      if (amount.isNotEmpty && task.hasReturn && task.maturityAt != null) {
        return '$name\'s $amount premium is due — it matures ${task.maturityAt!.year}.';
      }
      return amount.isNotEmpty
          ? '$name\'s $amount premium is due today.'
          : '$name\'s premium is due today.';
    case TaskCategory.birthday:
      return 'It\'s $name today — send a little love.';
    case TaskCategory.medicine:
      return 'Time for your $name — stay on track.';
    case TaskCategory.other:
      return '$name is on today.';
  }
}
