import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../reminders/domain/reminder_draft.dart';
import '../domain/item_catalog.dart';
import 'widgets/document_thumb.dart';

/// Opens the minimal entry sheet for one [item] and returns a completed
/// [ReminderDraft], or null if dismissed.
Future<ReminderDraft?> showEntrySheet(
  BuildContext context, {
  required Item item,
  required String categoryName,
}) {
  return showModalBottomSheet<ReminderDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _EntrySheet(item: item, categoryName: categoryName),
  );
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.item, required this.categoryName});

  final Item item;
  final String categoryName;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  DateTime? _date;
  final _docNumber = TextEditingController();

  Item get _item => widget.item;

  /// The single date's label — issue vs expiry depending on the anchor.
  String get _dateLabel => switch (_item.anchor) {
        AnchorType.expiry => 'Expiry date',
        AnchorType.issuePlusValidity => 'Issue date',
        AnchorType.none => '',
      };

  bool get _needsDate => _item.anchor != AnchorType.none;

  bool get _canSave => !_needsDate || _date != null;

  @override
  void dispose() {
    _docNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 30);
    final last = DateTime(now.year + 30);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_canSave) return;
    final draft = buildDraft(
      item: _item,
      categoryName: widget.categoryName,
      date: _date,
      documentNumber: _docNumber.text.trim(),
    );
    Navigator.of(context).pop(draft);
  }

  /// Computed expiry preview, so the user trusts the defaults.
  DateTime? get _previewExpiry {
    if (_date == null) return null;
    return switch (_item.anchor) {
      AnchorType.expiry => _date,
      AnchorType.issuePlusValidity =>
        _date!.add(Duration(days: _item.validityDays ?? 365)),
      AnchorType.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: the document thumbnail + its name.
            Row(
              children: [
                DocumentThumb(item: _item, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _item.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            if (_item.note != null) ...[
              const SizedBox(height: 12),
              Text(
                _item.note!,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.inkSoft),
              ),
            ],
            const SizedBox(height: 20),

            // The ONE date field (skipped entirely for store-only items).
            if (_needsDate) ...[
              _FieldLabel(_dateLabel),
              const SizedBox(height: 6),
              _DateField(
                value: _date,
                hint: 'Tap to choose',
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
            ],

            // Optional document number.
            if (_item.askDocNumber) ...[
              _FieldLabel('${_item.docNumberLabel ?? "Number"} (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _docNumber,
                decoration: InputDecoration(
                  hintText: _item.docNumberLabel,
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Live reminder preview.
            _Preview(item: _item, expiry: _previewExpiry, needsDate: _needsDate),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(_needsDate ? 'Set reminder' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.inkSoft,
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.hint, required this.onTap});

  final DateTime? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 12),
            Text(
              value == null ? hint : _fmt(value!),
              style: TextStyle(
                fontSize: 15,
                color: value == null ? AppColors.inkFaint : AppColors.ink,
                fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.item,
    required this.expiry,
    required this.needsDate,
  });

  final Item item;
  final DateTime? expiry;
  final bool needsDate;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (!needsDate) {
      text = 'Stored for reference — no reminder needed.';
    } else if (expiry == null) {
      text = 'Choose a date and we\'ll set the reminder for you.';
    } else {
      final remindOn = expiry!.subtract(Duration(days: item.leadDays));
      text = 'Expires ${_fmt(expiry!)} · we\'ll remind you on ${_fmt(remindOn)}.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
