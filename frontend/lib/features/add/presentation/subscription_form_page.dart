import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../../core/widgets/starfield.dart';
import '../../brand/data/brand_catalog.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_picker_sheet.dart';
import '../../details/domain/currency.dart';
import '../../tasks/domain/task.dart';
import '../domain/subscription_categories.dart';
import 'widgets/orbit_form.dart';

/// The Subscription form — modelled on the reference: an identity card (logo +
/// name + price), a grouped details card (first payment · cycle · free trial),
/// and a notification card. Space-themed, purple accent, no picture. Every row
/// is one tap; the whole thing is fast to fill.
///
/// Optionally seeded with an [initialName]/[initialCycle] when opened from a
/// catalog item. Returns a ready-to-save [Task], or null if cancelled.
class SubscriptionFormPage extends StatefulWidget {
  const SubscriptionFormPage({
    super.key,
    this.initialBrand,
    this.initialName,
    this.initialCycle,
    this.title,
    this.accent, // kept for call-site compatibility; the form is always accent
    this.editTask,
  });

  final Brand? initialBrand;
  final String? initialName;
  final RepeatCadence? initialCycle;
  final String? title;
  final Color? accent;

  /// When set, the form opens in EDIT mode pre-filled from this task and its
  /// Save returns an updated copy (same id) instead of a brand-new task.
  final Task? editTask;

  @override
  State<SubscriptionFormPage> createState() => _SubscriptionFormPageState();
}

class _SubscriptionFormPageState extends State<SubscriptionFormPage> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();

  String? _iconName;
  String? _iconDomain;
  bool _iconTouched = false; // user picked a logo manually → stop auto-icon
  String _currency = 'INR'; // INR · USD · KWD
  late RepeatCadence _cycle = widget.initialCycle ?? RepeatCadence.monthly;
  DateTime _firstPayment = DateTime.now();
  bool _freeTrial = false;
  int _remindDaysBefore = 1; // Notification lead time

  String _subCategory = kOtherSubCategory; // auto-filled, editable
  bool _categoryTouched = false; // user overrode → stop auto-filling
  bool _priceTouched = false; // user typed a price → stop auto-filling it
  bool _cycleTouched = false; // user changed the cycle → stop auto-filling it
  final Set<String> _customCategories = {}; // categories the user added

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTask;
    if (edit != null) {
      // EDIT mode — prefill everything from the existing task.
      _name.text = edit.title;
      _iconName = edit.iconName;
      _iconDomain = edit.iconDomain;
      // Keep the saved logo/price/cycle — don't let type-ahead override them.
      if (edit.hasIcon) _iconTouched = true;
      if (edit.hasAmount) {
        final plain = edit.amount!.toStringAsFixed(
            edit.amount == edit.amount!.roundToDouble() ? 0 : 2);
        _amount.text =
            formatAmount(plain, currencyOf(edit.currency).grouping);
      }
      _priceTouched = true;
      _cycleTouched = true;
      _currency = edit.currency;
      _cycle = edit.repeat == RepeatCadence.none
          ? RepeatCadence.monthly
          : edit.repeat;
      if (edit.dueAt != null) _firstPayment = edit.dueAt!;
      if (edit.subCategory != null && edit.subCategory!.trim().isNotEmpty) {
        _subCategory = edit.subCategory!.trim();
        _categoryTouched = true; // respect the saved category
        if (!kSubCategories
            .any((c) => c.name.toLowerCase() == _subCategory.toLowerCase())) {
          _customCategories.add(_subCategory);
        }
      }
    } else {
      final b = widget.initialBrand;
      if (b != null) {
        _iconName = b.name;
        _iconDomain = b.domain;
        _name.text = b.name;
      } else if (widget.initialName != null &&
          widget.initialName!.trim().isNotEmpty) {
        _name.text = widget.initialName!.trim();
      }
      _autoCategorise();
    }
    _name.addListener(() {
      _autoCategorise();
      _autoIcon();
      _autoPlan();
      setState(() {});
    });
    // If the USER types in the price field, stop auto-filling it. Programmatic
    // fills (from _autoPlan) set _settingPrice so they don't trip this.
    _amount.addListener(() {
      if (!_settingPrice && _amount.text.isNotEmpty) _priceTouched = true;
    });
  }

  bool _settingPrice = false; // true while _autoPlan writes the price field

  /// Pre-fill a typical price + cycle for a known subscription (unless the user
  /// has already edited them). "Netflix" → ₹499 / Monthly, "Prime" → ₹1499 /
  /// Yearly, etc. Gives the user a real starting number.
  void _autoPlan() {
    final plan = subscriptionDefault(_name.text.trim());
    if (plan == null) return;
    if (!_cycleTouched) _cycle = plan.cycle;
    if (!_priceTouched) {
      // A 0 default (e.g. bundled free perks) → leave blank rather than "0".
      final plain = plan.price > 0
          ? plan.price.toStringAsFixed(
              plan.price == plan.price.roundToDouble() ? 0 : 2)
          : '';
      // Group it into the current currency's format (matches the live typing).
      final text = formatAmount(plain, currencyOf(_currency).grouping);
      if (_amount.text != text) {
        _settingPrice = true; // mark this as a programmatic write
        _amount.text = text;
        _settingPrice = false;
      }
    }
  }

  /// Set the category from the typed/picked name — unless the user has manually
  /// chosen one (then we respect their choice).
  void _autoCategorise() {
    if (_categoryTouched) return;
    final guess = subCategoryFor(_name.text.trim());
    if (guess != _subCategory) _subCategory = guess;
  }

  /// Auto-resolve the logo as the user types — "Netflix" pops the Netflix icon
  /// instantly. Only for KNOWN brands (resolveKnown returns an empty domain for
  /// unrecognised names, so we never fetch a blank favicon). Skipped once the
  /// user has manually chosen a logo.
  void _autoIcon() {
    if (_iconTouched) return;
    final query = _name.text.trim();
    if (query.isEmpty) {
      _iconName = null;
      _iconDomain = null;
      return;
    }
    final brand = BrandCatalog.resolveSubscription(query);
    if (brand.domain.isNotEmpty) {
      _iconName = brand.name;
      _iconDomain = brand.domain;
    } else {
      // Unknown name → clear any previously auto-set logo (keeps it honest).
      _iconName = null;
      _iconDomain = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final brand = await showBrandPicker(context, subscriptionsOnly: true);
    if (brand != null) {
      setState(() {
        _iconTouched = true; // a manual pick wins over the type-ahead icon
        _iconName = brand.name;
        _iconDomain = brand.domain;
        if (_name.text.trim().isEmpty) _name.text = brand.name;
        // Auto-categorise from the picked brand (icon + category together),
        // unless the user has manually overridden the category.
        if (!_categoryTouched) _subCategory = subCategoryFor(brand.name);
      });
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(
        selected: _subCategory,
        custom: _customCategories.toList(),
      ),
    );
    if (picked != null && picked.trim().isNotEmpty) {
      setState(() {
        _subCategory = picked.trim();
        _categoryTouched = true; // stop auto-filling once chosen
        final isBuiltIn = kSubCategories
            .any((c) => c.name.toLowerCase() == picked.trim().toLowerCase());
        if (!isBuiltIn) _customCategories.add(picked.trim());
      });
    }
  }

  /// The keyboard flow after the amount: open Category, then the date picker.
  Future<void> _flowAfterAmount() async {
    await _pickCategory();
    if (!mounted) return;
    await _pickDate();
  }

  Future<void> _pickCurrency() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencySheet(selected: _currency),
    );
    if (picked != null) {
      setState(() {
        _currency = picked;
        // Re-group the existing amount into the new currency's format.
        _amount.text =
            formatAmount(_amount.text, currencyOf(picked).grouping);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showOrbitDatePicker(
      context,
      initial: _firstPayment,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
      title: 'Next payment date',
    );
    if (picked != null) setState(() => _firstPayment = picked);
  }

  void _save() {
    if (!_valid) return;
    HapticFeedback.lightImpact();
    final amount =
        double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    final edit = widget.editTask;
    if (edit != null) {
      // EDIT — return a copy with the same id so store.update patches it.
      Navigator.of(context).pop(
        edit.copyWith(
          title: _name.text.trim(),
          dueAt: _firstPayment,
          repeat: _cycle,
          iconName: _iconName,
          iconDomain: _iconDomain,
          amount: amount,
          clearAmount: amount == null,
          currency: _currency,
          category: TaskCategory.subscription,
          subCategory: _subCategory,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      Task(
        id: 'new',
        title: _name.text.trim(),
        dueAt: _firstPayment,
        repeat: _cycle,
        iconName: _iconName,
        iconDomain: _iconDomain,
        amount: amount,
        currency: _currency,
        storedCategory: TaskCategory.subscription,
        subCategory: _subCategory,
      ),
    );
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
              _Header(
                title: widget.editTask != null
                    ? 'Edit Subscription'
                    : (widget.title ?? 'Add Subscription'),
                canSave: _valid,
                onBack: () => Navigator.of(context).maybePop(),
                onSave: _save,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    // ── Identity: logo + name + price ──
                    OrbitIdentityCard(
                      iconName: _iconName,
                      iconDomain: _iconDomain,
                      nameController: _name,
                      nameFocus: _nameFocus,
                      amountController: _amount,
                      amountFocus: _amountFocus,
                      onPickIcon: _pickIcon,
                      currency: _currency,
                      onPickCurrency: _pickCurrency,
                      onAmountSubmitted: _flowAfterAmount,
                    ),
                    const SizedBox(height: 22),

                    // ── Details: category · next payment · cycle · free trial ──
                    _GroupCard(
                      children: [
                        _CategoryRow(
                          value: _subCategory,
                          onTap: _pickCategory,
                        ),
                        const _RowDivider(),
                        _NavRow(
                          label: 'Next payment',
                          value: _dateLabel(_firstPayment),
                          onTap: _pickDate,
                        ),
                        const _RowDivider(),
                        _CycleRow(
                          value: _cycle,
                          onChanged: (c) => setState(() {
                            _cycle = c;
                            _cycleTouched = true; // stop auto-filling the cycle
                          }),
                        ),
                        const _RowDivider(),
                        _ToggleRow(
                          label: 'Free trial',
                          value: _freeTrial,
                          onChanged: (v) => setState(() => _freeTrial = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── Notification lead time ──
                    _GroupCard(
                      children: [
                        _NotifyRow(
                          days: _remindDaysBefore,
                          onChanged: (d) =>
                              setState(() => _remindDaysBefore = d),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _freeTrial
                            ? 'We’ll warn you before the trial ends and it starts charging.'
                            : 'We’ll remind you before each payment so nothing surprises you.',
                        style: const TextStyle(
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

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _dateLabel(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.canSave,
    required this.onBack,
    required this.onSave,
  });
  final String title;
  final bool canSave;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.ink,
              ),
            ),
          ),
          // Save pill — accent when ready, muted when the name's empty.
          GestureDetector(
            onTap: canSave ? onSave : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: canSave
                    ? const LinearGradient(
                        colors: [AppColors.accent, AppColors.accentDeep])
                    : null,
                color: canSave ? null : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: canSave
                        ? Colors.transparent
                        : AppColors.cardBorder),
                boxShadow: canSave
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: canSave ? Colors.white : AppColors.inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: AppColors.ink, size: 22),
      ),
    );
  }
}

// ── Grouped card + rows ──────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Divider(height: 1, color: AppColors.hairline),
      );
}

/// A row whose right side is a tappable value (opens a picker/date).
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          children: [
            Text(label, style: _labelStyle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The category row — shows the current sub-category as an icon+label pill and
/// opens the category picker on tap.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            const Text('Category', style: _labelStyle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(subCategoryIcon(value), size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.expand_more_rounded,
                      size: 15, color: AppColors.inkSoft),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The billing-cycle row — a segmented inline picker (tap to cycle through, or
/// long-press-free chips). Kept to the common four so it's one tap.
class _CycleRow extends StatelessWidget {
  const _CycleRow({required this.value, required this.onChanged});
  final RepeatCadence value;
  final ValueChanged<RepeatCadence> onChanged;

  static const _options = [
    (RepeatCadence.weekly, 'Weekly'),
    (RepeatCadence.monthly, 'Monthly'),
    (RepeatCadence.yearly, 'Yearly'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          const Text('Cycle', style: _labelStyle),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (cadence, label) in _options)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(cadence);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: value == cadence
                            ? const LinearGradient(colors: [
                                AppColors.accent,
                                AppColors.accentDeep
                              ])
                            : null,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: value == cadence
                              ? Colors.white
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled toggle row.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Text(label, style: _labelStyle),
          const Spacer(),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeTrackColor: AppColors.accent,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// The notification lead-time row — a stepper over sensible presets.
class _NotifyRow extends StatelessWidget {
  const _NotifyRow({required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  static const _presets = [0, 1, 2, 3, 7];

  String _label(int d) => switch (d) {
        0 => 'On the day',
        1 => '1 day before',
        _ => '$d days before',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          const Text('Notification', style: _labelStyle),
          const Spacer(),
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: () {
              final i = _presets.indexOf(days);
              if (i > 0) {
                HapticFeedback.selectionClick();
                onChanged(_presets[i - 1]);
              }
            },
          ),
          SizedBox(
            width: 108,
            child: Text(
              _label(days),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: () {
              final i = _presets.indexOf(days);
              if (i < _presets.length - 1) {
                HapticFeedback.selectionClick();
                onChanged(_presets[i + 1]);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
);

// ── Currency picker sheet ────────────────────────────────────────────────────

/// A compact bottom sheet to choose the price currency (INR · USD · KWD).
class _CurrencySheet extends StatelessWidget {
  const _CurrencySheet({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkFaint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Currency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final c in kCurrencies)
                _CurrencyRow(
                  currency: c,
                  selected: c.code == selected,
                  onTap: () => Navigator.of(context).pop(c.code),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.currency,
    required this.selected,
    required this.onTap,
  });
  final Currency currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            // Symbol badge.
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                currency.symbol,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.code,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    currency.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Category picker sheet ────────────────────────────────────────────────────

/// Choose a subscription category — the 8 built-ins plus any the user added,
/// with an "Add category" action to create a custom one. Returns the chosen
/// category name, or null if dismissed.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.selected, required this.custom});
  final String selected;
  final List<String> custom;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final List<String> _custom = [...widget.custom];

  Future<void> _addCustom() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewCategorySheet(),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      Navigator.of(context).pop(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final builtIn = kSubCategories.map((c) => c.name).toList();
    final all = <String>[
      ...builtIn,
      ..._custom.where((c) => !builtIn.contains(c)),
    ];

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkFaint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _addCustom,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // A clean vertical LIST of categories (not chips). Capped height
              // so long lists scroll instead of overflowing the sheet.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  itemCount: all.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CategoryListRow(
                    name: all[i],
                    selected: all[i] == widget.selected,
                    onTap: () => Navigator.of(context).pop(all[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category as a full-width list row — icon · name · check when selected.
class _CategoryListRow extends StatelessWidget {
  const _CategoryListRow({
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(subCategoryIcon(name),
                  size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

/// A tiny sheet to name a new custom category.
class _NewCategorySheet extends StatefulWidget {
  const _NewCategorySheet();

  @override
  State<_NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends State<_NewCategorySheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textCapitalization: TextCapitalization.words,
                    cursorColor: AppColors.accent,
                    onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. News, Kids, Work…',
                      hintStyle: TextStyle(color: AppColors.inkFaint),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pop(_controller.text.trim()),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDeep]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Add category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
