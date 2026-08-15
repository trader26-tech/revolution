import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../tasks/data/task_store.dart';
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';

/// The Home COMMAND BOX — a CHAT you add reminders through. You type in plain
/// English and press Enter; your message appears as a bubble, Revo "thinks",
/// then replies with the parsed reminder as a card. Tap Add (or Enter) to
/// create it, and Revo confirms. The card only appears AFTER you send — never
/// live while typing.
class CommandBox extends StatefulWidget {
  const CommandBox({super.key, required this.store, required this.onAdded});

  final TaskStore store;

  /// Fired after a reminder is successfully created, so Home can refresh.
  final VoidCallback onAdded;

  @override
  State<CommandBox> createState() => _CommandBoxState();
}

class _CommandBoxState extends State<CommandBox> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// The conversation, oldest first.
  final List<_Msg> _messages = [];

  bool _busy = false; // parsing or saving in flight

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Enter pressed → send the typed message and ask Revo to parse it.
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    HapticFeedback.selectionClick();
    _controller.clear();
    setState(() {
      _messages.add(_Msg.user(text));
      _messages.add(_Msg.thinking());
      _busy = true;
    });
    _scrollToEnd();

    _Draft? draft;
    try {
      final res = await ApiClient.instance.post('/tasks/parse', {'text': text});
      if (res is Map && res['ok'] == true && res['draft'] is Map) {
        draft = _Draft.fromJson((res['draft'] as Map).cast<String, dynamic>());
      }
    } catch (_) {
      // fall through
    }
    draft ??= _Draft.raw(text); // offline / no parse → raw text as a reminder

    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.kind == _Kind.thinking);
      _messages.add(_Msg.card(draft!));
      _busy = false;
    });
    _scrollToEnd();
  }

  /// Confirm a card → create the reminder, then Revo confirms.
  Future<void> _confirm(_Msg msg) async {
    final draft = msg.draft;
    if (draft == null || _busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.store.add(
        draft.title,
        dueAt: draft.dueAt,
        repeat: draft.repeat,
        amount: draft.amount,
        currency: draft.currency ?? 'INR',
        category: draft.category,
        note: draft.note,
        doseTimes: draft.doseTimes,
        courseDays: draft.courseDays,
        repeatDays: draft.repeatDays,
      );
      if (!mounted) return;
      setState(() {
        msg.confirmed = true; // lock the card
        _messages.add(_Msg.done('Added “${draft.title}”'));
        _busy = false;
      });
      _scrollToEnd();
      widget.onAdded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't add — try again.")),
      );
    }
  }

  void _dismissCard(_Msg msg) {
    setState(() => _messages.remove(msg));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── The chat thread (only present once there's a conversation) ──
          if (_messages.isNotEmpty)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A tiny header with a "clear" so the thread never traps you.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 8, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Revora',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(_messages.clear),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: AppColors.inkFaint),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      controller: _scroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _MessageRow(
                        msg: _messages[i],
                        busy: _busy,
                        onConfirm: () => _confirm(_messages[i]),
                        onDismiss: () => _dismissCard(_messages[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── The always-open input. Enter sends. ──
          Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 44),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _focus.hasFocus
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : AppColors.cardBorder,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.auto_awesome_rounded,
                    size: 20, color: AppColors.accent.withValues(alpha: 0.9)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onTap: () => setState(() {}),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Add a reminder — just type it…',
                      hintStyle: TextStyle(color: AppColors.inkFaint),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                      isDense: true,
                    ),
                  ),
                ),
                _SendButton(busy: _busy, onTap: _send),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The send control — a spinner while busy, else an accent send arrow.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, color: AppColors.accent),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(6),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_upward_rounded,
            size: 20, color: Colors.white),
      ),
    );
  }
}

// ── Messages ─────────────────────────────────────────────────────────────────

enum _Kind { user, thinking, card, done }

class _Msg {
  _Msg.user(this.text)
      : kind = _Kind.user,
        draft = null;
  _Msg.thinking()
      : kind = _Kind.thinking,
        text = '',
        draft = null;
  _Msg.card(this.draft)
      : kind = _Kind.card,
        text = '';
  _Msg.done(this.text)
      : kind = _Kind.done,
        draft = null;

  final _Kind kind;
  final String text;
  final _Draft? draft;

  /// Once added, the card locks (no more Add/dismiss).
  bool confirmed = false;
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.msg,
    required this.busy,
    required this.onConfirm,
    required this.onDismiss,
  });

  final _Msg msg;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    switch (msg.kind) {
      case _Kind.user:
        return _UserBubble(text: msg.text);
      case _Kind.thinking:
        return const _ThinkingBubble();
      case _Kind.done:
        return _DoneBubble(text: msg.text);
      case _Kind.card:
        return _ReplyCard(
          draft: msg.draft!,
          confirmed: msg.confirmed,
          busy: busy,
          onConfirm: onConfirm,
          onDismiss: onDismiss,
        );
    }
  }
}

/// The user's own message — an accent bubble on the RIGHT.
class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(40, 4, 4, 4),
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

/// Revo's "typing…" indicator — three pulsing dots on the LEFT.
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
        margin: const EdgeInsets.fromLTRB(4, 4, 40, 4),
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

/// A small "✓ Added" confirmation from Revo.
class _DoneBubble extends StatelessWidget {
  const _DoneBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 4, 40, 4),
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

/// Revo's reply: the parsed reminder as a card, with Add + dismiss. Locks once
/// confirmed.
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.draft,
    required this.confirmed,
    required this.busy,
    required this.onConfirm,
    required this.onDismiss,
  });

  final _Draft draft;
  final bool confirmed;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cat = draft.categoryEnum;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 4, 24, 6),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                      ],
                    ),
                  ),
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
                          side: const BorderSide(color: AppColors.cardBorder),
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

  String _money(_Draft d) {
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

/// The parsed draft, mapped onto the app's types.
class _Draft {
  _Draft({
    required this.title,
    required this.category,
    this.amount,
    this.currency,
    this.dueAt,
    this.repeat = RepeatCadence.none,
    this.note,
    this.doseTimes = const [],
    this.courseDays,
    this.repeatDays = const [],
  });

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

  factory _Draft.raw(String text) => _Draft(title: text, category: 'other');

  factory _Draft.fromJson(Map<String, dynamic> j) {
    return _Draft(
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
    );
  }

  TaskCategory get categoryEnum => TaskCategory.values.firstWhere(
        (c) => c.name == category,
        orElse: () => TaskCategory.other,
      );
}
