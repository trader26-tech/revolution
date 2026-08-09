import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../../core/widgets/starfield.dart';
import '../../brand/presentation/brand_picker_sheet.dart';
import '../../details/domain/currency.dart';
import '../../tasks/domain/task.dart';
import '../domain/subscription_categories.dart';
import 'widgets/orbit_form.dart';

/// The Money & Investments (SIP) form — same orbit design language as the
/// subscription form: an identity card (platform logo · name · amount +
/// currency), a grouped details card (category · next date · cycle). The
/// category (Stocks / Mutual Funds / Bonds / Gold / Goal) auto-fills from the
/// name and can be changed or made custom.
///
/// Returns a ready-to-save [Task] (category `investment`), or the edited copy in
/// edit mode, or null if cancelled.
class SipFormPage extends StatefulWidget {
  const SipFormPage({
    super.key,
    this.initialName,
    this.accent, // kept for call-site compatibility; the form is always accent
    this.editTask,
  });

  final String? initialName;
  final Color? accent;

  /// When set, opens in EDIT mode pre-filled from this task; Save returns an
  /// updated copy (same id).
  final Task? editTask;

  @override
  State<SipFormPage> createState() => _SipFormPageState();
}

class _SipFormPageState extends State<SipFormPage> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();

  // The platform, picked as a brand logo (Groww, Zerodha, Kuvera…) — doubles as
  // the task icon.
  String? _iconName;
  String? _iconDomain;

  String _currency = 'INR';
  RepeatCadence _cycle = RepeatCadence.monthly;
  int _times = 1;
  List<int> _days = const [];
  DateTime _nextDate = DateTime.now().add(const Duration(days: 30));

  String _subCategory = kOtherSipCategory; // auto-filled, editable
  bool _categoryTouched = false;
  final Set<String> _customCategories = {};

  bool get _valid =>
      _name.text.trim().isNotEmpty && _amount.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTask;
    if (edit != null) {
      _name.text = edit.title;
      _iconName = edit.iconName;
      _iconDomain = edit.iconDomain;
      if (edit.hasAmount) {
        final plain = edit.amount!.toStringAsFixed(
            edit.amount == edit.amount!.roundToDouble() ? 0 : 2);
        _amount.text =
            formatAmount(plain, currencyOf(edit.currency).grouping);
      }
      _currency = edit.currency;
      _cycle = edit.repeat == RepeatCadence.none
          ? RepeatCadence.monthly
          : edit.repeat;
      _times = edit.repeatTimes;
      _days = [...edit.repeatDays];
      if (edit.dueAt != null) _nextDate = edit.dueAt!;
      if (edit.subCategory != null && edit.subCategory!.trim().isNotEmpty) {
        _subCategory = edit.subCategory!.trim();
        _categoryTouched = true;
        if (![...kSipCategories]
            .any((c) => c.name.toLowerCase() == _subCategory.toLowerCase())) {
          _customCategories.add(_subCategory);
        }
      }
    } else if (widget.initialName != null &&
        widget.initialName!.trim().isNotEmpty) {
      _name.text = widget.initialName!.trim();
      _autoCategorise();
    }
    _name.addListener(() {
      _autoCategorise();
      setState(() {});
    });
    _amount.addListener(() => setState(() {}));
  }

  void _autoCategorise() {
    if (_categoryTouched) return;
    final guess = sipCategoryFor(_name.text.trim());
    if (guess != _subCategory) _subCategory = guess;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPlatform() async {
    // A curated shelf of investment platforms (Zerodha, Groww, AMCs, banks…).
    final brand =
        await showBrandPicker(context, mode: BrandPickerMode.platforms);
    if (brand != null) {
      setState(() {
        _iconName = brand.name;
        _iconDomain = brand.domain;
      });
    }
  }

  Future<void> _pickCurrency() async {
    final picked = await showCurrencyPicker(context, _currency);
    if (picked != null) {
      setState(() {
        _currency = picked;
        _amount.text =
            formatAmount(_amount.text, currencyOf(picked).grouping);
      });
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showCategoryPicker(
      context,
      categories: kSipCategories,
      selected: _subCategory,
      custom: _customCategories.toList(),
    );
    if (picked != null && picked.trim().isNotEmpty) {
      setState(() {
        _subCategory = picked.trim();
        _categoryTouched = true;
        final isBuiltIn = kSipCategories
            .any((c) => c.name.toLowerCase() == picked.trim().toLowerCase());
        if (!isBuiltIn) _customCategories.add(picked.trim());
      });
    }
  }

  /// The keyboard flow after the amount: open Category, then the date picker —
  /// so pressing "next" walks the user through every remaining step.
  Future<void> _flowAfterAmount() async {
    await _pickCategory();
    if (!mounted) return;
    await _pickDate();
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
    HapticFeedback.lightImpact();
    final amount =
        double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    // Weekdays only matter for a weekly repeat.
    final days = _cycle == RepeatCadence.weekly ? _days : const <int>[];
    final edit = widget.editTask;
    if (edit != null) {
      Navigator.of(context).pop(
        edit.copyWith(
          title: _name.text.trim(),
          dueAt: _nextDate,
          repeat: _cycle,
          repeatTimes: _times,
          repeatDays: days,
          iconName: _iconName,
          iconDomain: _iconDomain,
          amount: amount,
          clearAmount: amount == null,
          currency: _currency,
          category: TaskCategory.investment,
          subCategory: _subCategory,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      Task(
        id: 'new',
        title: _name.text.trim(),
        dueAt: _nextDate,
        repeat: _cycle,
        repeatTimes: _times,
        repeatDays: days,
        iconName: _iconName,
        iconDomain: _iconDomain,
        amount: amount,
        currency: _currency,
        storedCategory: TaskCategory.investment,
        subCategory: _subCategory,
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _dateLabel(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

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
                title: widget.editTask != null ? 'Edit SIP' : 'New SIP',
                canSave: _valid,
                onBack: () => Navigator.of(context).maybePop(),
                onSave: _save,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    // Identity: platform logo · name · SIP amount + currency.
                    OrbitIdentityCard(
                      iconName: _iconName,
                      iconDomain: _iconDomain,
                      nameController: _name,
                      nameFocus: _nameFocus,
                      amountController: _amount,
                      amountFocus: _amountFocus,
                      onPickIcon: _pickPlatform,
                      currency: _currency,
                      onPickCurrency: _pickCurrency,
                      nameHint: 'What are you investing in?',
                      amountHint: '5000',
                      emptyIcon: Icons.account_balance_rounded,
                      onAmountSubmitted: _flowAfterAmount,
                    ),
                    const SizedBox(height: 22),

                    // Details: category · next date · cycle.
                    OrbitGroupCard(
                      children: [
                        OrbitCategoryRow(
                          value: _subCategory,
                          onTap: _pickCategory,
                        ),
                        const OrbitRowDivider(),
                        OrbitNavRow(
                          label: 'Next SIP date',
                          value: _dateLabel(_nextDate),
                          onTap: _pickDate,
                        ),
                        const OrbitRowDivider(),
                        OrbitFrequencyField(
                          label: 'Every',
                          cycle: _cycle,
                          times: _times,
                          days: _days,
                          onCycle: (c) => setState(() => _cycle = c),
                          onTimes: (n) => setState(() => _times = n),
                          onDays: (d) => setState(() => _days = d),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'We’ll remind you before each instalment so you never miss a SIP.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
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
