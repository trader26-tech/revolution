import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../../brand/presentation/brand_picker_sheet.dart';
import '../../tasks/domain/task.dart';
import '../domain/add_category.dart';
import 'widgets/add_scaffold.dart';
import 'widgets/repeat_cycle_field.dart';

/// The Subscription form — only what a subscription needs: what it is (name +
/// brand logo), what it costs, how often it bills, and the next payment date.
/// No documents, no person — those belong to other categories.
///
/// Returns a ready-to-save [Task], or null if cancelled.
class SubscriptionFormPage extends StatefulWidget {
  const SubscriptionFormPage({super.key});

  @override
  State<SubscriptionFormPage> createState() => _SubscriptionFormPageState();
}

class _SubscriptionFormPageState extends State<SubscriptionFormPage> {
  static const _accent = AppColors.accent;

  final _name = TextEditingController();
  final _amount = TextEditingController();

  String? _iconName;
  String? _iconDomain;
  RepeatCadence _cycle = RepeatCadence.monthly;
  DateTime _nextDate = DateTime.now().add(const Duration(days: 30));

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final Brand? brand = await showBrandPicker(context);
    if (brand != null) {
      setState(() {
        _iconName = brand.name;
        _iconDomain = brand.domain;
        // If they haven't typed a name yet, seed it from the brand.
        if (_name.text.trim().isEmpty) _name.text = brand.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
    );
    if (picked != null) setState(() => _nextDate = picked);
  }

  void _save() {
    if (!_valid) return;
    final amount = double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    Navigator.of(context).pop(
      Task(
        id: 'new',
        title: _name.text.trim(),
        dueAt: _nextDate,
        repeat: _cycle,
        iconName: _iconName,
        iconDomain: _iconDomain,
        amount: amount,
        currency: 'INR',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AddScaffold(
      title: 'New subscription',
      accent: _accent,
      icon: AddCategory.subscription.icon,
      canSave: _valid,
      onSave: _save,
      children: [
        // Name + brand logo.
        const AddFieldLabel('WHAT IS IT?'),
        const SizedBox(height: 10),
        Row(
          children: [
            _IconChip(
              iconName: _iconName,
              iconDomain: _iconDomain,
              accent: _accent,
              onTap: _pickIcon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AddTextField(
                controller: _name,
                hint: 'Netflix, Spotify, gym…',
                accent: _accent,
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Price (optional).
        const AddFieldLabel('PRICE  (optional)'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _amount,
          hint: '499',
          accent: _accent,
          prefix: '₹',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(height: 22),

        // Billing cycle.
        const AddFieldLabel('BILLING'),
        const SizedBox(height: 10),
        RepeatCycleField(
          value: _cycle,
          accent: _accent,
          onChanged: (c) {
            HapticFeedback.selectionClick();
            setState(() => _cycle = c);
          },
        ),
        const SizedBox(height: 22),

        // Next payment date.
        const AddFieldLabel('NEXT PAYMENT'),
        const SizedBox(height: 10),
        AddDateField(
          date: _nextDate,
          accent: _accent,
          onTap: _pickDate,
        ),
      ],
    );
  }
}

/// The brand-logo chip that opens the picker. Shows the chosen logo, or a
/// neutral "+" when empty.
class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.iconName,
    required this.iconDomain,
    required this.accent,
    required this.onTap,
  });

  final String? iconName;
  final String? iconDomain;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasIcon = (iconName != null && iconName!.isNotEmpty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasIcon
            ? BrandLogo(
                brand: Brand(name: iconName!, domain: iconDomain ?? ''),
                size: 32,
              )
            : Icon(Icons.add_rounded, color: accent, size: 26),
      ),
    );
  }
}
