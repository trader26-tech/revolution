import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_category.dart';
import 'reminder_confirm_sheet.dart';

/// A single checkbox row on the one-page onboarding list.
///
/// Unticked, it's a slim tappable row. Ticked, it expands IN PLACE to reveal
/// compact detail fields — name, day-of-month, and frequency — so the user
/// fills everything on the same screen, no navigation. Untick to collapse.
class ReminderRow extends StatelessWidget {
  const ReminderRow({
    super.key,
    required this.category,
    required this.draft,
    required this.onToggle,
    required this.onChanged,
  });

  final OnboardingCategory category;

  /// The staged draft, or null when unticked.
  final ReminderDraft? draft;

  /// Tick / untick.
  final VoidCallback onToggle;

  /// Called with the edited draft while ticked.
  final ValueChanged<ReminderDraft> onChanged;

  bool get _selected => draft != null;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _selected ? c.color.withValues(alpha: 0.06) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selected ? c.color.withValues(alpha: 0.5) : AppColors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // The always-visible checkbox row.
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onToggle();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: _selected ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(c.icon, color: c.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _selected ? AppColors.ink : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  _Checkbox(selected: _selected, color: c.color),
                ],
              ),
            ),
          ),
          // The inline detail fields, revealed when ticked.
          if (_selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _Details(
                accent: c.color,
                draft: draft!,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.selected, required this.color});
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? color : AppColors.inkFaint,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// Compact, on-page detail fields: name + day dropdown + frequency dropdown.
class _Details extends StatelessWidget {
  const _Details({
    required this.accent,
    required this.draft,
    required this.onChanged,
  });

  final Color accent;
  final ReminderDraft draft;
  final ValueChanged<ReminderDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name.
        _NameField(
          key: ValueKey('name_${draft.name}_${identityHashCode(draft)}'),
          initial: draft.name,
          accent: accent,
          onChanged: (v) => onChanged(ReminderDraft(
            name: v,
            day: draft.day,
            frequency: draft.frequency,
          )),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Day-of-month.
            Expanded(
              child: _Pill(
                label: 'Day',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: draft.day,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text(_ordinal(d))),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      HapticFeedback.selectionClick();
                      onChanged(ReminderDraft(
                        name: draft.name,
                        day: v,
                        frequency: draft.frequency,
                      ));
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Frequency.
            Expanded(
              child: _Pill(
                label: 'Repeats',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RepeatCadence>(
                    value: draft.frequency,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: RepeatCadence.monthly, child: Text('Monthly')),
                      DropdownMenuItem(
                          value: RepeatCadence.yearly, child: Text('Yearly')),
                      DropdownMenuItem(
                          value: RepeatCadence.weekly, child: Text('Weekly')),
                      DropdownMenuItem(
                          value: RepeatCadence.none, child: Text('One-time')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      HapticFeedback.selectionClick();
                      onChanged(ReminderDraft(
                        name: draft.name,
                        day: draft.day,
                        frequency: v,
                      ));
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({
    super.key,
    required this.initial,
    required this.accent,
    required this.onChanged,
  });
  final String initial;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintText: 'Name',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.accent, width: 1.6),
        ),
      ),
    );
  }
}

/// A labelled container that frames a compact dropdown.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.inkFaint,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

String _ordinal(int d) {
  if (d >= 11 && d <= 13) return '${d}th';
  switch (d % 10) {
    case 1:
      return '${d}st';
    case 2:
      return '${d}nd';
    case 3:
      return '${d}rd';
    default:
      return '${d}th';
  }
}
