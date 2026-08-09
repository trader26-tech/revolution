import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../../brand/presentation/brand_picker_sheet.dart';
import '../../tasks/domain/task.dart';
import '../domain/add_category.dart';
import 'widgets/add_scaffold.dart';
import 'widgets/local_photo_field.dart';
import 'widgets/repeat_cycle_field.dart';

/// The Subscription form — only what a subscription needs: what it is (name +
/// brand logo), what it costs, how often it bills, and the next payment date.
/// No documents, no person — those belong to other categories.
///
/// Optionally seeded with an [initialBrand] — when the user tapped a brand on
/// the add picker, the name + logo arrive already filled so they only set the
/// price and date.
///
/// Returns a ready-to-save [Task], or null if cancelled.
class SubscriptionFormPage extends StatefulWidget {
  const SubscriptionFormPage({
    super.key,
    this.initialBrand,
    this.initialName,
    this.initialCycle,
    this.title,
    this.accent,
  });

  /// Seed the logo + name from a tapped brand.
  final Brand? initialBrand;

  /// Seed just the name (a catalog item like "Passport renewal").
  final String? initialName;

  /// Seed the repeat cadence (the catalog item's sensible default).
  final RepeatCadence? initialCycle;

  /// Optional custom app-bar title (defaults to "New subscription").
  final String? title;

  /// Optional accent — the tapped category's colour, carried into the form.
  final Color? accent;

  @override
  State<SubscriptionFormPage> createState() => _SubscriptionFormPageState();
}

class _SubscriptionFormPageState extends State<SubscriptionFormPage> {
  Color get _accent => widget.accent ?? AppColors.accent;

  final _name = TextEditingController();
  final _amount = TextEditingController();

  String? _iconName;
  String? _iconDomain;
  String? _photo; // optional local picture of the subscription
  late RepeatCadence _cycle = widget.initialCycle ?? RepeatCadence.monthly;
  DateTime _nextDate = DateTime.now().add(const Duration(days: 30));

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the brand the user tapped on the picker, if any.
    final b = widget.initialBrand;
    if (b != null) {
      _iconName = b.name;
      _iconDomain = b.domain;
      _name.text = b.name;
    } else if (widget.initialName != null &&
        widget.initialName!.trim().isNotEmpty) {
      _name.text = widget.initialName!.trim();
    }
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
        imagePath: _photo,
        storedCategory: TaskCategory.subscription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AddScaffold(
      title: widget.title ?? 'New subscription',
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
        const SizedBox(height: 22),

        // An optional picture of the subscription (used when there's no brand
        // logo, or just to personalise it).
        const AddFieldLabel('PICTURE  (optional)'),
        const SizedBox(height: 12),
        LocalPhotoField(
          path: _photo,
          accent: _accent,
          label: 'Add a picture',
          onChanged: (p) => setState(() => _photo = p),
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
