import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../onboarding/presentation/widgets/magic_text.dart' show MagicText;
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';

/// The command CHAT — the model + message widgets rendered INSIDE the Home feed
/// (not a floating box). The user's typed line, Revo's "thinking" shimmer, the
/// parsed reminder card, and the "added" confirmation all live here so they
/// attach to the page and scroll with it. The input bar itself lives separately
/// (command_input.dart), pinned at the bottom.

enum ChatKind { user, thinking, card, action, picker, done }

/// One message in the command chat.
class ChatMsg {
  ChatMsg.user(this.text)
      : kind = ChatKind.user,
        draft = null,
        task = null,
        candidates = const [];
  ChatMsg.thinking()
      : kind = ChatKind.thinking,
        text = '',
        draft = null,
        task = null,
        candidates = const [];
  ChatMsg.card(this.draft)
      : kind = ChatKind.card,
        text = '',
        task = null,
        candidates = const [];
  /// A complete/delete/update action on a resolved existing [task].
  ChatMsg.action(this.draft, this.task)
      : kind = ChatKind.action,
        text = '',
        candidates = const [];
  /// Ambiguous match — pick which reminder from [candidates].
  ChatMsg.picker(this.draft, this.candidates)
      : kind = ChatKind.picker,
        text = '',
        task = null;
  ChatMsg.done(this.text)
      : kind = ChatKind.done,
        draft = null,
        task = null,
        candidates = const [];

  final ChatKind kind;
  final String text;
  final CommandDraft? draft;

  /// The resolved existing task for an action message.
  final Task? task;

  /// Candidate tasks for a picker message.
  final List<Task> candidates;

  /// Once acted on, the card locks (no more confirm/dismiss).
  bool confirmed = false;
}

/// The parsed reminder draft, mapped onto the app's types.
/// What the user wants to DO with a command.
enum CommandIntent { add, complete, delete, update }

class CommandDraft {
  CommandDraft({
    required this.title,
    required this.category,
    this.intent = CommandIntent.add,
    this.target,
    this.amount,
    this.currency,
    this.dueAt,
    this.repeat = RepeatCadence.none,
    this.note,
    this.doseTimes = const [],
    this.courseDays,
    this.repeatDays = const [],
    this.summary = '',
  });

  /// add | complete | delete | update.
  final CommandIntent intent;

  /// For non-add: key words naming the existing reminder to act on.
  final String? target;

  final String title;
  final String category;
  final double? amount;
  final String? currency;
  final DateTime? dueAt;
  final RepeatCadence repeat;
  final String? note;
  final List<String> doseTimes;
  final int? courseDays;
  final List<int> repeatDays;

  /// A short human line describing what Revo understood — the shimmer reply.
  final String summary;

  factory CommandDraft.raw(String text) =>
      CommandDraft(title: text, category: 'other', summary: 'Add "$text"');

  factory CommandDraft.fromJson(Map<String, dynamic> j) {
    return CommandDraft(
      intent: switch ((j['intent'] as String? ?? 'add').trim()) {
        'complete' => CommandIntent.complete,
        'delete' => CommandIntent.delete,
        'update' => CommandIntent.update,
        _ => CommandIntent.add,
      },
      target: (j['target'] as String?)?.trim(),
      title: (j['title'] as String? ?? '').trim(),
      category: (j['category'] as String? ?? 'other').trim(),
      amount: (j['amount'] as num?)?.toDouble(),
      currency: j['currency'] as String?,
      dueAt: j['due_at'] == null
          ? null
          : DateTime.tryParse(j['due_at'] as String),
      repeat: RepeatCadence.values.firstWhere(
        (r) => r.name == (j['repeat'] as String? ?? 'none'),
        orElse: () => RepeatCadence.none,
      ),
      note: j['note'] as String?,
      doseTimes: (j['dose_times'] as List?)?.cast<String>() ?? const [],
      courseDays: (j['course_days'] as num?)?.toInt(),
      repeatDays: (j['repeat_days'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      summary: (j['summary'] as String? ?? '').trim(),
    );
  }

  TaskCategory get categoryEnum => TaskCategory.values.firstWhere(
        (c) => c.name == category,
        orElse: () => TaskCategory.other,
      );
}

/// Renders one chat message. [shimmer] (0→1) drives the MagicText reveal on the
/// card's summary line, so Revo's reply materialises like it's being written.
class CommandMessage extends StatelessWidget {
  const CommandMessage({
    super.key,
    required this.msg,
    required this.shimmer,
    required this.busy,
    required this.onConfirm,
    required this.onDismiss,
    required this.onPick,
  });

  final ChatMsg msg;
  final double shimmer;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  /// Pick a specific task from a picker message.
  final ValueChanged<Task> onPick;

  @override
  Widget build(BuildContext context) {
    switch (msg.kind) {
      case ChatKind.user:
        return _UserBubble(text: msg.text);
      case ChatKind.thinking:
        return const _ThinkingBubble();
      case ChatKind.done:
        return _DoneBubble(text: msg.text);
      case ChatKind.card:
        return _ReplyCard(
          draft: msg.draft!,
          confirmed: msg.confirmed,
          busy: busy,
          shimmer: shimmer,
          onConfirm: onConfirm,
          onDismiss: onDismiss,
        );
      case ChatKind.action:
        return _ActionCard(
          draft: msg.draft!,
          task: msg.task!,
          confirmed: msg.confirmed,
          busy: busy,
          shimmer: shimmer,
          onConfirm: onConfirm,
          onDismiss: onDismiss,
        );
      case ChatKind.picker:
        return _PickerCard(
          draft: msg.draft!,
          candidates: msg.candidates,
          shimmer: shimmer,
          onPick: onPick,
          onDismiss: onDismiss,
        );
    }
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(56, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 56, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_c.value + i * 0.2) % 1.0);
                final o = 0.35 + 0.65 * (1 - (2 * t - 1).abs());
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: o),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _DoneBubble extends StatelessWidget {
  const _DoneBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 56, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Revo's reply: the parsed reminder card. Its summary line materialises with
/// the SAME glass shimmer as the today-bubbles ([MagicText]); the detail chips +
/// Add button fade in as the shimmer completes.
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.draft,
    required this.confirmed,
    required this.busy,
    required this.shimmer,
    required this.onConfirm,
    required this.onDismiss,
  });

  final CommandDraft draft;
  final bool confirmed;
  final bool busy;
  final double shimmer;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cat = draft.categoryEnum;
    // The chips + actions bloom in as the shimmer line finishes writing.
    final reveal = Curves.easeOut.transform(((shimmer - 0.55) / 0.45).clamp(0.0, 1.0));
    final line = draft.summary.isNotEmpty
        ? draft.summary
        : draft.title;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 32, 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withValues(alpha: confirmed ? 0.06 : 0.14),
              AppColors.card,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: confirmed
                ? AppColors.cardBorder
                : AppColors.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Opacity(
          opacity: confirmed ? 0.6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(cat.icon, size: 20, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      // The reply line, conjured word-by-word with the shimmer.
                      child: MagicText(
                        text: line,
                        progress: shimmer,
                        reading: true,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Chips + actions appear as the line settles.
              if (reveal > 0.01)
                Opacity(
                  opacity: reveal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(cat.label),
                          if (draft.amount != null) _chip(_money(draft)),
                          if (draft.doseTimes.isNotEmpty)
                            _chip(_doseLabel(draft.doseTimes))
                          else if (draft.repeat != RepeatCadence.none)
                            _chip(frequencyLabel(draft.repeat, 1)),
                          if (draft.courseDays != null)
                            _chip('${draft.courseDays} days'),
                          if (draft.dueAt != null)
                            _chip(_dateLabel(draft.dueAt!)),
                          if ((draft.note ?? '').isNotEmpty)
                            _chip('“${draft.note}”', muted: true),
                        ],
                      ),
                      if (!confirmed) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: FilledButton(
                                  onPressed: busy ? null : onConfirm,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  child: const Text('Add reminder',
                                      style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 42,
                              width: 42,
                              child: OutlinedButton(
                                onPressed: busy ? null : onDismiss,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(
                                      color: AppColors.cardBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 18, color: AppColors.inkSoft),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, {bool muted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.inkSoft : AppColors.ink,
        ),
      ),
    );
  }

  String _money(CommandDraft d) {
    final cur = currencyOf(d.currency ?? 'INR');
    final a = d.amount!;
    final body = a == a.roundToDouble()
        ? formatAmount(a.round().toString(), cur.grouping)
        : a.toStringAsFixed(2);
    return '${cur.symbol}$body';
  }

  static String _doseLabel(List<String> times) {
    final n = times.length;
    return n == 1 ? 'Once daily' : '$n× daily';
  }

  static String _dateLabel(DateTime d) {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final hasTime = !(d.hour == 0 && d.minute == 0);
    String base;
    if (diff == 0) {
      base = 'Today';
    } else if (diff == 1) {
      base = 'Tomorrow';
    } else {
      base = '${d.day} ${mo[d.month - 1]}';
    }
    if (!hasTime) return base;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
    return '$base · $h$m $ampm';
  }
}

/// A complete / delete / update action on a resolved existing task — always
/// confirmed. The summary shimmers in; the target reminder is named clearly, and
/// the confirm button's colour/label matches the action (red for delete).
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.draft,
    required this.task,
    required this.confirmed,
    required this.busy,
    required this.shimmer,
    required this.onConfirm,
    required this.onDismiss,
  });

  final CommandDraft draft;
  final Task task;
  final bool confirmed;
  final bool busy;
  final double shimmer;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  bool get _destructive => draft.intent == CommandIntent.delete;

  @override
  Widget build(BuildContext context) {
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.55) / 0.45).clamp(0.0, 1.0));
    final actionColor =
        _destructive ? const Color(0xFFFF6B6B) : AppColors.accent;
    final label = switch (draft.intent) {
      CommandIntent.delete => 'Delete',
      CommandIntent.complete => 'Mark done',
      CommandIntent.update => 'Save change',
      CommandIntent.add => 'Add',
    };
    final icon = switch (draft.intent) {
      CommandIntent.delete => Icons.delete_outline_rounded,
      CommandIntent.complete => Icons.check_circle_outline_rounded,
      CommandIntent.update => Icons.edit_outlined,
      CommandIntent.add => Icons.add_rounded,
    };
    final line = draft.summary.isNotEmpty ? draft.summary : label;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 32, 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              actionColor.withValues(alpha: confirmed ? 0.05 : 0.13),
              AppColors.card,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: confirmed
                ? AppColors.cardBorder
                : actionColor.withValues(alpha: 0.4),
          ),
        ),
        child: Opacity(
          opacity: confirmed ? 0.6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 20, color: actionColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: MagicText(
                        text: line,
                        progress: shimmer,
                        reading: true,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (reveal > 0.01)
                Opacity(
                  opacity: reveal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // The exact target reminder, so it's unmistakable.
                      _TaskChip(task: task),
                      if (!confirmed) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: FilledButton.icon(
                                  onPressed: busy ? null : onConfirm,
                                  icon: Icon(icon, size: 18),
                                  label: Text(label,
                                      style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: actionColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 42,
                              width: 42,
                              child: OutlinedButton(
                                onPressed: busy ? null : onDismiss,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(
                                      color: AppColors.cardBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 18, color: AppColors.inkSoft),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Which one?" — the ambiguous-match picker. Lists the candidate reminders as
/// tappable rows; picking one produces the confirm action card.
class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.draft,
    required this.candidates,
    required this.shimmer,
    required this.onPick,
    required this.onDismiss,
  });

  final CommandDraft draft;
  final List<Task> candidates;
  final double shimmer;
  final ValueChanged<Task> onPick;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 32, 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MagicText(
              text: 'Which one?',
              progress: shimmer,
              reading: true,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            for (final t in candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => onPick(t),
                  behavior: HitTestBehavior.opaque,
                  child: _TaskChip(task: t, tappable: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact row naming a resolved reminder — icon, title, a short meta line.
class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.task, this.tappable = false});
  final Task task;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(task.category.icon, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          if (tappable)
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
