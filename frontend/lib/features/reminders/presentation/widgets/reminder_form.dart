import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../domain/catalog.dart';
import '../../domain/reminder.dart';

/// The prefilled form for one catalog item, shown inside the add drawer.
///
/// Design goals:
///  * Nothing starts empty. Validity, reminder lead-time and every choice field
///    come pre-selected with the most common option.
///  * The user's ONE required action is picking a date (issue date, or expiry
///    for visa-style items). Everything downstream is computed live.
///  * Expiry and "remind me on" are shown as a live preview so the user trusts
///    the defaults instead of hunting for hidden settings.
class ReminderForm extends StatefulWidget {
  const ReminderForm({
    super.key,
    required this.category,
    required this.item,
    required this.onSubmit,
    required this.submitting,
  });

  final ReminderCategory category;
  final CatalogItem item;
  final bool submitting;
  final ValueChanged<ReminderDraft> onSubmit;

  @override
  State<ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _docNumber;
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _choiceValues = {};

  /// The single date the user picks — issue date for most items, or the expiry
  /// date itself for [ValidityKind.expiryOnly] items.
  DateTime? _anchorDate;
  late int _remindDaysBefore;

  bool get _isExpiryAnchored =>
      widget.item.validityKind == ValidityKind.expiryOnly;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _docNumber = TextEditingController();
    _remindDaysBefore = widget.item.defaultRemindDaysBefore;

    for (final f in widget.item.fields) {
      if (f.options.isNotEmpty) {
        _choiceValues[f.key] = f.defaultValue.isNotEmpty
            ? f.defaultValue
            : f.options.first;
      } else {
        _textControllers[f.key] = TextEditingController(text: f.defaultValue);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _docNumber.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Computes the expiry date from the anchor + validity rule.
  DateTime? get _expiryDate {
    final anchor = _anchorDate;
    if (anchor == null) return null;
    switch (widget.item.validityKind) {
      case ValidityKind.expiryOnly:
        return anchor;
      case ValidityKind.fixedYears:
        return DateTime(
          anchor.year + (widget.item.defaultValidityYears ?? 1),
          anchor.month,
          anchor.day,
        );
      case ValidityKind.evergreen:
        final months = widget.item.reviewIntervalMonths ?? 60;
        return DateTime(anchor.year, anchor.month + months, anchor.day);
    }
  }

  DateTime? get _remindOn {
    final expiry = _expiryDate;
    if (expiry == null) return null;
    return expiry.subtract(Duration(days: _remindDaysBefore));
  }

  String get _anchorLabel {
    if (_isExpiryAnchored) return 'Expiry date';
    switch (widget.item.validityKind) {
      case ValidityKind.evergreen:
        return 'Last updated / issued on';
      default:
        return 'Issue date';
    }
  }

  Future<void> _pickAnchorDate() async {
    final now = DateTime.now();
    final initial = _anchorDate ??
        (_isExpiryAnchored ? now.add(const Duration(days: 365)) : now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
      helpText: 'Select $_anchorLabel'.toUpperCase(),
    );
    if (picked != null) setState(() => _anchorDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final expiry = _expiryDate;
    final remindOn = _remindOn;
    if (expiry == null || remindOn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please pick the $_anchorLabel first')),
      );
      return;
    }

    final metadata = <String, dynamic>{};
    _choiceValues.forEach((k, v) => metadata[k] = v);
    _textControllers.forEach((k, c) {
      if (c.text.trim().isNotEmpty) metadata[k] = c.text.trim();
    });

    widget.onSubmit(ReminderDraft(
      category: widget.category.key,
      itemKey: widget.item.key,
      title: _title.text.trim(),
      documentNumber: _docNumber.text.trim(),
      issueDate: _isExpiryAnchored ? null : _anchorDate,
      expiryDate: expiry,
      remindOn: remindOn,
      remindDaysBefore: _remindDaysBefore,
      metadata: metadata,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.category.color;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        shrinkWrap: true,
        children: [
          _Header(item: widget.item, color: color),
          if (widget.item.tip != null) ...[
            const SizedBox(height: 12),
            _TipBanner(text: widget.item.tip!, color: color),
          ],
          const SizedBox(height: 20),

          // Title (prefilled).
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Reminder name',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
          ),
          const SizedBox(height: 16),

          // Document number (optional, prefilled hint).
          if (widget.item.documentNumberLabel != null)
            TextFormField(
              controller: _docNumber,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: '${widget.item.documentNumberLabel} (optional)',
                hintText: widget.item.documentNumberHint,
                border: const OutlineInputBorder(),
              ),
            ),
          if (widget.item.documentNumberLabel != null)
            const SizedBox(height: 16),

          // Choice / text fields from the catalog (all prefilled).
          for (final f in widget.item.fields) ...[
            _CatalogFieldEditor(
              field: f,
              color: color,
              selected: _choiceValues[f.key],
              controller: _textControllers[f.key],
              onChoice: (v) => setState(() => _choiceValues[f.key] = v),
            ),
            const SizedBox(height: 16),
          ],

          // The one required action: pick the anchor date.
          _DateTile(
            label: _anchorLabel,
            value: _anchorDate,
            color: color,
            emphasize: _anchorDate == null,
            onTap: _pickAnchorDate,
          ),
          const SizedBox(height: 16),

          // Reminder lead-time chips (prefilled to the item's default).
          Text('Remind me', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final d in kRemindPresets)
                ChoiceChip(
                  label: Text('$d days before'),
                  selected: _remindDaysBefore == d,
                  onSelected: (_) => setState(() => _remindDaysBefore = d),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Live computed preview so the defaults feel trustworthy.
          _ComputedPreview(
            expiry: _expiryDate,
            remindOn: _remindOn,
            color: color,
            evergreen: widget.item.validityKind == ValidityKind.evergreen,
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: widget.submitting ? null : _submit,
            icon: widget.submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.notifications_active_outlined),
            label: Text(widget.submitting ? 'Saving…' : 'Set reminder'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item, required this.color});
  final CatalogItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            item.title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogFieldEditor extends StatelessWidget {
  const _CatalogFieldEditor({
    required this.field,
    required this.color,
    required this.selected,
    required this.controller,
    required this.onChoice,
  });

  final CatalogField field;
  final Color color;
  final String? selected;
  final TextEditingController? controller;
  final ValueChanged<String> onChoice;

  @override
  Widget build(BuildContext context) {
    if (field.options.isEmpty) {
      return TextFormField(
        controller: controller,
        keyboardType: field.keyboardType,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          border: const OutlineInputBorder(),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in field.options)
              ChoiceChip(
                label: Text(o),
                selected: selected == o,
                onSelected: (_) => onChoice(o),
              ),
          ],
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.color,
    required this.emphasize,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final Color color;
  final bool emphasize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: emphasize ? color : Theme.of(context).dividerColor,
            width: emphasize ? 1.6 : 1,
          ),
          color: emphasize ? color.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? 'Tap to select' : DateFmt.medium(value!),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value == null ? color : null,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }
}

class _ComputedPreview extends StatelessWidget {
  const _ComputedPreview({
    required this.expiry,
    required this.remindOn,
    required this.color,
    required this.evergreen,
  });

  final DateTime? expiry;
  final DateTime? remindOn;
  final Color color;
  final bool evergreen;

  @override
  Widget build(BuildContext context) {
    if (expiry == null || remindOn == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row(
            context,
            icon: evergreen ? Icons.refresh : Icons.hourglass_bottom,
            label: evergreen ? 'Next review' : 'Expires on',
            value: DateFmt.medium(expiry!),
          ),
          const Divider(height: 20),
          _row(
            context,
            icon: Icons.notifications_active_outlined,
            label: 'We\'ll remind you',
            value: '${DateFmt.medium(remindOn!)} · '
                '${DateFmt.relativeDays(remindOn!.difference(DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                )).inDays)}',
            highlight: color,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? highlight,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: highlight ?? Theme.of(context).hintColor),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: highlight,
                ),
          ),
        ),
      ],
    );
  }
}
