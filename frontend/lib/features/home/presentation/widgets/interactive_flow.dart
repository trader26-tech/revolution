import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart'
    show Grouping, currencyOf, formatAmount, unformatAmount;
import '../../../onboarding/presentation/widgets/magic_text.dart' show MagicText;
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';

/// The DETERMINISTIC command flow — a tap-driven Create/Read/Update/Delete
/// assistant that runs with NO LLM. The whole conversation (root menu →
/// category → fields → confirm) lives in the Home feed as chat messages, so it
/// reads as one scrolling screen.
///
/// This file owns:
///   • [FlowOp]           — the four root operations.
///   • [FieldKind]/[FieldSpec] — what one question asks for.
///   • [categoryFields]   — the up-to-3 tailored fields per category.
///   • [CreateFlow]       — the mutable state for a create-in-progress.
///   • the widgets        — option chips, category chips, each field prompt,
///                          and the tappable confirmation card.
///
/// Only CREATE is wired end-to-end for now (per the product ask); Read/Update/
/// Delete surface a short "coming soon" line so the menu stays honest.

/// The four things the command assistant can do.
enum FlowOp { create, read, update, delete }

extension FlowOpInfo on FlowOp {
  String get label => switch (this) {
        FlowOp.create => 'Create',
        FlowOp.read => 'Read',
        FlowOp.update => 'Update',
        FlowOp.delete => 'Delete',
      };

  IconData get icon => switch (this) {
        FlowOp.create => Icons.add_rounded,
        FlowOp.read => Icons.search_rounded,
        FlowOp.update => Icons.edit_rounded,
        FlowOp.delete => Icons.delete_outline_rounded,
      };
}

/// The categories offered when creating — Browse's set, minus nothing. General
/// leads so a free-form reminder is one tap away.
const List<TaskCategory> kCreateCategories = [
  TaskCategory.subscription,
  TaskCategory.bills,
  TaskCategory.investment,
  TaskCategory.birthday,
  TaskCategory.medicine,
  TaskCategory.policies,
  TaskCategory.other,
];

// ── Field specs — what a single question collects ────────────────────────────

/// The kind of input a field question uses.
enum FieldKind {
  /// A short line of text (the name/title).
  text,

  /// A money amount (currency-aware numeric).
  amount,

  /// A date (opens a date picker).
  date,

  /// A repeat cadence chosen from chips (every day/week/month/year).
  frequency,

  /// A small integer typed in (times per day, course days).
  number,
}

/// One question in a create flow: what it asks, how it's entered, whether it can
/// be skipped, and the prompt line Revo says.
class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.label,
    required this.prompt,
    required this.kind,
    this.icon = Icons.circle,
    this.skippable = true,
    this.unitWord,
  });

  /// A stable key used to store the entered value on the [CreateFlow].
  final String key;

  /// Short noun shown on the confirm card ("Name", "Price").
  final String label;

  /// The conversational question Revo asks ("What's it called?").
  final String prompt;

  final FieldKind kind;
  final IconData icon;
  final bool skippable;

  /// For [FieldKind.number] — the trailing unit on the confirm card
  /// ("times a day", "days").
  final String? unitWord;
}

/// The up-to-3 tailored fields for each category. Name is always first. Every
/// non-name field is skippable, so a fast capture is just name → confirm.
List<FieldSpec> categoryFields(TaskCategory c) {
  const name = FieldSpec(
    key: 'title',
    label: 'Name',
    prompt: "What's it called?",
    kind: FieldKind.text,
    icon: Icons.title_rounded,
    skippable: false,
  );
  const price = FieldSpec(
    key: 'amount',
    label: 'Price',
    prompt: 'How much is it?',
    kind: FieldKind.amount,
    icon: Icons.payments_outlined,
  );
  const amount = FieldSpec(
    key: 'amount',
    label: 'Amount',
    prompt: "What's the amount?",
    kind: FieldKind.amount,
    icon: Icons.payments_outlined,
  );
  const every = FieldSpec(
    key: 'repeat',
    label: 'Every',
    prompt: 'How often?',
    kind: FieldKind.frequency,
    icon: Icons.repeat_rounded,
  );
  const dueDate = FieldSpec(
    key: 'dueAt',
    label: 'Due',
    prompt: 'When is it due?',
    kind: FieldKind.date,
    icon: Icons.calendar_today_rounded,
  );
  const onDate = FieldSpec(
    key: 'dueAt',
    label: 'Date',
    prompt: "What's the date?",
    kind: FieldKind.date,
    icon: Icons.calendar_today_rounded,
  );

  switch (c) {
    case TaskCategory.subscription:
      return const [name, price, every];
    case TaskCategory.bills:
      return const [name, amount, dueDate];
    case TaskCategory.investment:
      return const [name, amount, every];
    case TaskCategory.birthday:
      return const [name, onDate];
    case TaskCategory.medicine:
      return const [
        name,
        FieldSpec(
          key: 'timesPerDay',
          label: 'Doses',
          prompt: 'How many times a day?',
          kind: FieldKind.number,
          icon: Icons.medication_outlined,
          unitWord: 'a day',
        ),
        FieldSpec(
          key: 'courseDays',
          label: 'For',
          prompt: 'For how many days?',
          kind: FieldKind.number,
          icon: Icons.event_available_outlined,
          unitWord: 'days',
        ),
      ];
    case TaskCategory.policies:
      return const [name, amount, every];
    case TaskCategory.insurance:
      return const [name, amount, dueDate];
    case TaskCategory.other:
      return const [name, onDate];
  }
}

// ── The mutable create-in-progress state ─────────────────────────────────────

/// Which sub-step of a create flow we're on.
enum CreateStage { pickCategory, fields, confirm }

/// The mutable state of one create conversation. Held by a single chat message
/// (`ChatKind.interactive`) and mutated in place as the user taps through, so
/// the whole flow stays on one growing card rather than spawning a new bubble
/// per step.
class CreateFlow {
  CreateFlow();

  CreateStage stage = CreateStage.pickCategory;
  TaskCategory? category;

  /// Index into [fields] of the question currently being asked.
  int fieldIndex = 0;

  /// Collected values, keyed by [FieldSpec.key]. A key present with a null value
  /// means "explicitly skipped"; absent means "not reached yet".
  final Map<String, Object?> values = {};

  /// True once committed (added), so the card locks.
  bool done = false;

  /// True while re-asking a SINGLE field from the confirm card — so answering it
  /// returns straight to confirm instead of re-walking the later questions.
  bool editingOne = false;

  List<FieldSpec> get fields =>
      category == null ? const [] : categoryFields(category!);

  FieldSpec? get currentField =>
      fieldIndex < fields.length ? fields[fieldIndex] : null;

  /// Advance past the current field (with or without a value) and move to the
  /// next question, or to the confirm step when the questions run out.
  void answer(String key, Object? value) {
    values[key] = value;
    // Editing one field from the confirm card → jump straight back to confirm.
    if (editingOne) {
      editingOne = false;
      stage = CreateStage.confirm;
      return;
    }
    fieldIndex++;
    if (fieldIndex >= fields.length) stage = CreateStage.confirm;
  }

  /// Re-ask a single field from the confirm card (tap a row to edit it). Answering
  /// it returns directly to the confirm card ([editingOne]).
  void editField(int index) {
    fieldIndex = index;
    editingOne = true;
    stage = CreateStage.fields;
  }

  String? get title => values['title'] as String?;
  double? get amount => (values['amount'] as num?)?.toDouble();
  DateTime? get dueAt => values['dueAt'] as DateTime?;
  RepeatCadence get repeat =>
      values['repeat'] as RepeatCadence? ?? RepeatCadence.none;
  int? get timesPerDay => values['timesPerDay'] as int?;
  int? get courseDays => values['courseDays'] as int?;
}

// ── Widgets ──────────────────────────────────────────────────────────────────

/// Revo's opening line + the four operation chips (Create/Read/Update/Delete).
/// Blooms in with the shimmer; chips fade in just after the line lands.
class MenuLine extends StatelessWidget {
  const MenuLine({
    super.key,
    required this.shimmer,
    required this.onPick,
  });

  final double shimmer;
  final ValueChanged<FlowOp> onPick;

  /// One-line hint under each action label.
  static String _hintFor(FlowOp op) => switch (op) {
        FlowOp.create => 'Add a new reminder or item',
        FlowOp.read => 'See what you have coming up',
        FlowOp.update => 'Change something you saved',
        FlowOp.delete => 'Remove an item',
      };

  @override
  Widget build(BuildContext context) {
    // Start the rows only AFTER the greeting hero has mostly landed (shimmer>0.5),
    // then run them one-after-another so Create → Read → Update → Delete each
    // arrives in turn.
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.5) / 0.5).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var idx = 0; idx < FlowOp.values.length; idx++) ...[
            if (idx > 0)
              Opacity(
                opacity: Curves.easeOut
                    .transform(((reveal - idx * 0.18) / 0.3).clamp(0.0, 1.0)),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            _staggered(
              reveal,
              idx,
              _MenuRow(
                op: FlowOp.values[idx],
                hint: _hintFor(FlowOp.values[idx]),
                onTap: () => onPick(FlowOp.values[idx]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Slides + fades each row up ONE AFTER ANOTHER off [reveal] — each row waits
  /// for the previous to arrive before starting (a clear sequential cascade).
  Widget _staggered(double reveal, int i, Widget child) {
    const step = 0.18; // bigger gap → clearly one-by-one
    final start = i * step;
    final local = ((reveal - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 12),
        child: child,
      ),
    );
  }
}

/// One CRUD action as a clean tappable LIST ROW: a tinted icon tile, the action
/// name, a one-line hint, and a chevron. Full-width, press-highlight.
class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.op, required this.hint, required this.onTap});
  final FlowOp op;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _down = false;

  // One single accent colour for every action — clean + consistent.
  Color get _tint => AppColors.accent;

  @override
  Widget build(BuildContext context) {
    // A clean, flat LIST LINE: a single-accent icon, the label + hint, a chevron,
    // and a thin divider — no coloured card, no per-action colours.
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _down
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Column(
          children: [
            Row(
              children: [
                Icon(widget.op.icon, size: 23, color: _tint),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.op.label,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.hint,
                        style: TextStyle(
                          color: AppColors.inkSoft.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.inkFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The whole CREATE flow rendered as one growing card: it shows the chosen
/// category, then the current question, then the confirm card — mutating in
/// place as [flow] advances. One message, one evolving surface.
class CreateFlowLine extends StatelessWidget {
  const CreateFlowLine({
    super.key,
    required this.flow,
    required this.shimmer,
    required this.busy,
    required this.onPickCategory,
    required this.onAnswer,
    required this.onEditField,
    required this.onConfirm,
    required this.onCancel,
  });

  final CreateFlow flow;
  final double shimmer;
  final bool busy;
  final ValueChanged<TaskCategory> onPickCategory;
  final void Function(String key, Object? value) onAnswer;
  final ValueChanged<int> onEditField;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 24, 8),
      child: switch (flow.stage) {
        CreateStage.pickCategory => _CategoryStep(
            shimmer: shimmer,
            onPick: onPickCategory,
          ),
        CreateStage.fields => _FieldStep(
            key: ValueKey('field-${flow.category}-${flow.fieldIndex}'),
            flow: flow,
            shimmer: shimmer,
            onAnswer: onAnswer,
          ),
        CreateStage.confirm => _ConfirmStep(
            flow: flow,
            shimmer: shimmer,
            busy: busy,
            onEditField: onEditField,
            onConfirm: onConfirm,
            onCancel: onCancel,
          ),
      },
    );
  }
}

/// Step 1 — "Which one?" + the category chips.
class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.shimmer, required this.onPick});
  final double shimmer;
  final ValueChanged<TaskCategory> onPick;

  @override
  Widget build(BuildContext context) {
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.4) / 0.6).clamp(0.0, 1.0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MagicText(
          text: 'What are you adding?',
          progress: 1,
          reading: true,
          style: TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.ink),
        ),
        if (reveal > 0.01)
          Opacity(
            opacity: reveal,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in kCreateCategories)
                    _Chip(
                      icon: c.icon,
                      label: c.singular[0].toUpperCase() +
                          c.singular.substring(1),
                      onTap: () => onPick(c),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Step 2 — the current field question + its input control. A "Skip" chip sits
/// beside the input for optional fields. Keyed so each question rebuilds fresh.
class _FieldStep extends StatefulWidget {
  const _FieldStep({
    super.key,
    required this.flow,
    required this.shimmer,
    required this.onAnswer,
  });

  final CreateFlow flow;
  final double shimmer;
  final void Function(String key, Object? value) onAnswer;

  @override
  State<_FieldStep> createState() => _FieldStepState();
}

class _FieldStepState extends State<_FieldStep> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  FieldSpec get _field => widget.flow.currentField!;

  @override
  void initState() {
    super.initState();
    // Text-like inputs auto-focus so the keyboard rises with the question.
    if (_field.kind == FieldKind.text ||
        _field.kind == FieldKind.amount ||
        _field.kind == FieldKind.number) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submitText() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      if (_field.skippable) _skip();
      return;
    }
    HapticFeedback.selectionClick();
    widget.onAnswer(_field.key, raw);
  }

  void _submitAmount() {
    final raw = unformatAmount(_controller.text).trim();
    final v = double.tryParse(raw);
    if (v == null) {
      if (_field.skippable) _skip();
      return;
    }
    HapticFeedback.selectionClick();
    widget.onAnswer(_field.key, v);
  }

  void _submitNumber() {
    final v = int.tryParse(_controller.text.trim());
    if (v == null || v <= 0) {
      if (_field.skippable) _skip();
      return;
    }
    HapticFeedback.selectionClick();
    widget.onAnswer(_field.key, v);
  }

  void _skip() {
    HapticFeedback.selectionClick();
    widget.onAnswer(_field.key, null);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
      builder: (context, child) => Theme(
        data: AppTheme.dark.copyWith(
          colorScheme: AppTheme.dark.colorScheme.copyWith(
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      widget.onAnswer(_field.key, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reveal =
        Curves.easeOut.transform(((widget.shimmer - 0.35) / 0.65)
            .clamp(0.0, 1.0));
    final f = _field;

    // Small progress hint — "Step 2 of 3".
    final step = 'Step ${widget.flow.fieldIndex + 1} of ${widget.flow.fields.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.flow.category!.icon,
                size: 15, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(step,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.inkFaint)),
          ],
        ),
        const SizedBox(height: 8),
        MagicText(
          text: f.prompt,
          progress: 1,
          reading: true,
          style: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.ink),
        ),
        if (reveal > 0.01)
          Opacity(
            opacity: reveal,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _input(f),
            ),
          ),
      ],
    );
  }

  Widget _input(FieldSpec f) {
    switch (f.kind) {
      case FieldKind.text:
        return _textRow(hint: 'Type a name…', onSubmit: _submitText);
      case FieldKind.amount:
        final cur = currencyOf('INR');
        return _textRow(
          hint: '0',
          prefix: cur.symbol,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          formatters: [_AmountFormatter(cur.grouping)],
          onSubmit: _submitAmount,
        );
      case FieldKind.number:
        return _textRow(
          hint: '1',
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: f.unitWord,
          onSubmit: _submitNumber,
        );
      case FieldKind.date:
        return Row(
          children: [
            _Chip(
              icon: Icons.calendar_today_rounded,
              label: 'Pick a date',
              filled: true,
              onTap: _pickDate,
            ),
            const SizedBox(width: 8),
            if (f.skippable) _skipChip(),
          ],
        );
      case FieldKind.frequency:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in const [
              RepeatCadence.daily,
              RepeatCadence.weekly,
              RepeatCadence.monthly,
              RepeatCadence.yearly,
            ])
              _Chip(
                label: r.label,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onAnswer(f.key, r);
                },
              ),
            if (f.skippable) _skipChip(),
          ],
        );
    }
  }

  /// A compact inline text input with a send button + optional Skip chip.
  Widget _textRow({
    required String hint,
    required VoidCallback onSubmit,
    String? prefix,
    String? suffix,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                if (prefix != null) ...[
                  Text(prefix,
                      style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    keyboardType: keyboard,
                    inputFormatters: formatters,
                    onSubmitted: (_) => onSubmit(),
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(color: AppColors.inkFaint),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 6),
                  Text(suffix,
                      style: const TextStyle(
                          color: AppColors.inkFaint,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
                GestureDetector(
                  onTap: onSubmit,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_field.skippable) ...[
          const SizedBox(width: 8),
          _skipChip(),
        ],
      ],
    );
  }

  Widget _skipChip() => _Chip(label: 'Skip', muted: true, onTap: _skip);
}

/// Step 3 — the confirm card. Each entered field is a tappable row (tap to
/// re-ask just that field), then Confirm / Cancel.
class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.flow,
    required this.shimmer,
    required this.busy,
    required this.onEditField,
    required this.onConfirm,
    required this.onCancel,
  });

  final CreateFlow flow;
  final double shimmer;
  final bool busy;
  final ValueChanged<int> onEditField;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final reveal =
        Curves.easeOut.transform(((shimmer - 0.3) / 0.7).clamp(0.0, 1.0));
    final cat = flow.category!;
    final line = flow.done
        ? 'Added “${flow.title ?? ''}”'
        : 'Add this ${cat.singular}?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (flow.done) ...[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle_rounded,
                    size: 17, color: AppColors.accent),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: MagicText(
                text: line,
                progress: 1,
                reading: true,
                style: const TextStyle(
                    fontSize: 16,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink),
              ),
            ),
          ],
        ),
        if (reveal > 0.01)
          Opacity(
            opacity: reveal,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _card(),
            ),
          ),
        if (reveal > 0.01 && !flow.done)
          Opacity(
            opacity: reveal,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: busy ? null : onConfirm,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Confirm',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: busy ? null : onCancel,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The details as a soft card. Every ANSWERED (or skipped) field is a row;
  /// tapping a row re-asks just that field (unless already committed).
  Widget _card() {
    final rows = <Widget>[];
    for (var i = 0; i < flow.fields.length; i++) {
      final f = flow.fields[i];
      // Only show fields the user has reached; skipped ones show as "—".
      if (!flow.values.containsKey(f.key)) continue;
      rows.add(_row(i, f));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(int index, FieldSpec f) {
    final value = _display(f);
    final skipped = flow.values[f.key] == null;
    return GestureDetector(
      onTap: flow.done ? null : () => onEditField(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Icon(f.icon,
                size: 16, color: AppColors.accent.withValues(alpha: 0.85)),
            const SizedBox(width: 10),
            SizedBox(
              width: 62,
              child: Text(f.label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.inkFaint)),
            ),
            Expanded(
              child: Text(
                skipped ? '—' : value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: skipped ? AppColors.inkFaint : AppColors.ink),
              ),
            ),
            if (!flow.done)
              const Icon(Icons.edit_rounded,
                  size: 14, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }

  String _display(FieldSpec f) {
    final v = flow.values[f.key];
    if (v == null) return '—';
    switch (f.kind) {
      case FieldKind.text:
        return v as String;
      case FieldKind.amount:
        final cur = currencyOf('INR');
        final a = (v as num).toDouble();
        final body = a == a.roundToDouble()
            ? formatAmount(a.round().toString(), cur.grouping)
            : a.toStringAsFixed(2);
        return '${cur.symbol}$body';
      case FieldKind.date:
        return _dateLabel(v as DateTime);
      case FieldKind.frequency:
        return (v as RepeatCadence).label;
      case FieldKind.number:
        final n = v as int;
        return f.unitWord != null ? '$n ${f.unitWord}' : '$n';
    }
  }
}

/// A short "coming soon" reply for Read/Update/Delete (not built yet).
class ComingSoonLine extends StatelessWidget {
  const ComingSoonLine({super.key, required this.op, required this.shimmer});
  final FlowOp op;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 24, 8),
      child: MagicText(
        text: '${op.label} is coming next — for now, tap Create to add '
            'something.',
        progress: shimmer,
        reading: true,
        style: const TextStyle(
            fontSize: 16,
            height: 1.32,
            fontWeight: FontWeight.w700,
            color: AppColors.ink),
      ),
    );
  }
}

// ── Small shared pieces ──────────────────────────────────────────────────────

/// A pill chip — the flow's one tappable primitive, ONE accent colour for all.
/// [filled] = accent solid (primary), [muted] = quiet (Skip).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.muted = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    // Single accent colour for every chip (no per-category tints) + a FIXED
    // height, so they all read as one consistent set — same size, same format.
    final Color bg;
    final Color fg;
    final Color border;
    if (filled) {
      bg = AppColors.accent;
      fg = Colors.white;
      border = Colors.transparent;
    } else if (muted) {
      bg = Colors.transparent;
      fg = AppColors.inkFaint;
      border = AppColors.cardBorder;
    } else {
      bg = AppColors.accent.withValues(alpha: 0.12);
      fg = AppColors.ink;
      border = AppColors.accent.withValues(alpha: 0.35);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg == AppColors.ink
                  ? AppColors.accent
                  : fg),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Groups the amount digits as the user types (reuses the app's currency
/// grouping so ₹ amounts read naturally).
class _AmountFormatter extends TextInputFormatter {
  _AmountFormatter(this.grouping);
  final Grouping grouping;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatAmount(newValue.text, grouping);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// "Today" / "Tomorrow" / "Fri 22 Aug" — a compact date label for the card.
String _dateLabel(DateTime d) {
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
    'Oct', 'Nov', 'Dec'];
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) return wd[day.weekday - 1];
  return '${wd[day.weekday - 1]} ${d.day} ${mo[d.month - 1]}';
}
