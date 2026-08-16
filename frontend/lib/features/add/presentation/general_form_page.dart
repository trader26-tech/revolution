import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../../core/widgets/starfield.dart';
import '../../details/domain/currency.dart';
import '../../details/domain/currency_input.dart';
import '../../tasks/domain/task.dart';
import 'widgets/orbit_form.dart';

/// The GENERAL reminder form — the catch-all "just remember this" entry. Unlike
/// the tailored forms (subscription price/cycle, SIP amount, occasion date),
/// this one is deliberately open: a title, a date, an optional freeform NOTE
/// describing what it's about, and a reminder lead time. It's the easy way to
/// capture anything that doesn't fit a specific category.
///
/// Returns a ready-to-save [Task] (category `other`), the edited copy in edit
/// mode, or null if cancelled.
class GeneralFormPage extends StatefulWidget {
  const GeneralFormPage({super.key, this.editTask, this.onDelete});

  /// When set, opens in EDIT mode pre-filled; Save returns an updated copy.
  final Task? editTask;

  /// Edit mode only — confirm + delete this task. Returns true when deleted so
  /// the form pops. Null in add mode (no delete button).
  final Future<bool> Function()? onDelete;

  @override
  State<GeneralFormPage> createState() => _GeneralFormPageState();
}

class _GeneralFormPageState extends State<GeneralFormPage> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _note = TextEditingController();

  // Optional catch-all extras: an amount (with currency) and a repeat cadence —
  // so General can capture money and recurring things, not just plain reminders.
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  String _currency = 'INR';
  RepeatCadence _repeat = RepeatCadence.none;
  int _interval = 1;

  DateTime? _date;
  int _remindDaysBefore = 0;

  bool get _valid => _title.text.trim().isNotEmpty;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.editTask;
    if (edit != null) {
      _title.text = edit.title;
      _note.text = edit.note ?? '';
      _date = edit.dueAt;
      _remindDaysBefore = edit.remindDaysBefore;
      _currency = edit.currency;
      if (edit.amount != null) {
        _amount.text = formatAmount(
            edit.amount!.toStringAsFixed(currencyOf(edit.currency).decimals),
            currencyOf(edit.currency).grouping);
      }
      _repeat = edit.repeat;
      _interval = edit.repeatTimes;
    }
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    _note.dispose();
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency() async {
    final picked = await showCurrencyPicker(context, _currency);
    if (picked != null) {
      setState(() {
        _currency = picked;
        _amount.text = formatAmount(_amount.text, currencyOf(picked).grouping);
      });
    }
  }

  Future<void> _pickFrequency() async {
    final r = await showFrequencyPicker(context,
        unit: _repeat, interval: _interval);
    if (r != null) {
      setState(() {
        _repeat = r.unit;
        _interval = r.interval;
      });
    }
  }

  /// The typed amount as a number, or null when blank.
  double? get _amountValue {
    final raw = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  String _dateLabel() {
    final d = _date;
    if (d == null) return 'Set a date';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showOrbitDatePicker(
      context,
      initial: _date ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20, 12, 31),
      title: 'When?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _handleDelete() async {
    final deleted = await widget.onDelete!();
    if (deleted && mounted) Navigator.of(context).pop();
  }

  void _save() {
    if (!_valid) return;
    HapticFeedback.lightImpact();
    final title = _title.text.trim();
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final amount = _amountValue;
    final edit = widget.editTask;
    if (edit != null) {
      Navigator.of(context).pop(edit.copyWith(
        title: title,
        dueAt: _date,
        clearDueAt: _date == null,
        note: note,
        clearNote: note == null,
        amount: amount,
        clearAmount: amount == null,
        currency: _currency,
        repeat: _repeat,
        repeatTimes: _interval,
        category: TaskCategory.other,
        remindDaysBefore: _remindDaysBefore,
      ));
      return;
    }
    Navigator.of(context).pop(Task(
      id: 'new',
      title: title,
      dueAt: _date,
      note: note,
      amount: amount,
      currency: _currency,
      repeat: _repeat,
      repeatTimes: _interval,
      storedCategory: TaskCategory.other,
      remindDaysBefore: _remindDaysBefore,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Starfield(
        intensity: 0.5,
        child: SafeArea(
          child: Column(
            children: [
              OrbitFormHeader(
                title: widget.editTask != null
                    ? 'Edit reminder'
                    : 'Add a reminder',
                canSave: _valid,
                onBack: () => Navigator.of(context).maybePop(),
                onSave: _save,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    // ── Identity: the name + an OPTIONAL amount (₹) right in the
                    //    header, like the subscription form. Blank amount = a
                    //    plain reminder. ──
                    _TitleCard(
                      controller: _title,
                      focus: _titleFocus,
                      // Never auto-open the keyboard — let the page settle first;
                      // the user taps the field when ready. (Applies to add too.)
                      autofocus: false,
                      amount: _amount,
                      amountFocus: _amountFocus,
                      currency: _currency,
                      onPickCurrency: _pickCurrency,
                    ),
                    const OrbitSaveHint(),
                    const SizedBox(height: 18),

                    // ── The schedule, all in ONE card: when it's due, whether it
                    //    repeats, and when to remind. Repeats + Remind read as one
                    //    contained flow. Repeats defaults to "Never". ──
                    OrbitGroupCard(
                      children: [
                        OrbitNavRow(
                          label: 'When',
                          value: _dateLabel(),
                          onTap: _pickDate,
                        ),
                        const OrbitRowDivider(),
                        OrbitNavRow(
                          label: 'Repeats',
                          value: frequencyLabel(_repeat, _interval),
                          onTap: _pickFrequency,
                        ),
                        const OrbitRowDivider(),
                        _RemindRow(
                          days: _remindDaysBefore,
                          onChanged: (d) =>
                              setState(() => _remindDaysBefore = d),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── Note ──
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'NOTE',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    _NoteField(controller: _note),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 15, color: AppColors.inkFaint),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Anything you want to remember — a detail, a link, '
                              'the why. We’ll keep it with the reminder.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: AppColors.inkFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onDelete != null)
                      OrbitDeleteButton(onDelete: _handleDelete),
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

/// The title input, in the orbit identity-card style (icon chip + text field).
class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.controller,
    required this.focus,
    required this.amount,
    required this.amountFocus,
    required this.currency,
    required this.onPickCurrency,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final FocusNode focus;

  /// The OPTIONAL amount — a currency chip + number, sitting under the name
  /// right in the identity card (same shape as the subscription form). Blank =
  /// no amount, so a General item stays a plain reminder.
  final TextEditingController amount;
  final FocusNode amountFocus;
  final String currency;
  final VoidCallback onPickCurrency;

  /// Only auto-focus (raise the keyboard) when ADDING — never when editing an
  /// existing reminder, where the name's already filled and the user is just
  /// reviewing/tweaking.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final symbol = currencyOf(currency).symbol;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.28),
                  AppColors.accent.withValues(alpha: 0.12),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.ink, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The name.
                TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: autofocus,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: AppColors.accent,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Name',
                    hintStyle: TextStyle(
                      color: AppColors.inkFaint,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                // The OPTIONAL amount, right under the name.
                Row(
                  children: [
                    // Currency chip — tap to change.
                    GestureDetector(
                      onTap: onPickCurrency,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(symbol,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                )),
                            const SizedBox(width: 3),
                            const Icon(Icons.expand_more_rounded,
                                size: 15, color: AppColors.accent),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: amount,
                        focusNode: amountFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        // Same grouped formatter the tailored forms use, so the
                        // amount round-trips through _save()'s _amountValue.
                        inputFormatters: [
                          CurrencyAmountFormatter(
                            currencyOf(currency).grouping,
                            decimals: currencyOf(currency).decimals,
                          ),
                        ],
                        cursorColor: AppColors.accent,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Amount',
                          hintStyle: TextStyle(
                            color: AppColors.inkFaint,
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A multiline freeform note field.
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: AppColors.accent,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        decoration: const InputDecoration(
          hintText: 'Note',
          hintStyle: TextStyle(
            color: AppColors.inkFaint,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// A reminder lead-time stepper (On the day → N days before). Mirrors the
/// occasion form's control so the whole add surface feels consistent.
class _RemindRow extends StatelessWidget {
  const _RemindRow({required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  static const _presets = [0, 1, 3, 7, 14, 30];

  String _label(int d) => switch (d) {
        0 => 'On the day',
        1 => '1 day before',
        _ => '$d days before',
      };

  int get _index {
    var best = 0;
    var bestDiff = (days - _presets[0]).abs();
    for (var i = 1; i < _presets.length; i++) {
      final diff = (days - _presets[i]).abs();
      if (diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final i = _index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Text('Remind me', style: orbitLabelStyle),
          const Spacer(),
          // − steps DOWN toward "On the day"; + steps UP to more days before —
          // the intuitive direction (bigger number to the right of +).
          _step(Icons.remove_rounded, i > 0, () {
            onChanged(_presets[i - 1]);
          }),
          SizedBox(
            width: 108,
            child: Text(
              _label(_presets[i]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          _step(Icons.add_rounded, i < _presets.length - 1, () {
            onChanged(_presets[i + 1]);
          }),
        ],
      ),
    );
  }

  Widget _step(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon,
            size: 18, color: enabled ? AppColors.accent : AppColors.inkFaint),
      ),
    );
  }
}
