import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../details/domain/currency.dart';
import '../../../details/domain/currency_input.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/subscription_categories.dart';

/// Shared building blocks for the tailored "orbit" add/edit forms (Subscription,
/// SIP, …) so every form looks and behaves identically: the header + Save pill,
/// the identity card (logo · name · amount + currency), grouped rows, the
/// currency picker, and the category picker (with a custom-category flow).

const orbitLabelStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
);

// ── Header ───────────────────────────────────────────────────────────────────

class OrbitFormHeader extends StatelessWidget {
  const OrbitFormHeader({
    super.key,
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
                    color:
                        canSave ? Colors.transparent : AppColors.cardBorder),
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

// ── Identity card (logo · name · amount + currency) ──────────────────────────

class OrbitIdentityCard extends StatelessWidget {
  const OrbitIdentityCard({
    super.key,
    required this.iconName,
    required this.iconDomain,
    required this.nameController,
    required this.nameFocus,
    required this.amountController,
    required this.amountFocus,
    required this.onPickIcon,
    required this.currency,
    required this.onPickCurrency,
    this.nameHint = 'Name',
    this.amountHint = '0.00',
    this.emptyIcon = Icons.add_rounded,
    this.onAmountSubmitted,
  });

  final String? iconName;
  final String? iconDomain;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final TextEditingController amountController;
  final FocusNode amountFocus;
  final VoidCallback onPickIcon;
  final String currency;
  final VoidCallback onPickCurrency;
  final String nameHint;
  final String amountHint;
  final IconData emptyIcon;

  /// Called when the user presses the keyboard action on the amount field —
  /// the form uses it to continue the flow (e.g. open the category picker).
  /// When null, the amount's action just dismisses the keyboard.
  final VoidCallback? onAmountSubmitted;

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
                      size: 62,
                      bare: true,
                      circular: true,
                    )
                  : Icon(emptyIcon, color: AppColors.accent, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  focusNode: nameFocus,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: AppColors.accent,
                  // Keyboard "Next" jumps straight to the amount field, so the
                  // whole form fills in one flow without tapping each field.
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => amountFocus.requestFocus(),
                  // Tapping outside the fields dismisses the keyboard (opt out).
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: nameHint,
                    hintStyle: const TextStyle(
                      color: AppColors.inkFaint,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onPickCurrency,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currencyOf(currency).symbol,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.expand_more_rounded,
                                size: 15, color: AppColors.accent),
                          ],
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
                        // If the form wants to continue the flow after the
                        // amount (open the category picker), show "Next" and
                        // hand off; otherwise "Done" just closes the keyboard.
                        textInputAction: onAmountSubmitted != null
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: (_) {
                          FocusScope.of(context).unfocus();
                          onAmountSubmitted?.call();
                        },
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        inputFormatters: [
                          // Live grouping per the chosen currency (Indian for
                          // INR, Western for USD/KWD), with its decimal limit.
                          CurrencyAmountFormatter(
                            currencyOf(currency).grouping,
                            decimals: currencyOf(currency).decimals,
                          ),
                        ],
                        cursorColor: AppColors.accent,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: amountHint,
                          hintStyle: const TextStyle(
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

class OrbitGroupCard extends StatelessWidget {
  const OrbitGroupCard({super.key, required this.children});
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

class OrbitRowDivider extends StatelessWidget {
  const OrbitRowDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Divider(height: 1, color: AppColors.hairline),
      );
}

/// A row whose right side is a tappable value (opens a picker/date).
class OrbitNavRow extends StatelessWidget {
  const OrbitNavRow({
    super.key,
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
            Text(label, style: orbitLabelStyle),
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

/// The category row — shows the current category as an icon+label pill.
class OrbitCategoryRow extends StatelessWidget {
  const OrbitCategoryRow({super.key, required this.value, required this.onTap});
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
            const Text('Category', style: orbitLabelStyle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(subCategoryIcon(value),
                      size: 15, color: AppColors.accent),
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

/// The cycle row — an inline segmented Weekly/Monthly/Yearly picker.
class OrbitCycleRow extends StatelessWidget {
  const OrbitCycleRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Cycle',
  });
  final RepeatCadence value;
  final ValueChanged<RepeatCadence> onChanged;
  final String label;

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
          Text(label, style: orbitLabelStyle),
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
                for (final (cadence, text) in _options)
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
                        text,
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

// ── Frequency field (cycle · times · weekdays) ───────────────────────────────

/// A rich "Every" field: a base cycle (Weekly/Monthly/Yearly), how many TIMES
/// per cycle (1× / 2× / 3×), and — when Weekly — a row of weekday chips to pick
/// which days. Renders as its own rows so it fits inside a group card; the
/// weekday row animates in only for Weekly.
class OrbitFrequencyField extends StatelessWidget {
  const OrbitFrequencyField({
    super.key,
    required this.cycle,
    required this.times,
    required this.days,
    required this.onCycle,
    required this.onTimes,
    required this.onDays,
    this.label = 'Every',
  });

  final RepeatCadence cycle;
  final int times;
  final List<int> days; // 1=Mon … 7=Sun
  final ValueChanged<RepeatCadence> onCycle;
  final ValueChanged<int> onTimes;
  final ValueChanged<List<int>> onDays;
  final String label;

  static const _cycles = [
    (RepeatCadence.weekly, 'Weekly'),
    (RepeatCadence.monthly, 'Monthly'),
    (RepeatCadence.yearly, 'Yearly'),
  ];
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: the base cycle.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Text(label, style: orbitLabelStyle),
              const Spacer(),
              _Segmented(
                options: [
                  for (final (c, t) in _cycles) (c, t),
                ],
                isSelected: (c) => c == cycle,
                onTap: (c) {
                  HapticFeedback.selectionClick();
                  onCycle(c);
                },
              ),
            ],
          ),
        ),
        const OrbitRowDivider(),
        // Row 2: how many times per cycle.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              const Text('Times', style: orbitLabelStyle),
              const SizedBox(width: 6),
              // A live hint of what the choice means.
              Expanded(
                child: Text(
                  _timesHint(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkFaint,
                  ),
                ),
              ),
              _Segmented<int>(
                options: const [(1, '1×'), (2, '2×'), (3, '3×')],
                isSelected: (n) => n == times,
                onTap: (n) {
                  HapticFeedback.selectionClick();
                  onTimes(n);
                },
              ),
            ],
          ),
        ),
        // Row 3: weekday chips — only for Weekly.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: cycle == RepeatCadence.weekly
              ? Column(
                  children: [
                    const OrbitRowDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 13, 18, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('On days', style: orbitLabelStyle),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              for (var d = 1; d <= 7; d++)
                                _DayChip(
                                  letter: _dayLetters[d - 1],
                                  selected: days.contains(d),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    final next = [...days];
                                    if (next.contains(d)) {
                                      next.remove(d);
                                    } else {
                                      next.add(d);
                                    }
                                    onDays(next);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  String _timesHint() {
    if (times <= 1) return 'once a ${cycle.unit}';
    if (times == 2) return 'twice a ${cycle.unit}';
    return '$times times a ${cycle.unit}';
  }
}

/// A generic segmented control used by the frequency field.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.isSelected,
    required this.onTap,
  });
  final List<(T, String)> options;
  final bool Function(T) isSelected;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (val, text) in options)
            GestureDetector(
              onTap: () => onTap(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isSelected(val)
                      ? const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDeep])
                      : null,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected(val)
                        ? Colors.white
                        : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A round weekday chip (M T W T F S S).
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.letter,
    required this.selected,
    required this.onTap,
  });
  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDeep])
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.glassBorder,
          ),
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// The chosen frequency returned by [showFrequencyPicker].
class FrequencyResult {
  const FrequencyResult(this.cycle, this.times, this.days);
  final RepeatCadence cycle;
  final int times;
  final List<int> days;
}

/// Opens the Frequency picker as a bottom sheet (so it joins the same
/// step-through flow as Category and Date). Returns the chosen frequency, or
/// null if dismissed without confirming.
Future<FrequencyResult?> showFrequencyPicker(
  BuildContext context, {
  required RepeatCadence cycle,
  required int times,
  required List<int> days,
}) {
  return showModalBottomSheet<FrequencyResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _FrequencySheet(cycle: cycle, times: times, days: days),
  );
}

class _FrequencySheet extends StatefulWidget {
  const _FrequencySheet({
    required this.cycle,
    required this.times,
    required this.days,
  });
  final RepeatCadence cycle;
  final int times;
  final List<int> days;

  @override
  State<_FrequencySheet> createState() => _FrequencySheetState();
}

class _FrequencySheetState extends State<_FrequencySheet> {
  late RepeatCadence _cycle = widget.cycle;
  late int _times = widget.times;
  late List<int> _days = [...widget.days];

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _grabber()),
              const SizedBox(height: 16),
              const Text('Frequency',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              // A live, human summary of the current choice.
              Text(
                frequencyLabel(_cycle, _times, _days),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 12),
              // The same field, in a card for the sheet.
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: OrbitFrequencyField(
                  cycle: _cycle,
                  times: _times,
                  days: _days,
                  onCycle: (c) => setState(() => _cycle = c),
                  onTimes: (n) => setState(() => _times = n),
                  onDays: (d) => setState(() => _days = d),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(
                    FrequencyResult(_cycle, _times, _days)),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.accentDeep]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Currency picker ──────────────────────────────────────────────────────────

/// Opens the currency picker; returns the chosen code (INR/USD/KWD) or null.
Future<String?> showCurrencyPicker(BuildContext context, String selected) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _CurrencySheet(selected: selected),
  );
}

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
              _grabber(),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose a currency',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
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
              color: selected ? AppColors.accent : AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(currency.symbol,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currency.code,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  Text(currency.label,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft)),
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

// ── Category picker ──────────────────────────────────────────────────────────

/// Opens the category picker for a given [categories] list (each form passes its
/// own — subscription vs SIP buckets), plus any [custom] categories. Returns the
/// chosen name (a built-in, a custom, or a newly-typed one), or null.
Future<String?> showCategoryPicker(
  BuildContext context, {
  required List<SubCategory> categories,
  required String selected,
  required List<String> custom,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CategorySheet(
      categories: categories,
      selected: selected,
      custom: custom,
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.categories,
    required this.selected,
    required this.custom,
  });
  final List<SubCategory> categories;
  final String selected;
  final List<String> custom;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
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
    final builtIn = widget.categories.map((c) => c.name).toList();
    final all = <String>[
      ...builtIn,
      ...widget.custom.where((c) => !builtIn.contains(c)),
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
              _grabber(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Choose a category',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _addCustom,
                    behavior: HitTestBehavior.opaque,
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18, color: AppColors.accent),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
              color: selected ? AppColors.accent : AppColors.cardBorder),
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
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
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
                const Text('New category',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
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
                        color: AppColors.ink),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Retirement, Kids, Tax…',
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
                    child: const Text('Add category',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
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

Widget _grabber() => Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.inkFaint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
    );
