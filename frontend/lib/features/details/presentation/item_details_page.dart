import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/item_details.dart';

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

  late final TextEditingController _name =
      TextEditingController(text: _d.name);
  late final TextEditingController _amount = TextEditingController(
      text: _d.amount == null ? '' : _d.amount!.toStringAsFixed(2));
  late final TextEditingController _url = TextEditingController(text: _d.url);
  late final TextEditingController _notes =
      TextEditingController(text: _d.notes);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    _d
      ..name = _name.text.trim()
      ..amount = double.tryParse(_amount.text.trim())
      ..url = _url.text.trim()
      ..notes = _notes.text.trim();
    Navigator.of(context).pop(_d);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _d.firstPaymentDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 30),
    );
    if (picked != null) setState(() => _d.firstPaymentDate = picked);
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
                    currency: _d.currency,
                  ),
                  const SizedBox(height: 20),
                  _Group(children: [
                    _Row(
                      label: 'First payment date',
                      trailing: _Chip(text: _fmtDate(_d.firstPaymentDate)),
                      onTap: _pickDate,
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
                    _Row(
                      label: 'Duration',
                      trailing: _ValuePicker(
                          text: _d.durationForever ? 'Forever' : 'Fixed'),
                      onTap: () => setState(
                          () => _d.durationForever = !_d.durationForever),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _Group(children: [
                    _Row(
                      label: 'List',
                      trailing: _ValuePicker(text: _d.list),
                      onTap: () => _pickFromList(
                        'List',
                        ['Personal', 'Work', 'Family', 'Shared'],
                        _d.list,
                        (v) => setState(() => _d.list = v),
                      ),
                    ),
                    _Row(
                      label: 'Category',
                      trailing: _ValuePicker(text: _d.category),
                      onTap: () => _pickFromList(
                        'Category',
                        ['Other', 'Entertainment', 'Utilities', 'Insurance',
                         'Finance', 'Health', 'Vehicle'],
                        _d.category,
                        (v) => setState(() => _d.category = v),
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
                  const _SectionLabel('URL'),
                  _TextFieldCard(
                    controller: _url,
                    hint: 'E.g. example.com',
                    keyboardType: TextInputType.url,
                  ),
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

  Future<void> _pickFromList(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onPick,
  ) async {
    final picked =
        await _showOptionSheet<String>(title, options, current, (s) => s);
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
  });

  final TextEditingController name;
  final TextEditingController amount;
  final String currency;

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(currency,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentDeep)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 18, color: AppColors.inkSoft),
                        decoration: const InputDecoration(
                          hintText: '0.00',
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
            Text(label,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.ink, fontWeight: FontWeight.w500)),
            const Spacer(),
            trailing,
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
        Text(text,
            style: const TextStyle(fontSize: 16, color: AppColors.inkSoft)),
        const SizedBox(width: 4),
        const Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.inkFaint),
      ],
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
