import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../../brand/presentation/brand_picker_sheet.dart';
import '../../tasks/domain/task.dart';
import 'widgets/add_scaffold.dart';
import 'widgets/repeat_cycle_field.dart';

/// The Money & Investments (SIP) form — a SIP has three things a reminder needs:
/// how MUCH you invest, WHERE (the platform — Groww, Zerodha, Kuvera…, picked
/// as a logo), and WHEN the next instalment lands (+ how often). No documents,
/// no person.
///
/// Returns a ready-to-save [Task] in the `subscription`… no — the `other`
/// category flagged as money, or null if cancelled.
class SipFormPage extends StatefulWidget {
  const SipFormPage({super.key, this.initialName, this.accent});

  /// Seed the SIP name (e.g. the catalog item "SIP investment").
  final String? initialName;

  /// The category accent, carried into the form.
  final Color? accent;

  @override
  State<SipFormPage> createState() => _SipFormPageState();
}

class _SipFormPageState extends State<SipFormPage> {
  static const _green = Color(0xFF4ADE80);
  Color get _accent => widget.accent ?? _green;

  final _name = TextEditingController();
  final _amount = TextEditingController();

  // The platform, picked as a brand logo (Groww, Zerodha, Kuvera…).
  String? _platformName;
  String? _platformDomain;

  RepeatCadence _cycle = RepeatCadence.monthly;
  DateTime _nextDate = DateTime.now().add(const Duration(days: 30));

  bool get _valid =>
      _name.text.trim().isNotEmpty && _amount.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.trim().isNotEmpty) {
      _name.text = widget.initialName!.trim();
    }
    _name.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickPlatform() async {
    final Brand? brand = await showBrandPicker(context);
    if (brand != null) {
      setState(() {
        _platformName = brand.name;
        _platformDomain = brand.domain;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showOrbitDatePicker(
      context,
      initial: _nextDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
      title: 'Next SIP date',
    );
    if (picked != null) setState(() => _nextDate = picked);
  }

  void _save() {
    if (!_valid) return;
    final amount =
        double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    // Title reads naturally, e.g. "Index fund SIP · Groww".
    final base = _name.text.trim();
    final title =
        _platformName != null ? '$base · $_platformName' : base;
    Navigator.of(context).pop(
      Task(
        id: 'new',
        title: title,
        dueAt: _nextDate,
        repeat: _cycle,
        amount: amount,
        currency: 'INR',
        // The platform doubles as the task's logo.
        iconName: _platformName,
        iconDomain: _platformDomain,
        storedCategory: TaskCategory.investment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AddScaffold(
      title: widget.initialName ?? 'New SIP',
      accent: _accent,
      icon: Icons.savings_rounded,
      canSave: _valid,
      onSave: _save,
      children: [
        // What SIP is this.
        const AddFieldLabel('WHAT ARE YOU INVESTING IN?'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _name,
          hint: 'Index fund, Nifty 50, my ELSS…',
          accent: _accent,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 22),

        // SIP amount.
        const AddFieldLabel('SIP AMOUNT'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _amount,
          hint: '5000',
          accent: _accent,
          prefix: '₹',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(height: 22),

        // Platform (brand logo).
        const AddFieldLabel('PLATFORM'),
        const SizedBox(height: 10),
        _PlatformField(
          name: _platformName,
          domain: _platformDomain,
          accent: _accent,
          onTap: _pickPlatform,
        ),
        const SizedBox(height: 22),

        // How often.
        const AddFieldLabel('EVERY'),
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

        // Next date.
        const AddFieldLabel('NEXT SIP DATE'),
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

/// The platform row — shows the chosen brand logo + name, or a prompt to pick.
class _PlatformField extends StatelessWidget {
  const _PlatformField({
    required this.name,
    required this.domain,
    required this.accent,
    required this.onTap,
  });

  final String? name;
  final String? domain;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = name != null && name!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: has
                  ? BrandLogo(
                      brand: Brand(name: name!, domain: domain ?? ''),
                      size: 26,
                    )
                  : Icon(Icons.account_balance_rounded,
                      color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has ? name! : 'Groww, Zerodha, Kuvera…',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: has ? AppColors.ink : AppColors.inkFaint,
                ),
              ),
            ),
            Icon(has ? Icons.edit_rounded : Icons.add_rounded,
                size: 20, color: accent),
          ],
        ),
      ),
    );
  }
}
