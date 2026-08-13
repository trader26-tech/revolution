import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../onboarding/presentation/widgets/magic_text.dart'
    show MagicText, RevoEntrance;
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';

/// The Home hero: everything due TODAY, arriving as chat-style speech BUBBLES
/// that materialise one after another — the same shimmer-and-waterfall
/// choreography as onboarding pages 2 & 4. Revo greets from the top-left, his
/// line resolves word by word, then each reminder pops in on its own beat.
///
/// Every bubble reads like Revo talking to you about that one thing: the name,
/// a plain-English "when", and a derived nudge ("Is this AI copilot still worth
/// it, or cancel?"). A tick on the right dismisses it — the bubble shrinks away
/// and an "Done · Undo" toast lets you take it back.
class TodayBubbles extends StatefulWidget {
  const TodayBubbles({
    super.key,
    required this.greeting,
    required this.tasks,
    required this.onOpen,
    required this.onComplete,
    required this.onUndo,
  });

  /// The top line Revo says — "Good evening, Sanjeev".
  final String greeting;

  /// Everything due today, unfinished — soonest first.
  final List<Task> tasks;

  /// Tap a bubble → open its edit form.
  final ValueChanged<Task> onOpen;

  /// Tick a bubble → mark it done. Called AFTER the pop-away animation.
  final ValueChanged<Task> onComplete;

  /// Undo a just-completed task (from the toast).
  final ValueChanged<Task> onUndo;

  @override
  State<TodayBubbles> createState() => _TodayBubblesState();
}

class _TodayBubblesState extends State<TodayBubbles>
    with SingleTickerProviderStateMixin {
  // Absolute-millisecond waterfall, mirroring the onboarding cascade:
  //   0..500      Revo enters.  —— pause ——
  //   700..1500   the greeting MATERIALISES word by word (shimmer).
  //   1700        the sub-line fades in.
  //   1900+       each bubble pops in, one [_beatGap] after the last.
  late final AnimationController _intro;

  static const _revoMs = 500;
  static const _greetStartMs = 700;
  static const _greetEndMs = 1500;
  static const _subMs = 1700;
  static const _cascadeStartMs = 1900;
  static const _beatGap = 220;
  static const _beatWindow = 420;

  /// Tasks the user has ticked away this session — hidden with an exit
  /// animation, kept out of the list so the cascade below reflows up.
  final Set<String> _dismissed = {};

  List<Task> get _visible =>
      widget.tasks.where((t) => !_dismissed.contains(t.id)).toList();

  int get _totalMs =>
      _cascadeStartMs +
      ((widget.tasks.length - 1).clamp(0, 1 << 30)) * _beatGap +
      _beatWindow;

  double get _ms => _intro.value * _totalMs;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _intro.duration = Duration(milliseconds: _totalMs);
      _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  double _win(num startMs, num endMs) =>
      ((_ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

  Widget _reveal(num startMs, Widget child, {num window = _beatWindow}) {
    if (_intro.isCompleted) return child;
    final t = Curves.easeOutCubic.transform(_win(startMs, startMs + window));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    );
  }

  /// A bubble's springy pop-in on its beat.
  Widget _beatReveal(num startMs, Widget child) {
    if (_intro.isCompleted) return child;
    final raw = _win(startMs, startMs + _beatWindow);
    final ease = Curves.easeOutCubic.transform(raw);
    final spring = Curves.easeOutBack.transform(raw);
    return Opacity(
      opacity: ease,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - ease)),
        child: Transform.scale(
          scale: 0.86 + 0.14 * spring,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }

  void _dismiss(Task task) {
    HapticFeedback.mediumImpact();
    setState(() => _dismissed.add(task.id));
    widget.onComplete(task);
    // Show the undo toast; tapping Undo brings the bubble back.
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
      animation: _intro,
      builder: (context, _) {
        final visible = _visible;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Revo + the greeting, materialising word by word ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 2),
                    child: RevoEntrance(
                      t: _win(0, _revoMs),
                      child: Transform.flip(
                        flipX: true,
                        child: const AnimatedMascot(size: 54, glow: false),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MagicText(
                            text: widget.greeting,
                            progress: _win(_greetStartMs, _greetEndMs),
                            style: const TextStyle(
                              fontSize: 23,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _reveal(
                            _subMs,
                            Text(
                              _subline(visible.length),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── The bubbles — one per task due today ──
            if (visible.isEmpty)
              _reveal(_subMs, const _AllDoneBubble())
            else
              for (var i = 0; i < visible.length; i++)
                _beatReveal(
                  _cascadeStartMs + i * _beatGap,
                  _TaskBubble(
                    key: ValueKey(visible[i].id),
                    task: visible[i],
                    onTap: () => widget.onOpen(visible[i]),
                    onDone: () => _dismiss(visible[i]),
                  ),
                ),
          ],
        );
      },
    );
  }

  String _subline(int count) {
    if (count == 0) return "You're all caught up for today.";
    if (count == 1) return "One thing on your plate today.";
    return "$count things on your plate today.";
  }
}

/// One reminder, drawn as a speech bubble: a tail on the left (it's Revo
/// talking), the brand logo, the name, a plain-English "when", a derived nudge,
/// and a tick to dismiss it.
class _TaskBubble extends StatelessWidget {
  const _TaskBubble({
    super.key,
    required this.task,
    required this.onTap,
    required this.onDone,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tint = task.category.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The little tail that makes it read as a chat bubble.
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: CustomPaint(
              size: const Size(9, 14),
              painter: _TailPainter(color: AppColors.card),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BubbleIcon(task: task, tint: tint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _WhenPill(task: task, tint: tint),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // The derived nudge — Revo's take on this reminder.
                            Text(
                              bubbleInsight(task),
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _TickButton(onDone: onDone, tint: tint),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dismiss tick — a round outlined check that fills with the category tint
/// on press, then the parent animates the bubble away.
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
        // Let the fill flash before the bubble leaves.
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

/// A compact "when" chip — "6 PM", "Today", "Now".
class _WhenPill extends StatelessWidget {
  const _WhenPill({required this.task, required this.tint});
  final Task task;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final label = bubbleWhen(task);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: tint,
        ),
      ),
    );
  }
}

/// The leading icon — the real brand logo when the task carries one, else the
/// category glyph on a tinted tile.
class _BubbleIcon extends StatelessWidget {
  const _BubbleIcon({required this.task, required this.tint});
  final Task task;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final hasBrand = (task.iconDomain ?? '').isNotEmpty;
    if (hasBrand) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: BrandLogo(
            brand: Brand(name: task.title, domain: task.iconDomain!),
            size: 34,
            bare: true,
            circular: true,
          ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(task.category.icon, size: 21, color: tint),
    );
  }
}

/// The "all clear today" bubble — shown when nothing's due (but there are still
/// upcoming items below, so the home isn't the empty state).
class _AllDoneBubble extends StatelessWidget {
  const _AllDoneBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Nothing due today — enjoy the calm.',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chat-bubble tail (a small triangle) pointing left toward Revo.
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
    // Hairline edge to match the bubble border.
    final stroke = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height * 0.5)
        ..lineTo(size.width, size.height),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

// ── Derived copy: the "when" and the nudge ───────────────────────────────────

/// A short, human "when" for today's bubble pill. Everything here is due today,
/// so this is about the TIME of day (or "Now" if it's already past).
String bubbleWhen(Task task) {
  final due = task.dueAt;
  if (due == null) return 'Today';
  final now = DateTime.now();
  final atMidnight = due.hour == 0 && due.minute == 0;
  if (atMidnight) return 'Today';
  if (due.isBefore(now)) return 'Now';
  final h = due.hour % 12 == 0 ? 12 : due.hour % 12;
  final ampm = due.hour < 12 ? 'AM' : 'PM';
  final m = due.minute == 0
      ? ''
      : ':${due.minute.toString().padLeft(2, '0')}';
  return '$h$m $ampm';
}

/// Revo's one-line take on a reminder — a fuller, more conversational nudge than
/// the little card punches, derived from the task's category + sub-category. For
/// an AI subscription this reads "Is this AI copilot still worth it, or cancel?"
/// — exactly the kind of decision the home bubble should prompt.
String bubbleInsight(Task task) {
  final sub = (task.subCategory ?? '').toLowerCase();
  switch (task.category) {
    case TaskCategory.subscription:
      return switch (sub) {
        'ai' => 'Is this AI copilot still worth it, or cancel?',
        'entertainment' => 'Still watching enough to keep it?',
        'music' => 'Still on repeat, or let it go?',
        'cloud & tools' => 'Still using this enough to keep it?',
        'learning' => 'Still learning from it, or pause it?',
        'gaming' => 'Still playing, or cancel for now?',
        'food & shopping' => 'Perks still paying for themselves?',
        _ => 'Still worth keeping, or time to cancel?',
      };
    case TaskCategory.bills:
      return 'Due today — pay it to avoid a late fee.';
    case TaskCategory.insurance:
      return 'Renews today — keep your cover unbroken.';
    case TaskCategory.investment:
      return 'Invest today to keep compounding.';
    case TaskCategory.policies:
      return task.hasReturn
          ? 'Premium due — keep the return on track.'
          : 'Premium due today.';
    case TaskCategory.birthday:
      return 'A day worth remembering — reach out.';
    case TaskCategory.other:
      return 'On your list for today.';
  }
}
