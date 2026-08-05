import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../options/data/options_store.dart';
import '../../options/presentation/option_picker_sheet.dart';
import '../domain/currency.dart';
import '../domain/item_details.dart';
import 'amount_formatter.dart';

/// The full-screen details editor — the rich form (amount, cycle, list,
/// category, notification, URL, notes…) modelled on a subscription entry.
///
/// Opens with an existing [ItemDetails] (or a fresh one) and returns the edited
/// copy on Save, or null if the user backs out.
class ItemDetailsPage extends StatefulWidget {
  const ItemDetailsPage({
    super.key,
    required this.title,
    this.initial,
  });

  final String title;
  final ItemDetails? initial;

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  late final ItemDetails _d = widget.initial?.copy() ?? ItemDetails();

  Currency get _currency => currencyOf(_d.currency);

  late final TextEditingController _name =
      TextEditingController(text: _d.name);
  late final TextEditingController _amount = TextEditingController(
      text: _d.amount == null
          ? ''
          : formatAmount(
              _d.amount!.toStringAsFixed(_currency.decimals), _currency.grouping));
  late final TextEditingController _notes =
      TextEditingController(text: _d.notes);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    _d
      ..name = _name.text.trim()
      // Strip grouping separators before parsing the number.
      ..amount = double.tryParse(unformatAmount(_amount.text))
      ..notes = _notes.text.trim();
    Navigator.of(context).pop(_d);
  }

  /// Pick the currency (₹ / $ / KD). Re-groups the amount for the new system.
  Future<void> _pickCurrency() async {
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Currency',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            for (final c in kCurrencies)
              ListTile(
                leading: Text(c.symbol,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                title: Text(c.label),
                trailing: c.code == _d.currency
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _d.currency = picked.code;
      // Re-group the existing digits under the new system.
      final digits = unformatAmount(_amount.text);
      _amount.text = formatAmount(digits, picked.grouping);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: widget.title, onBack: () => Navigator.pop(context), onSave: _save),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _NameAmountCard(
                    name: _name,
                    amount: _amount,
                    currency: _currency,
                    onTapCurrency: _pickCurrency,
                  ),
                  const SizedBox(height: 20),
                  _Group(children: [
                    // Order: First payment date → Duration → Type → Cycle.
                    _Row(
                      label: 'First payment date',
                      trailing: _Chip(text: _fmtDate(_d.firstPaymentDate)),
                      onTap: _pickFirstPaymentDate,
                    ),
                    _Row(
                      label: 'Duration',
                      trailing: _Chip(
                        text: _d.durationForever
                            ? 'Forever'
                            : _fmtDate(_d.durationUntil ?? _d.firstPaymentDate),
                      ),
                      onTap: _pickDuration,
                    ),
                    _Row(
                      label: 'Type',
                      trailing: _ValuePicker(text: _d.type.label),
                      onTap: () => _pickType(),
                    ),
                    _Row(
                      label: 'Cycle',
                      trailing: _ValuePicker(text: _d.cycle.label),
                      onTap: () => _pickCycle(),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _Group(children: [
                    _Row(
                      label: 'List',
                      trailing: _ValuePicker(text: _d.list),
                      onTap: () => _pickOption(
                        OptionKind.list,
                        _d.list,
                        (v) => setState(() => _d.list = v),
                      ),
                    ),
                    _Row(
                      label: 'Category',
                      trailing: _ValuePicker(text: _d.category),
                      onTap: () => _pickOption(
                        OptionKind.category,
                        _d.category,
                        (v) => setState(() => _d.category = v),
                      ),
                    ),
                    _Row(
                      label: 'Payment Method',
                      trailing: _ValuePicker(text: _d.paymentMethod ?? 'None'),
                      onTap: () => _pickOption(
                        OptionKind.paymentMethod,
                        _d.paymentMethod ?? 'None',
                        (v) => setState(
                            () => _d.paymentMethod = v == 'None' ? null : v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _Group(children: [
                    _Row(
                      label: 'Notification',
                      trailing: _ValuePicker(text: _d.notify.label),
                      onTap: () => _pickNotify(),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const _SectionLabel('NOTES'),
                  _TextFieldCard(
                    controller: _notes,
                    hint: 'Add a note…',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- pickers --------------------------------------------------------------

  /// First payment date → a bottom sheet with a calendar. Selecting a day or
  /// tapping Cancel closes it.
  Future<void> _pickFirstPaymentDate() async {
    final picked = await _showCalendarSheet(
      title: 'First payment date',
      initial: _d.firstPaymentDate,
    );
    if (picked != null) setState(() => _d.firstPaymentDate = picked);
  }

  /// Duration → a bottom sheet offering "Forever" or a specific end date via the
  /// same calendar. Picking either (or Cancel) closes it.
  Future<void> _pickDuration() async {
    final result = await _showDurationSheet();
    if (result == null) return; // cancelled
    setState(() {
      if (result.forever) {
        _d.durationForever = true;
      } else {
        _d.durationForever = false;
        _d.durationUntil = result.date;
      }
    });
  }

  /// Shows a calendar in a bottom sheet. Returns the chosen date, or null on
  /// cancel/dismiss. Selecting a day resolves immediately (auto-close).
  Future<DateTime?> _showCalendarSheet({
    required String title,
    required DateTime initial,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true, // let the sheet size to its (tall) content
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                title: title,
                onCancel: () => Navigator.pop(sheetCtx),
              ),
              _InlineCalendar(
                selected: initial,
                // A tap on a day picks it and closes the sheet.
                onChanged: (d) => Navigator.pop(sheetCtx, d),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// The duration sheet: a "Forever" option pinned on top, then the calendar for
  /// a fixed end date. Returns a [_DurationResult], or null on cancel.
  Future<_DurationResult?> _showDurationSheet() {
    return showModalBottomSheet<_DurationResult>(
      context: context,
      isScrollControlled: true, // Forever tile + full calendar is tall
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                title: 'Duration',
                onCancel: () => Navigator.pop(sheetCtx),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded,
                    color: AppColors.accent),
                title: const Text('Forever',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _d.durationForever
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () =>
                    Navigator.pop(sheetCtx, const _DurationResult.forever()),
              ),
              const Divider(
                height: 1, thickness: 1, indent: 16, endIndent: 16,
                color: AppColors.hairline,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Or pick an end date',
                      style: TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              _InlineCalendar(
                selected: _d.durationUntil ?? _d.firstPaymentDate,
                onChanged: (d) =>
                    Navigator.pop(sheetCtx, _DurationResult.until(d)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickType() => _pickEnum<BillingType>(
        'Type',
        BillingType.values,
        _d.type,
        (e) => e.label,
        (v) => setState(() => _d.type = v),
      );

  Future<void> _pickCycle() => _pickEnum<BillingCycle>(
        'Cycle',
        BillingCycle.values,
        _d.cycle,
        (e) => e.label,
        (v) => setState(() => _d.cycle = v),
      );

  Future<void> _pickNotify() => _pickEnum<NotifyBefore>(
        'Notification',
        NotifyBefore.values,
        _d.notify,
        (e) => e.label,
        (v) => setState(() => _d.notify = v),
      );

  Future<void> _pickEnum<T>(
    String title,
    List<T> options,
    T current,
    String Function(T) label,
    ValueChanged<T> onPick,
  ) async {
    final picked = await _showOptionSheet<T>(
        title, options, current, label);
    if (picked != null) onPick(picked);
  }

  /// Store-backed picker for the customisable fields (List, Category, Payment
  /// Method). Shows defaults + the user's saved options and an "Add new…" row;
  /// new values are persisted via [OptionsStore].
  Future<void> _pickOption(
    OptionKind kind,
    String current,
    ValueChanged<String> onPick,
  ) async {
    final picked = await showOptionPicker(
      context,
      store: OptionsStore.instance,
      kind: kind,
      current: current,
    );
    if (picked != null) onPick(picked);
  }

  Future<T?> _showOptionSheet<T>(
    String title,
    List<T> options,
    T current,
    String Function(T) label,
  ) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
            for (final o in options)
              ListTile(
                title: Text(label(o)),
                trailing: o == current
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, o),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack, required this.onSave});

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.ink,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
            ),
          ),
          TextButton(
            onPressed: onSave,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _NameAmountCard extends StatelessWidget {
  const _NameAmountCard({
    required this.name,
    required this.amount,
    required this.currency,
    required this.onTapCurrency,
  });

  final TextEditingController name;
  final TextEditingController amount;
  final Currency currency;
  final VoidCallback onTapCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 30, color: AppColors.inkSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'Name',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Tappable currency badge — tap to pick ₹ / $ / KD.
                    InkWell(
                      onTap: onTapCurrency,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(currency.symbol,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentDeep)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        // Live grouping for the active currency's number system.
                        inputFormatters: [
                          AmountInputFormatter(currency.grouping),
                        ],
                        style: const TextStyle(
                            fontSize: 18, color: AppColors.inkSoft),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          isDense: true,
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

/// A rounded card that groups a set of rows with hairline dividers between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(const Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.hairline,
        ));
      }
    }
    return Container(
      decoration: _cardDecoration,
      child: Column(children: rows),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing, this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // The label claims the free space, so the value is always pushed
            // flush to the right edge — consistent across every row.
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 12),
            // The value sits at the right; it only shrinks if genuinely huge.
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill chip (used for the date value).
class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.ink)),
    );
  }
}

/// A value with up/down chevrons (a selectable option).
class _ValuePicker extends StatelessWidget {
  const _ValuePicker({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, color: AppColors.inkSoft),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.inkFaint),
      ],
    );
  }
}

/// A full month calendar shown inline inside the details card (no modal). Wraps
/// Flutter's [CalendarDatePicker] and themes it to the app's accent.
/// Result of the duration sheet: either "Forever" or a fixed end [date].
class _DurationResult {
  const _DurationResult.forever()
      : forever = true,
        date = null;
  const _DurationResult.until(this.date) : forever = false;

  final bool forever;
  final DateTime? date;
}

/// A bottom-sheet header: a title on the left, a Cancel button on the right.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onCancel});

  final String title;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const Spacer(),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}

class _InlineCalendar extends StatelessWidget {
  const _InlineCalendar({required this.selected, required this.onChanged});

  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    // No divider of its own — the group already draws a single hairline above
    // this, so the calendar just pops up cleanly below the date row.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.accent,
                onPrimary: Colors.white,
              ),
        ),
        // Bound the height so the month grid has a definite size inside a
        // scroll view / min-sized column — prevents overflow.
        child: SizedBox(
          height: 340,
          child: CalendarDatePicker(
            initialDate: selected,
            firstDate: DateTime(DateTime.now().year - 2),
            lastDate: DateTime(DateTime.now().year + 30),
            onDateChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.inkFaint,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _cardDecoration,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: AppColors.card,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  border: Border.fromBorderSide(BorderSide(color: AppColors.cardBorder)),
);
