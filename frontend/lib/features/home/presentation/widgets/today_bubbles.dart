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
    required this.onOpen,
    required this.onComplete,
    required this.onUndo,
  });

  /// Bumped by the parent whenever Home becomes visible again — a change here
  /// restarts the conjuring from empty, so returning to Home always re-plays it.
  final int replayTick;

  /// The top line Revo says — "Good evening, Sanjeev".
  final String greeting;

  /// Everything due today, unfinished — soonest first.
  final List<Task> tasks;

  /// Tap a settled line → open its edit form.
  final ValueChanged<Task> onOpen;

  /// Tick a line → mark it done. Called AFTER the pop-away animation.
  final ValueChanged<Task> onComplete;

  /// Undo a just-completed task (from the toast).
  final ValueChanged<Task> onUndo;

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
  /// next starts. Slow on purpose — this is the whole point of the effect.
  static const _itemRevealMs = 900;
  static const _itemGapMs = 260;
  static const _itemStrideMs = _itemRevealMs + _itemGapMs;

  /// Reminders the user ticked away this session — removed with an exit anim.
  final Set<String> _dismissed = {};

  List<Task> get _visible =>
      widget.tasks.where((t) => !_dismissed.contains(t.id)).toList();

  int get _totalMs =>
      _firstItemMs +
      (widget.tasks.isEmpty ? 0 : (widget.tasks.length - 1) * _itemStrideMs) +
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
      _dismissed.clear();
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

  void _dismiss(Task task) {
    HapticFeedback.mediumImpact();
    setState(() => _dismissed.add(task.id));
    widget.onComplete(task);
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
            setState(() => _dismissed.remove(task.id));
            widget.onUndo(task);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _run,
      builder: (context, _) {
        final visible = _visible;
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
            const SizedBox(height: 22),

            // ── The reminders — conjured ONE AT A TIME, then a clean list ──
            if (visible.isEmpty)
              Opacity(
                opacity: _win(_greetEndMs, _greetEndMs + 500),
                child: const _AllClearLine(),
              )
            else
              for (var i = 0; i < visible.length; i++)
                _ConjuredLine(
                  key: ValueKey(visible[i].id),
                  task: visible[i],
                  // This line's own 0→1 materialise window. Sequential: line i
                  // only starts once line i-1's window has closed.
                  progress: _win(_itemStart(i), _itemStart(i) + _itemRevealMs),
                  onTap: () => widget.onOpen(visible[i]),
                  onDone: () => _dismiss(visible[i]),
                ),
          ],
        );
      },
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Tier 1: the quiet salutation ──
        MagicText(
          text: hasName ? '$salutation,' : salutation,
          progress: progress,
          style: TextStyle(
            fontSize: hasName ? 16 : 30,
            height: 1.1,
            fontWeight: hasName ? FontWeight.w600 : FontWeight.w800,
            letterSpacing: 0.2,
            color: AppColors.inkSoft,
          ),
        ),
        // ── Tier 2: the name — big, gradient-filled, the hero ──
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
              progress: progress,
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
}

/// One reminder as Revo conjures it: a leading icon and a tick fade in around a
/// line of text that MATERIALISES word by word. No card chrome — it reads as
/// Revo carefully putting the thought on screen, then settling into a plain,
/// tappable list row.
class _ConjuredLine extends StatelessWidget {
  const _ConjuredLine({
    super.key,
    required this.task,
    required this.progress,
    required this.onTap,
    required this.onDone,
  });

  final Task task;

  /// 0→1 across THIS line's materialise window.
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tint = task.category.color;
    // The icon and tick bloom slightly AHEAD of the words settling, so the line
    // feels like it's being assembled: the vessel first, then the words fill in.
    final chrome = Curves.easeOut.transform((progress / 0.5).clamp(0.0, 1.0));
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      // The name — conjured word by word.
                      MagicText(
                        text: task.title,
                        progress: progress,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // ONE tailored meta line — built from this item's real
                      // name, sub-category and amount (e.g. "6 PM · ₹119 music",
                      // "matures 2034 · ₹8,400"). Fades in as the words finish,
                      // so the name lands first and its detail follows. Kept to
                      // a single ellipsised line so the screen never fills up.
                      Opacity(
                        opacity: Curves.easeOut
                            .transform((progress - 0.55).clamp(0.0, 0.45) / 0.45),
                        child: Text(
                          bubbleMeta(task),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: tint.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // The tick — appears only once the line has settled, so you
                // can't dismiss a thing that's still being written.
                Padding(
                  padding: const EdgeInsets.only(top: 2),
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

// ── Derived copy: ONE tailored meta line per item ────────────────────────────

/// The time of day the item is due — "6 PM" / "Now" / "" (blank if it's just a
/// whole-day reminder with no set time, so we don't print a meaningless "12 AM").
String _timePart(Task task) {
  final due = task.dueAt;
  if (due == null) return '';
  if (due.hour == 0 && due.minute == 0) return '';
  final now = DateTime.now();
  if (due.isBefore(now)) return 'Now';
  final h = due.hour % 12 == 0 ? 12 : due.hour % 12;
  final ampm = due.hour < 12 ? 'AM' : 'PM';
  final m = due.minute == 0 ? '' : ':${due.minute.toString().padLeft(2, '0')}';
  return '$h$m $ampm';
}

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

/// ONE short, TAILOR-MADE line for a reminder — assembled from this exact
/// item's real facts (time, amount, sub-category, maturity), never a generic
/// "still worth it?". Kept to at most a couple of dot-separated fragments so it
/// fits on a single line under the name and the screen stays uncluttered.
///
/// Examples: "6 PM · ₹119 · music"  ·  "₹1,240 · due today"  ·  "matures 2034"
String bubbleMeta(Task task) {
  final parts = <String>[];
  final time = _timePart(task);
  final amount = _amountPart(task);
  final sub = (task.subCategory ?? '').trim();

  switch (task.category) {
    case TaskCategory.subscription:
      // Brand + price + what it's for — e.g. "₹119 · music".
      if (amount.isNotEmpty) parts.add(amount);
      if (sub.isNotEmpty) parts.add(sub.toLowerCase());
      if (parts.isEmpty && time.isNotEmpty) parts.add(time);
    case TaskCategory.bills:
      if (amount.isNotEmpty) parts.add(amount);
      parts.add('due today');
    case TaskCategory.insurance:
      if (amount.isNotEmpty) parts.add(amount);
      parts.add('renews today');
    case TaskCategory.investment:
      if (amount.isNotEmpty) parts.add(amount);
      if (sub.isNotEmpty) parts.add(sub.toLowerCase());
      if (parts.isEmpty) parts.add('invest today');
    case TaskCategory.policies:
      if (amount.isNotEmpty) parts.add('$amount premium');
      if (task.hasReturn && task.maturityAt != null) {
        parts.add('matures ${task.maturityAt!.year}');
      }
      if (parts.isEmpty) parts.add('premium due');
    case TaskCategory.birthday:
      // People, not money — keep it warm and specific.
      if (time.isNotEmpty) parts.add(time);
      parts.add('their day');
    case TaskCategory.other:
      if (time.isNotEmpty) parts.add(time);
      if (parts.isEmpty) parts.add('today');
  }

  // Lead with the time for money items too, when there's room — one fragment.
  if (time.isNotEmpty &&
      !parts.contains(time) &&
      task.category != TaskCategory.birthday &&
      task.category != TaskCategory.other) {
    parts.insert(0, time);
  }

  // Never more than three fragments — keep it tight.
  return parts.take(3).join('  ·  ');
}
