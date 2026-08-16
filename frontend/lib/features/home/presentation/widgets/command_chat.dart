import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../onboarding/presentation/widgets/magic_text.dart' show MagicText;
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';
import 'interactive_flow.dart';

/// The command CHAT — the model + message widgets rendered INSIDE the Home feed
/// (not a floating box). The user's typed line, Revo's "thinking" shimmer, the
/// parsed reminder card, and the "added" confirmation all live here so they
/// attach to the page and scroll with it. The input bar itself lives separately
/// (command_input.dart), pinned at the bottom.

enum ChatKind {
  user,
  thinking,
  proposal,
  action,
  picker,
  answer,
  done,
  // ── The deterministic (no-LLM) command assistant ──
  /// The root Create/Read/Update/Delete option chips.
  menu,
  /// A create-in-progress (category → fields → confirm), all on one card.
  create,
  /// A short "coming soon" reply for Read/Update/Delete.
  comingSoon,
}

/// One message in the command chat.
class ChatMsg {
  ChatMsg.user(this.text)
      : kind = ChatKind.user,
        draft = null,
        task = null,
        flow = null,
        op = null,
        candidates = const [];
  ChatMsg.thinking()
      : kind = ChatKind.thinking,
        text = '',
        draft = null,
        task = null,
        flow = null,
        op = null,
        candidates = const [];
  /// A proposed ADD — shown as text + a tiny inline Add/Cancel.
  ChatMsg.proposal(this.draft)
      : kind = ChatKind.proposal,
        text = '',
        task = null,
        flow = null,
        op = null,
        candidates = const [];
  /// A complete/delete/update action on a resolved existing [task].
  ChatMsg.action(this.draft, this.task)
      : kind = ChatKind.action,
        text = '',
        flow = null,
        op = null,
        candidates = const [];
  /// Ambiguous match — pick which reminder from [candidates].
  ChatMsg.picker(this.draft, this.candidates)
      : kind = ChatKind.picker,
        text = '',
        task = null,
        flow = null,
        op = null;
  /// A QUERY answer — a header line + the matching reminders as text.
  ChatMsg.answer(this.text, this.candidates)
      : kind = ChatKind.answer,
        draft = null,
        task = null,
        flow = null,
        op = null;
  ChatMsg.done(this.text)
      : kind = ChatKind.done,
        draft = null,
        task = null,
        flow = null,
        op = null,
        candidates = const [];

  /// The root Create/Read/Update/Delete chips.
  ChatMsg.menu()
      : kind = ChatKind.menu,
        text = '',
        draft = null,
        task = null,
        flow = null,
        op = null,
        candidates = const [];

  /// A create-in-progress — [flow] carries the mutable step state.
  ChatMsg.create(this.flow)
      : kind = ChatKind.create,
        text = '',
        draft = null,
        task = null,
        op = null,
        candidates = const [];

  /// A "coming soon" reply for [op] (Read/Update/Delete).
  ChatMsg.comingSoon(this.op)
      : kind = ChatKind.comingSoon,
        text = '',
        draft = null,
        task = null,
        flow = null,
        candidates = const [];

  final ChatKind kind;
  final String text;
  final CommandDraft? draft;

  /// The resolved existing task for an action message.
  final Task? task;

  /// The mutable create-flow state, for a [ChatKind.create] message.
  final CreateFlow? flow;

  /// The operation a [ChatKind.comingSoon] message refers to.
  final FlowOp? op;

  /// Candidate tasks (picker) / answer items (query).
  final List<Task> candidates;

  /// Once acted on, the proposal/action locks (no more confirm/dismiss).
  bool confirmed = false;
}

/// The parsed reminder draft, mapped onto the app's types.
/// What the user wants to DO with a command.
enum CommandIntent { query, add, complete, delete, update }

/// The time window of a query.
enum CommandRange { today, tomorrow, week, month, overdue, all }

class CommandDraft {
  CommandDraft({
    required this.title,
    required this.category,
    this.intent = CommandIntent.add,
    this.range = CommandRange.all,
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

  /// query | add | complete | delete | update.
  final CommandIntent intent;

  /// The time window for a query.
  final CommandRange range;

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
        'query' => CommandIntent.query,
        'complete' => CommandIntent.complete,
        'delete' => CommandIntent.delete,
        'update' => CommandIntent.update,
        _ => CommandIntent.add,
      },
      range: switch ((j['range'] as String? ?? 'all').trim()) {
        'today' => CommandRange.today,
        'tomorrow' => CommandRange.tomorrow,
        'week' => CommandRange.week,
        'month' => CommandRange.month,
        'overdue' => CommandRange.overdue,
        _ => CommandRange.all,
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

// ── Message rendering — text-first, shimmering, minimal chrome ────────────────

/// Renders one chat message. [shimmer] (0→1) drives the MagicText reveal so
/// Revo's reply materialises exactly like the today to-do lines. Replies are
/// plain conversational text; only add/action carry a tiny inline confirm.
class CommandMessage extends StatelessWidget {
  const CommandMessage({
    super.key,
    required this.msg,
    required this.shimmer,
    required this.busy,
    required this.onConfirm,
    required this.onDismiss,
    required this.onPick,
    required this.onPickOp,
    required this.onPickCategory,
    required this.onDocument,
    required this.onAnswerField,
    required this.onEditField,
  });

  final ChatMsg msg;
  final double shimmer;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  final ValueChanged<Task> onPick;

  /// Root menu → the user picked Create/Read/Update/Delete.
  final ValueChanged<FlowOp> onPickOp;

  /// Create flow → the user picked a category.
  final ValueChanged<TaskCategory> onPickCategory;

  /// Create flow → the user picked "Document" (opens the add-document sheet).
  final VoidCallback onDocument;

  /// Create flow → the user answered (or skipped) the current field.
  final void Function(String key, Object? value) onAnswerField;

  /// Create flow → the user tapped a confirm-card row to re-ask that field.
  final ValueChanged<int> onEditField;

  @override
  Widget build(BuildContext context) {
    switch (msg.kind) {
      case ChatKind.user:
        return _UserLine(text: msg.text);
      case ChatKind.thinking:
        return const _ThinkingLine();
      case ChatKind.done:
        return _RevoText(text: msg.text, shimmer: shimmer, leadingCheck: true);
      case ChatKind.proposal:
        return _ProposalLine(
          draft: msg.draft!,
          confirmed: msg.confirmed,
          busy: busy,
          shimmer: shimmer,
          onConfirm: onConfirm,
          onDismiss: onDismiss,
        );
      case ChatKind.action:
        return _ActionLine(
          draft: msg.draft!,
          task: msg.task!,
          confirmed: msg.confirmed,
          busy: busy,
          shimmer: shimmer,
          onConfirm: onConfirm,
          onDismiss: onDismiss,
        );
      case ChatKind.picker:
        return _PickerLine(
          candidates: msg.candidates,
          shimmer: shimmer,
          onPick: onPick,
        );
      case ChatKind.answer:
        return _AnswerLine(
          header: msg.text,
          items: msg.candidates,
          shimmer: shimmer,
        );
      case ChatKind.menu:
        return MenuLine(shimmer: shimmer, onPick: onPickOp);
      case ChatKind.create:
        return CreateFlowLine(
          flow: msg.flow!,
          shimmer: shimmer,
          busy: busy,
          onPickCategory: onPickCategory,
          onDocument: onDocument,
          onAnswer: onAnswerField,
          onEditField: onEditField,
          onConfirm: onConfirm,
          onCancel: onDismiss,
        );
      case ChatKind.comingSoon:
        return ComingSoonLine(op: msg.op!, shimmer: shimmer);
    }
  }
}

/// The user's own line — a quiet right-aligned bubble (kept, so the thread reads
/// as a conversation), but small.
class _UserLine extends StatelessWidget {
  const _UserLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(56, 4, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(5),
          ),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Revo's typing indicator — three pulsing dots, left, no bubble chrome.
class _ThinkingLine extends StatefulWidget {
  const _ThinkingLine();
  @override
  State<_ThinkingLine> createState() => _ThinkingLineState();
}

class _ThinkingLineState extends State<_ThinkingLine>
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value + i * 0.2) % 1.0);
            final o = 0.3 + 0.7 * (1 - (2 * t - 1).abs());
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
        ),
      ),
    );
  }
}

/// A plain shimmering line of Revo text — the base for most replies. Same look
/// as the today to-do lines: no bubble, just conjured text (optional leading ✓).
class _RevoText extends StatelessWidget {
  const _RevoText({
    required this.text,
    required this.shimmer,
    this.leadingCheck = false,
  });
  final String text;
  final double shimmer;
  final bool leadingCheck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 24, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingCheck) ...[
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: MagicText(
              text: text,
              progress: shimmer,
              reading: true,
              style: const TextStyle(
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny inline confirm — "Add ✓ / Cancel ✗" pills under a reply line. Blooms
/// in as the shimmer finishes. [color]/[label] adapt to the action.
class _InlineConfirm extends StatelessWidget {
  const _InlineConfirm({
    required this.reveal,
    required this.busy,
    required this.label,
    required this.color,
    required this.onConfirm,
    required this.onDismiss,
  });
  final double reveal;
  final bool busy;
  final String label;
  final Color color;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (reveal < 0.01) return const SizedBox.shrink();
    return Opacity(
      opacity: reveal,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: busy ? null : onConfirm,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: busy ? null : onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A proposed ADD — a shimmering sentence + labelled detail lines (icons), then
/// the inline Add/Cancel. No boxed card.
class _ProposalLine extends StatelessWidget {
  const _ProposalLine({
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
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.5) / 0.5).clamp(0.0, 1.0));
    final line = draft.summary.isNotEmpty
        ? 'Add ${draft.title}?'
        : 'Add “${draft.title}”?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MagicText(
            text: line,
            progress: shimmer,
            reading: true,
            style: const TextStyle(
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          if (reveal > 0.01)
            Opacity(
              opacity: reveal,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _DetailLines(draft: draft),
              ),
            ),
          if (!confirmed)
            _InlineConfirm(
              reveal: reveal,
              busy: busy,
              label: 'Add',
              color: AppColors.accent,
              onConfirm: onConfirm,
              onDismiss: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// The parsed reminder's fields as clean LABELLED lines with icons — the
/// "clearly mention each tag & value" ask. Only shows fields that exist.
class _DetailLines extends StatelessWidget {
  const _DetailLines({required this.draft});
  final CommandDraft draft;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _row(draft.categoryEnum.icon, 'Category', draft.categoryEnum.label),
    ];
    if (draft.amount != null) {
      rows.add(_row(Icons.payments_outlined, 'Amount', _money(draft)));
    }
    if (draft.doseTimes.isNotEmpty) {
      rows.add(_row(Icons.medication_outlined, 'Doses',
          '${draft.doseTimes.length}× daily · ${draft.doseTimes.join(", ")}'));
    } else if (draft.repeat != RepeatCadence.none) {
      rows.add(_row(Icons.repeat_rounded, 'Repeats',
          frequencyLabel(draft.repeat, 1)));
    }
    if (draft.courseDays != null) {
      rows.add(_row(Icons.event_available_outlined, 'For',
          '${draft.courseDays} days'));
    }
    if (draft.dueAt != null) {
      rows.add(_row(Icons.calendar_today_rounded, 'When',
          _dateLabel(draft.dueAt!)));
    }
    if ((draft.note ?? '').isNotEmpty) {
      rows.add(_row(Icons.sticky_note_2_outlined, 'Note', draft.note!));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.accent.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          SizedBox(
            width: 66,
            child: Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.inkFaint)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ),
        ],
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
}

/// A complete/delete/update action — a shimmering sentence naming the exact
/// reminder, then an action-coloured inline confirm (red for delete).
class _ActionLine extends StatelessWidget {
  const _ActionLine({
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

  @override
  Widget build(BuildContext context) {
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.5) / 0.5).clamp(0.0, 1.0));
    final destructive = draft.intent == CommandIntent.delete;
    final color = destructive ? const Color(0xFFFF6B6B) : AppColors.accent;
    final (String verb, String label) = switch (draft.intent) {
      CommandIntent.delete => ('Delete', 'Delete'),
      CommandIntent.complete => ('Mark done', 'Done'),
      CommandIntent.update => ('Update', 'Save'),
      _ => ('Add', 'Add'),
    };
    final line = '$verb “${task.title}”?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MagicText(
            text: line,
            progress: shimmer,
            reading: true,
            style: const TextStyle(
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          // For update, show what's changing.
          if (draft.intent == CommandIntent.update && reveal > 0.01)
            Opacity(
              opacity: reveal,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _DetailLines(draft: draft),
              ),
            ),
          if (!confirmed)
            _InlineConfirm(
              reveal: reveal,
              busy: busy,
              label: label,
              color: color,
              onConfirm: onConfirm,
              onDismiss: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// Ambiguous match — "Which one?" then the candidate reminders as tappable
/// shimmering lines (icon · name).
class _PickerLine extends StatelessWidget {
  const _PickerLine({
    required this.candidates,
    required this.shimmer,
    required this.onPick,
  });
  final List<Task> candidates;
  final double shimmer;
  final ValueChanged<Task> onPick;

  @override
  Widget build(BuildContext context) {
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.4) / 0.6).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MagicText(
            text: 'Which one?',
            progress: shimmer,
            reading: true,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          if (reveal > 0.01)
            Opacity(
              opacity: reveal,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    for (final t in candidates)
                      GestureDetector(
                        onTap: () => onPick(t),
                        behavior: HitTestBehavior.opaque,
                        child: _ReminderRow(task: t, tappable: true),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A QUERY answer — a shimmering header ("3 things this week"), then the
/// matching reminders as text lines grouped by day. No cards.
class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.header,
    required this.items,
    required this.shimmer,
  });
  final String header;
  final List<Task> items;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.35) / 0.65).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MagicText(
            text: header,
            progress: shimmer,
            reading: true,
            style: const TextStyle(
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          if (reveal > 0.01)
            Opacity(
              opacity: reveal,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in items) _ReminderRow(task: t),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One reminder as a compact TEXT line (not a card): tinted icon · name · a
/// muted meta tail (when · amount). Used by query answers + the picker.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.task, this.tappable = false});
  final Task task;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(task.category.icon, size: 17, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: task.title,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink),
                  ),
                  if (_meta(task).isNotEmpty)
                    TextSpan(
                      text: '   ${_meta(task)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft),
                    ),
                ],
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

  String _meta(Task t) {
    final bits = <String>[];
    if (t.dueAt != null) bits.add(_dateLabel(t.dueAt!));
    if (t.amount != null) {
      final cur = currencyOf(t.currency);
      final a = t.amount!;
      final body = a == a.roundToDouble()
          ? formatAmount(a.round().toString(), cur.grouping)
          : a.toStringAsFixed(2);
      bits.add('${cur.symbol}$body');
    }
    return bits.join('  ·  ');
  }
}

/// "Today" / "Tomorrow" / "Fri 22 Aug" (+ time when set) — shared by the reply
/// widgets above.
String _dateLabel(DateTime d) {
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
    'Oct', 'Nov', 'Dec'];
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  } else if (diff > 1 && diff < 7) {
    base = wd[day.weekday - 1];
  } else {
    base = '${wd[day.weekday - 1]} ${d.day} ${mo[d.month - 1]}';
  }
  if (!hasTime) return base;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  return '$base · $h$m $ampm';
}
