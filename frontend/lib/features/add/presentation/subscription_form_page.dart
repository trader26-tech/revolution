import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/starfield.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../../brand/presentation/brand_picker_sheet.dart';
import '../../tasks/domain/task.dart';

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
  });

  final Brand? initialBrand;
  final String? initialName;
  final RepeatCadence? initialCycle;
  final String? title;
  final Color? accent;

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
  late RepeatCadence _cycle = widget.initialCycle ?? RepeatCadence.monthly;
  DateTime _firstPayment = DateTime.now();
  bool _freeTrial = false;
  int _remindDaysBefore = 1; // Notification lead time

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
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
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final brand = await showBrandPicker(context, subscriptionsOnly: true);
    if (brand != null) {
      setState(() {
        _iconName = brand.name;
        _iconDomain = brand.domain;
        if (_name.text.trim().isEmpty) _name.text = brand.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstPayment,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
      helpText: 'First payment date',
    );
    if (picked != null) setState(() => _firstPayment = picked);
  }

  void _save() {
    if (!_valid) return;
    HapticFeedback.lightImpact();
    final amount =
        double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    Navigator.of(context).pop(
      Task(
        id: 'new',
        title: _name.text.trim(),
        dueAt: _firstPayment,
        repeat: _cycle,
        iconName: _iconName,
        iconDomain: _iconDomain,
        amount: amount,
        currency: 'INR',
        storedCategory: TaskCategory.subscription,
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
                title: widget.title ?? 'Add Subscription',
                canSave: _valid,
                onBack: () => Navigator.of(context).maybePop(),
                onSave: _save,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    // ── Identity: logo + name + price ──
                    _IdentityCard(
                      iconName: _iconName,
                      iconDomain: _iconDomain,
                      nameController: _name,
                      nameFocus: _nameFocus,
                      amountController: _amount,
                      amountFocus: _amountFocus,
                      onPickIcon: _pickIcon,
                    ),
                    const SizedBox(height: 22),

                    // ── Details: first payment · cycle · free trial ──
                    _GroupCard(
                      children: [
                        _NavRow(
                          label: 'First payment',
                          value: _dateLabel(_firstPayment),
                          onTap: _pickDate,
                        ),
                        const _RowDivider(),
                        _CycleRow(
                          value: _cycle,
                          onChanged: (c) => setState(() => _cycle = c),
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

// ── Identity card (logo + name + price) ──────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.iconName,
    required this.iconDomain,
    required this.nameController,
    required this.nameFocus,
    required this.amountController,
    required this.amountFocus,
    required this.onPickIcon,
  });

  final String? iconName;
  final String? iconDomain;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final TextEditingController amountController;
  final FocusNode amountFocus;
  final VoidCallback onPickIcon;

  @override
  Widget build(BuildContext context) {
    final hasIcon = (iconName != null && iconName!.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo picker — a big round tap target (subscriptions-only picker).
          GestureDetector(
            onTap: onPickIcon,
            child: Container(
              width: 62,
              height: 62,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasIcon
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : AppColors.cardBorder,
                  width: hasIcon ? 1.5 : 1,
                ),
              ),
              child: hasIcon
                  ? BrandLogo(
                      brand: Brand(name: iconName!, domain: iconDomain ?? ''),
                      size: 40,
                      circular: true,
                    )
                  : const Icon(Icons.add_rounded,
                      color: AppColors.accent, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name.
                TextField(
                  controller: nameController,
                  focusNode: nameFocus,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: AppColors.accent,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Name',
                    hintStyle: TextStyle(
                      color: AppColors.inkFaint,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                // Price — a ₹ badge + amount, on one line.
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: amountController,
                        focusNode: amountFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        cursorColor: AppColors.accent,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: AppColors.inkFaint,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
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
