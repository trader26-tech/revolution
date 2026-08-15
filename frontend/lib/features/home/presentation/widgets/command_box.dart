import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../tasks/data/task_store.dart';
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';

/// The Home COMMAND BOX — the primary way to add a reminder. The user types in
/// plain English ("Netflix 649 every month", "call mom on her birthday next
/// Tuesday"); the backend LLM parses it into a structured draft; a confirmation
/// card slides up right above the field showing what was understood; pressing
/// Enter / Add creates it. Always open, pinned above the keyboard.
class CommandBox extends StatefulWidget {
  const CommandBox({super.key, required this.store, required this.onAdded});

  final TaskStore store;

  /// Fired after a reminder is successfully created, so Home can refresh /
  /// celebrate.
  final VoidCallback onAdded;

  @override
  State<CommandBox> createState() => _CommandBoxState();
}

class _CommandBoxState extends State<CommandBox> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  bool _parsing = false;
  bool _saving = false;

  /// The current parsed draft (null until the user has typed enough + it parsed).
  _Draft? _draft;

  /// The text the current [_draft] was parsed from — so we don't re-show a stale
  /// card after the user keeps typing.
  String _draftFor = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final text = value.trim();
    _debounce?.cancel();
    if (text.length < 3) {
      setState(() {
        _draft = null;
        _parsing = false;
      });
      return;
    }
    // Debounce so we parse when the user pauses, not on every keystroke.
    setState(() => _parsing = true);
    _debounce = Timer(const Duration(milliseconds: 550), () => _parse(text));
  }

  Future<void> _parse(String text) async {
    try {
      final res = await ApiClient.instance.post('/tasks/parse', {'text': text});
      if (!mounted) return;
      if (res is Map && res['ok'] == true && res['draft'] is Map) {
        setState(() {
          _draft = _Draft.fromJson((res['draft'] as Map).cast<String, dynamic>());
          _draftFor = text;
          _parsing = false;
        });
        return;
      }
    } catch (_) {
      // fall through to the local fallback
    }
    if (!mounted) return;
    // Offline / no parse — still let them add the raw text as a plain reminder.
    setState(() {
      _draft = _Draft.raw(text);
      _draftFor = text;
      _parsing = false;
    });
  }

  Future<void> _confirm() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() => _saving = true);
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
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _draft = null;
        _saving = false;
        _draftFor = '';
      });
      _focus.unfocus();
      widget.onAdded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't add — try again.")),
      );
    }
  }

  void _dismissDraft() {
    setState(() {
      _draft = null;
      _draftFor = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final draft = _draft;
    // Only show the card if it still matches what's typed (avoids a stale card).
    final showCard = draft != null && _controller.text.trim() == _draftFor;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── The confirmation card, sliding up above the field ──
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: showCard
                ? _ConfirmCard(
                    draft: draft,
                    saving: _saving,
                    onConfirm: _confirm,
                    onDismiss: _dismissDraft,
                  )
                : const SizedBox(width: double.infinity),
          ),
          // ── The always-open text field ──
          // Extra bottom margin leaves room for the shell's small "Menu" handle
          // that sits at the very bottom-center, so they never overlap.
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
                    size: 20,
                    color: AppColors.accent.withValues(alpha: 0.9)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onTap: () => setState(() {}),
                    onSubmitted: (_) {
                      if (_draft != null) _confirm();
                    },
                    textInputAction: TextInputAction.done,
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
                _TrailingButton(
                  parsing: _parsing,
                  ready: showCard,
                  saving: _saving,
                  onTap: showCard ? _confirm : null,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The trailing control in the field: a spinner while parsing, an accent "add"
/// arrow when a draft is ready, else a soft idle glyph.
class _TrailingButton extends StatelessWidget {
  const _TrailingButton({
    required this.parsing,
    required this.ready,
    required this.saving,
    required this.onTap,
  });
  final bool parsing;
  final bool ready;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (saving || parsing) {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(6),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ready ? AppColors.accent : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 20,
          color: ready ? Colors.white : AppColors.inkFaint,
        ),
      ),
    );
  }
}

/// The inline confirmation card: "Here's what I understood" — the parsed
/// reminder as clean chips, with Add + dismiss. Feels like a reply.
class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.draft,
    required this.saving,
    required this.onConfirm,
    required this.onDismiss,
  });

  final _Draft draft;
  final bool saving;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cat = draft.categoryEnum;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.14),
            AppColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                "HERE'S WHAT I GOT",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.accent.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(cat.icon, size: 21, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
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
                        if (draft.amount != null)
                          _chip(_money(draft)),
                        if (draft.doseTimes.isNotEmpty)
                          _chip(_doseLabel(draft.doseTimes))
                        else if (draft.repeat != RepeatCadence.none)
                          _chip(frequencyLabel(draft.repeat, 1)),
                        if (draft.courseDays != null)
                          _chip('${draft.courseDays} days'),
                        if (draft.dueAt != null) _chip(_dateLabel(draft.dueAt!)),
                        if ((draft.note ?? '').isNotEmpty)
                          _chip('“${draft.note}”', muted: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: saving ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text(
                      'Add reminder',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
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

  /// "2× daily" for a couple of doses, else the count — the times themselves are
  /// captured on the task; the chip just conveys the cadence at a glance.
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

  factory _Draft.raw(String text) =>
      _Draft(title: text, category: 'other');

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
    );
  }

  TaskCategory get categoryEnum => TaskCategory.values.firstWhere(
        (c) => c.name == category,
        orElse: () => TaskCategory.other,
      );
}
