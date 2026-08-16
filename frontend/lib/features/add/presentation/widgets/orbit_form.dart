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

// ── Entrance cascade ─────────────────────────────────────────────────────────

/// A scrollable form body whose rows ARRIVE ONE AFTER ANOTHER — each card/field
/// eases up, fades, and gently settles a beat after the one above it, so opening
/// a form reads like the list assembling itself, not a dialog popping up.
///
/// Drop-in for a form's `ListView`: give it the same `padding` and `children`.
/// It runs its own entrance the first time it mounts (so the route transition
/// can stay a plain, quick fade — the CONTENT does the animating, not the page).
class OrbitFormCascade extends StatefulWidget {
  const OrbitFormCascade({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  State<OrbitFormCascade> createState() => _OrbitFormCascadeState();
}

class _OrbitFormCascadeState extends State<OrbitFormCascade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // A short beat so the page is painted before the cascade begins — the rows
    // are then clearly SEEN arriving one by one, not mid-transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      itemCount: widget.children.length,
      itemBuilder: (context, i) => _CascadeRow(
        intro: _intro,
        index: i,
        child: widget.children[i],
      ),
    );
  }
}

/// One form row's staggered arrival — mirrors the collection-list cascade: a
/// FIXED per-row delay (so every row gets the same generous window), then a
/// springy settle (ease up + in + scale, with a soft overshoot) and a fade.
class _CascadeRow extends StatelessWidget {
  const _CascadeRow({
    required this.intro,
    required this.index,
    required this.child,
  });

  final Animation<double> intro;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      builder: (context, child) {
        // A longer, more OVERLAPPING wave: rows start close together and each
        // takes its time, so the whole thing flows as one smooth motion instead
        // of discrete beats. No overshoot — a pure glide, so nothing "jumps".
        const perRow = 0.075; // small gap → rows overlap and flow into each other
        const maxStart = 0.5;
        const window = 0.5; // long, unhurried per-row settle
        final start = (index * perRow).clamp(0.0, maxStart);
        final raw = ((intro.value - start) / window).clamp(0.0, 1.0);
        // easeOutCubic: a soft, natural decelerate to rest — NO spring-back.
        final eased = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            // A gentle rise only — smaller travel, no sideways drift, no scale.
            // It simply slides up and settles, like the list but calmer.
            offset: Offset(0, 20 * (1 - eased)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

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

/// A full-width DELETE button for the BOTTOM of an edit form — a quiet red
/// outline (destructive but not shouty). Sits at the end of the scroll content,
/// shown only in edit mode. Tapping runs [onDelete] (which confirms + removes).
class OrbitDeleteButton extends StatelessWidget {
  const OrbitDeleteButton({super.key, required this.onDelete});
  final VoidCallback onDelete;

  static const _red = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GestureDetector(
        onTap: onDelete,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _red.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, size: 20, color: _red),
              SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet reassurance line — "save now, tweak later" — meant to sit just below
/// the identity block on an add form, so users don't hesitate before saving.
/// Low-contrast on purpose: it reassures without competing with the fields.
class OrbitSaveHint extends StatelessWidget {
  const OrbitSaveHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(6, 8, 6, 2),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 13, color: AppColors.inkFaint),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              'Just save — you can tweak any detail later.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkFaint,
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

// ── Frequency: "every [− N +] [unit ▾]" ──────────────────────────────────────

/// The "every N unit" control — a −/number/+ stepper and a unit dropdown
/// (minute · hour · day · week · month · year). Matches the reference exactly.
class OrbitFrequencyField extends StatelessWidget {
  const OrbitFrequencyField({
    super.key,
    required this.unit,
    required this.interval,
    required this.onUnit,
    required this.onInterval,
  });

  final RepeatCadence unit;
  final int interval;
  final ValueChanged<RepeatCadence> onUnit;
  final ValueChanged<int> onInterval;

  static const _min = 1;
  static const _max = 99;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          const Text('every', style: orbitLabelStyle),
          const SizedBox(width: 10),
          // The −/N/+ stepper.
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stepBtn(Icons.remove_rounded, interval > _min, () {
                  HapticFeedback.selectionClick();
                  onInterval(interval - 1);
                }),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$interval',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _stepBtn(Icons.add_rounded, interval < _max, () {
                  HapticFeedback.selectionClick();
                  onInterval(interval + 1);
                }),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // The unit dropdown pill — flexes so a long label ("minutes") can
          // shrink instead of overflowing the row.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _UnitDropdown(unit: unit, interval: interval, onUnit: onUnit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 20,
            color: enabled ? AppColors.accent : AppColors.inkFaint),
      ),
    );
  }
}

/// The tappable "day ▾" pill that opens a unit menu.
class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({
    required this.unit,
    required this.interval,
    required this.onUnit,
  });
  final RepeatCadence unit;
  final int interval;
  final ValueChanged<RepeatCadence> onUnit;

  String _label() {
    final u = unit == RepeatCadence.none ? RepeatCadence.daily : unit;
    return interval > 1 ? '${u.unit}s' : u.unit;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<RepeatCadence>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnitSheet(selected: unit),
    );
    if (picked != null) onUnit(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.expand_more_rounded,
                size: 16, color: AppColors.accent),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _label(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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

/// The unit menu (minute · hour · day · week · month · year).
class _UnitSheet extends StatelessWidget {
  const _UnitSheet({required this.selected});
  final RepeatCadence selected;

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
              const Text('Repeat unit',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 10),
              for (final u in kRepeatUnits)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(u),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: u == selected
                          ? AppColors.accent.withValues(alpha: 0.14)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: u == selected
                              ? AppColors.accent
                              : AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            u.unit[0].toUpperCase() + u.unit.substring(1),
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (u == selected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.accent, size: 22),
                      ],
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

/// The chosen frequency returned by [showFrequencyPicker].
class FrequencyResult {
  const FrequencyResult(this.unit, this.interval);
  final RepeatCadence unit;
  final int interval;
}

/// Opens the Frequency picker as a bottom sheet (joins the Category/Date flow).
/// Returns the chosen "every N unit", or null if dismissed.
Future<FrequencyResult?> showFrequencyPicker(
  BuildContext context, {
  required RepeatCadence unit,
  required int interval,
}) {
  return showModalBottomSheet<FrequencyResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _FrequencySheet(unit: unit, interval: interval),
  );
}

class _FrequencySheet extends StatefulWidget {
  const _FrequencySheet({required this.unit, required this.interval});
  final RepeatCadence unit;
  final int interval;

  @override
  State<_FrequencySheet> createState() => _FrequencySheetState();
}

class _FrequencySheetState extends State<_FrequencySheet> {
  late RepeatCadence _unit =
      widget.unit == RepeatCadence.none ? RepeatCadence.monthly : widget.unit;
  late int _interval = widget.interval < 1 ? 1 : widget.interval;

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
              Text(
                frequencyLabel(_unit, _interval),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: OrbitFrequencyField(
                  unit: _unit,
                  interval: _interval,
                  onUnit: (u) => setState(() => _unit = u),
                  onInterval: (n) => setState(() => _interval = n),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .pop(FrequencyResult(_unit, _interval)),
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
