import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';

/// A premium "every [ − N + ] [ unit ▾ ]" repeat control.
///
/// Replaces the flat frequency pills with the natural-language stepper: a count
/// stepper on the left, a unit dropdown on the right. Reads "every 1 day",
/// "every 2 weeks", "every 6 months" — the way people actually think about a
/// recurring reminder. Both pieces are pill-shaped, dark, and lift with the
/// accent when touched, matching the Orbit language.
///
/// The unit maps to the app's [RepeatCadence]; [count] is the interval (the
/// existing `every` field on a draft). A count of 1 with a unit is the plain
/// cadence ("every day" == daily); higher counts are the interval ("every 2
/// weeks").
class RepeatEveryPicker extends StatelessWidget {
  const RepeatEveryPicker({
    super.key,
    required this.count,
    required this.unit,
    required this.onCountChanged,
    required this.onUnitChanged,
    this.accent = AppColors.accent,
  });

  /// The interval multiplier — "every [count] units". Clamped to 1..99.
  final int count;

  /// The repeat unit. [RepeatCadence.none] is treated as a one-time reminder and
  /// hides the count (there's no interval to repeat).
  final RepeatCadence unit;

  final ValueChanged<int> onCountChanged;
  final ValueChanged<RepeatCadence> onUnitChanged;
  final Color accent;

  // The units offered, in ascending order, with their singular labels. The
  // dropdown pluralises based on [count].
  static const _units = <(RepeatCadence, String)>[
    (RepeatCadence.daily, 'day'),
    (RepeatCadence.weekly, 'week'),
    (RepeatCadence.monthly, 'month'),
    (RepeatCadence.yearly, 'year'),
    (RepeatCadence.none, 'one-time'),
  ];

  static String _labelFor(RepeatCadence u, int n) {
    final base = _units.firstWhere((e) => e.$1 == u).$2;
    if (u == RepeatCadence.none) return 'one-time';
    return n == 1 ? base : '${base}s';
  }

  bool get _isOneTime => unit == RepeatCadence.none;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // "every" lead-in — quiet, so the controls carry the emphasis.
        if (!_isOneTime) ...[
          const Text(
            'every',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(width: 12),
          // The count stepper.
          _Stepper(
            count: count,
            accent: accent,
            onChanged: onCountChanged,
          ),
          const SizedBox(width: 12),
        ],
        // The unit dropdown — fills the remaining width so it never feels cramped.
        Expanded(child: _UnitDropdown(
          unit: unit,
          count: count,
          accent: accent,
          onChanged: onUnitChanged,
        )),
      ],
    );
  }
}

/// A dark pill with −/+ ends and a big tabular number between them.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.count,
    required this.accent,
    required this.onChanged,
  });

  final int count;
  final Color accent;
  final ValueChanged<int> onChanged;

  void _bump(int delta) {
    final next = (count + delta).clamp(1, 99);
    if (next != count) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: count > 1,
            accent: accent,
            onTap: () => _bump(-1),
          ),
          // The count — tabular so the pill width doesn't jitter 9→10.
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: count < 99,
            accent: accent,
            onTap: () => _bump(1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 46,
          height: 52,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? accent : AppColors.inkFaint,
          ),
        ),
      ),
    );
  }
}

/// The unit dropdown — a dark pill showing the current unit + a chevron, opening
/// a themed menu (day / week / month / year / one-time).
class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({
    required this.unit,
    required this.count,
    required this.accent,
    required this.onChanged,
  });

  final RepeatCadence unit;
  final int count;
  final Color accent;
  final ValueChanged<RepeatCadence> onChanged;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Menu surface in the Orbit palette.
      data: Theme.of(context).copyWith(
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.08),
      ),
      child: PopupMenuButton<RepeatCadence>(
        onSelected: (u) {
          HapticFeedback.selectionClick();
          onChanged(u);
        },
        offset: const Offset(0, 56),
        color: AppColors.card,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        itemBuilder: (context) => [
          for (final (u, _) in RepeatEveryPicker._units)
            PopupMenuItem<RepeatCadence>(
              value: u,
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      RepeatEveryPicker._labelFor(u, count),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            u == unit ? FontWeight.w800 : FontWeight.w600,
                        color: u == unit ? AppColors.ink : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  if (u == unit)
                    Icon(Icons.check_rounded, size: 18, color: accent),
                ],
              ),
            ),
        ],
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  RepeatEveryPicker._labelFor(unit, count),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 22, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
