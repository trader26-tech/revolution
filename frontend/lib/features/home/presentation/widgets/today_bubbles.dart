import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../onboarding/presentation/widgets/magic_text.dart'
    show MagicText, RevoEntrance;
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

  // Intro (Revo + greeting), then a beat, then the items — deliberately SLOW so
  // the effort is visible.
  static const _revoMs = 460;
  static const _greetStartMs = 620;
  static const _greetEndMs = 1500;
  static const _firstItemMs = 1850;

  /// How long ONE reminder takes to fully materialise, and the gap before the
  /// next starts. Slow on purpose — the shimmer should visibly sweep across the
  /// line word by word, not flash past. This paces that reading sweep.
  static const _itemRevealMs = 1500;
  static const _itemGapMs = 300;
  static const _itemStrideMs = _itemRevealMs + _itemGapMs;

  /// Whether the "Done today" section is expanded. Collapsed by default so
  /// finished items don't compete with what's still to do.
  bool _doneOpen = false;

  List<Task> get _active => widget.tasks;
  List<Task> get _done => widget.doneTasks;

  int get _totalMs =>
      _firstItemMs +
      (_active.isEmpty ? 0 : (_active.length - 1) * _itemStrideMs) +
      _itemRevealMs;

  double get _ms => _run.value * _totalMs;

  @override
  void initState() {
    super.initState();
    _run = AnimationController(vsync: this, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _run.duration = Duration(milliseconds: _totalMs);
      _run.forward();
    });
  }

  @override
  void didUpdateWidget(covariant TodayBubbles old) {
    super.didUpdateWidget(old);
    // Home became visible again → conjure it all over, from empty.
    if (widget.replayTick != old.replayTick) {
      _run.duration = Duration(milliseconds: _totalMs);
      _run.forward(from: 0);
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
            // ── Revo + the greeting, materialising word by word ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: RevoEntrance(
                      t: _win(0, _revoMs),
                      child: Transform.flip(
                        flipX: true,
                        child: const AnimatedMascot(size: 52, glow: false),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _Greeting(
                        greeting: widget.greeting,
                        progress: _win(_greetStartMs, _greetEndMs),
                      ),
                    ),
                  ),
                ],
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

            // ── Active reminders — conjured ONE AT A TIME ──
            if (active.isEmpty)
              Opacity(
                opacity: _win(_greetEndMs, _greetEndMs + 500),
                child: _AllClearLine(allDone: done.isNotEmpty),
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
                  onDone: () => _complete(active[i]),
                ),

            // ── "Done today" — everything you've ticked, tap to bring back ──
            if (done.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DoneSection(
                tasks: done,
                open: _doneOpen,
                onToggleOpen: () => setState(() => _doneOpen = !_doneOpen),
                onRestore: _restore,
                onOpen: widget.onOpen,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The "Done today" group — a tappable header with a count, and (when open) the
/// finished reminders, each struck-through with a filled check you tap to bring
/// it back to active. The list expands/collapses with a smooth size+fade so it
/// never feels like content pops in.
class _DoneSection extends StatelessWidget {
  const _DoneSection({
    required this.tasks,
    required this.open,
    required this.onToggleOpen,
    required this.onRestore,
    required this.onOpen,
  });

  final List<Task> tasks;
  final bool open;
  final VoidCallback onToggleOpen;
  final ValueChanged<Task> onRestore;
  final ValueChanged<Task> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row — "Done today · N", with a rotating chevron.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleOpen,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Done today',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // The items — animated open/closed.
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: open
                ? Column(
                    children: [
                      const SizedBox(height: 2),
                      for (final t in tasks)
                        _DoneLine(
                          key: ValueKey('done-${t.id}'),
                          task: t,
                          onRestore: () => onRestore(t),
                          onTap: () => onOpen(t),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

/// One finished reminder: its name struck through and dimmed, with a FILLED
/// check on the right. Tapping the check restores it (marks undone); tapping the
/// row opens it. Reads as clearly "handled" without shouting.
class _DoneLine extends StatelessWidget {
  const _DoneLine({
    super.key,
    required this.task,
    required this.onRestore,
    required this.onTap,
  });

  final Task task;
  final VoidCallback onRestore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = task.category.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Opacity(
                  opacity: 0.5,
                  child: _LineIcon(task: task, tint: tint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkFaint,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.inkFaint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filled check — tap to restore (mark undone). Tooltip spells it
                // out so the affordance is unmistakable.
                Tooltip(
                  message: 'Mark as not done',
                  child: GestureDetector(
                    onTap: onRestore,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 17, color: Colors.white),
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
class _Greeting extends StatelessWidget {
  const _Greeting({required this.greeting, required this.progress});

  /// The full line, e.g. "Good evening, Ranjeev". Split at the comma into the
  /// salutation and the name; if there's no comma (name unknown) we show just
  /// the salutation, styled as the hero.
  final String greeting;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final comma = greeting.indexOf(',');
    final hasName = comma >= 0 && comma < greeting.length - 1;
    final salutation =
        hasName ? greeting.substring(0, comma).trim() : greeting.trim();
    final name = hasName ? greeting.substring(comma + 1).trim() : '';

    // Read the greeting IN ORDER while KEEPING the bubbly shimmer (glow, haze,
    // float) on every word: the salutation ("Good morning,") materialises first
    // across the FRONT of the window, THEN the name ("Ranjeev") across the BACK
    // — with a slight overlap so it flows. Default (shimmer) MagicText already
    // starts its words left-to-right; sequencing the two TIERS this way is what
    // makes the whole line land as "Good morning," → "Ranjeev" in order, instead
    // of the name flashing in alongside the salutation.
    final salProgress = _seg(progress, 0.0, 0.58);
    final nameProgress = _seg(progress, 0.42, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Tier 1: the quiet salutation (reveals first) ──
        MagicText(
          text: hasName ? '$salutation,' : salutation,
          progress: hasName ? salProgress : progress,
          style: TextStyle(
            fontSize: hasName ? 16 : 30,
            height: 1.1,
            fontWeight: hasName ? FontWeight.w600 : FontWeight.w800,
            letterSpacing: 0.2,
            color: AppColors.inkSoft,
          ),
        ),
        // ── Tier 2: the name — big, gradient-filled, the hero (reveals after) ──
        if (hasName) ...[
          const SizedBox(height: 2),
          ShaderMask(
            // Paint the materialising name with a violet→light sweep. The mask
            // recolours whatever MagicText draws, so the word-by-word shimmer
            // still plays underneath.
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
              text: name,
              progress: nameProgress,
              style: const TextStyle(
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: Colors.white, // recoloured by the ShaderMask
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Remap the overall [progress] onto a sub-window [start, end], clamped to
  /// 0..1 — so one tier can run over the front of the timeline and the next over
  /// the back, giving a strict salutation-then-name reading order.
  static double _seg(double progress, double start, double end) =>
      ((progress - start) / (end - start)).clamp(0.0, 1.0);
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
    required this.onDone,
  });

  final Task task;

  /// The single unified sentence to conjure (AI line or local fallback).
  final String sentence;

  /// 0→1 across THIS line's materialise window.
  final double progress;
  final VoidCallback onTap;
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
/// category glyph on a tinted tile.
class _LineIcon extends StatelessWidget {
  const _LineIcon({required this.task, required this.tint});
  final Task task;
  final Color tint;

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
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(task.category.icon, size: 20, color: tint),
    );
  }
}

/// The "nothing due" line — shown when today is clear (there may still be
/// upcoming items below, so this isn't the whole-app empty state).
class _AllClearLine extends StatelessWidget {
  const _AllClearLine({this.allDone = false});

  /// True when the list is empty because everything was TICKED (vs. nothing was
  /// due at all) — so the message can celebrate rather than say "nothing here".
  final bool allDone;

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
          Expanded(
            child: Text(
              allDone
                  ? 'All done for today — nicely handled.'
                  : 'Nothing due today — enjoy the calm.',
              style: const TextStyle(
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
    case TaskCategory.other:
      return '$name is on today.';
  }
}
