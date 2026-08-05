import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/bamboo_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/reminder.dart';
import '../../domain/repeat_cycle.dart';

/// A full-screen, structured form to create ANY reminder — the Orbit
/// "Add Subscription" pattern, adapted for our reminder app and Bobo theme.
///
/// Fields: an icon+name header with an optional ₹ amount, then grouped rows for
/// the due date, how often it repeats, and when to be notified, plus a notes
/// box. The common set works for every reminder, whatever category it lives in.
class CustomReminderForm extends StatefulWidget {
  const CustomReminderForm({
    super.key,
    required this.categoryKey,
    required this.categoryLabel,
    required this.onSave,
    this.accent = Bamboo.green,
    this.icon = Icons.notifications_active_outlined,
    this.initialName = '',
    this.saving = false,
  });

  /// The category (folder) this reminder is being created inside.
  final String categoryKey;
  final String categoryLabel;

  final Color accent;
  final IconData icon;
  final String initialName;
  final bool saving;

  /// Called with the assembled draft when the user taps Save.
  final ValueChanged<ReminderDraft> onSave;

  @override
  State<CustomReminderForm> createState() => _CustomReminderFormState();
}

class _CustomReminderFormState extends State<CustomReminderForm> {
  late final TextEditingController _name;
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  RepeatCycle _repeat = RepeatCycle.yearly;
  int _remindDaysBefore = 7;

  static const _remindOptions = [1, 3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
      helpText: 'When is it due?',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_valid) return;
    final amount = double.tryParse(_amount.text.trim());
    final draft = ReminderDraft(
      category: widget.categoryKey,
      itemKey: 'custom',
      title: _name.text.trim(),
      expiryDate: _dueDate,
      remindOn: _dueDate.subtract(Duration(days: _remindDaysBefore)),
      remindDaysBefore: _remindDaysBefore,
      metadata: {
        'source': 'custom',
        'category_label': widget.categoryLabel,
        'repeat': _repeat.name,
        if (amount != null && amount > 0) 'amount': amount,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      },
    );
    widget.onSave(draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bamboo.cream,
      appBar: AppBar(
        backgroundColor: Bamboo.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'New in ${widget.categoryLabel}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Bamboo.ink,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _valid && !widget.saving ? _save : null,
              child: widget.saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _valid ? Bamboo.greenDeep : Bamboo.inkSoft,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HeaderCard(
            nameController: _name,
            amountController: _amount,
            accent: widget.accent,
            icon: widget.icon,
          ),
          const SizedBox(height: 20),
          _Group(
            children: [
              _Row(
                label: 'Due date',
                trailing: _PillButton(
                  label: DateFmt.medium(_dueDate),
                  onTap: _pickDate,
                ),
              ),
              const _Divider(),
              _Row(
                label: 'Repeats',
                trailing: _RepeatDropdown(
                  value: _repeat,
                  onChanged: (v) => setState(() => _repeat = v),
                ),
              ),
              const _Divider(),
              _Row(
                label: 'Notify me',
                trailing: _RemindDropdown(
                  value: _remindDaysBefore,
                  options: _remindOptions,
                  onChanged: (v) => setState(() => _remindDaysBefore = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _NotesGroup(controller: _notes),
        ],
      ),
    );
  }
}

/// The icon + Name + optional ₹ amount header, like Orbit's top card.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.nameController,
    required this.amountController,
    required this.accent,
    required this.icon,
  });

  final TextEditingController nameController;
  final TextEditingController amountController;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Bamboo.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Bamboo.ink,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Name',
                    hintStyle: TextStyle(color: Bamboo.inkSoft),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Bamboo.ink,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '0.00  (optional)',
                          hintStyle: TextStyle(color: Bamboo.inkSoft),
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

/// A rounded card that groups rows, like Orbit's sections.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Bamboo.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Bamboo.ink,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Bamboo.cardBorder),
    );
  }
}

/// A tappable pill (used for the date).
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Bamboo.mist,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Bamboo.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _RepeatDropdown extends StatelessWidget {
  const _RepeatDropdown({required this.value, required this.onChanged});
  final RepeatCycle value;
  final ValueChanged<RepeatCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<RepeatCycle>(
        value: value,
        borderRadius: BorderRadius.circular(14),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Bamboo.ink,
          fontSize: 15,
        ),
        icon: const Icon(Icons.unfold_more, size: 18, color: Bamboo.inkSoft),
        items: [
          for (final c in RepeatCycle.values)
            DropdownMenuItem(value: c, child: Text(c.label)),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }
}

class _RemindDropdown extends StatelessWidget {
  const _RemindDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  String _label(int d) => d == 1 ? '1 day before' : '$d days before';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        borderRadius: BorderRadius.circular(14),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Bamboo.ink,
          fontSize: 15,
        ),
        icon: const Icon(Icons.unfold_more, size: 18, color: Bamboo.inkSoft),
        items: [
          for (final d in options)
            DropdownMenuItem(value: d, child: Text(_label(d))),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }
}

class _NotesGroup extends StatelessWidget {
  const _NotesGroup({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'NOTES',
            style: TextStyle(
              color: Bamboo.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Bamboo.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Bamboo.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Bamboo.ink),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Anything Bobo should note…',
              hintStyle: TextStyle(color: Bamboo.inkSoft),
            ),
          ),
        ),
      ],
    );
  }
}
