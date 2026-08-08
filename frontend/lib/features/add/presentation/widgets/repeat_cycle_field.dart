import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';

/// A compact segmented control for a subscription's billing cadence — Weekly /
/// Monthly / Yearly — with the accent sliding under the chosen option.
class RepeatCycleField extends StatelessWidget {
  const RepeatCycleField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final RepeatCadence value;
  final ValueChanged<RepeatCadence> onChanged;
  final Color accent;

  static const _options = <(RepeatCadence, String)>[
    (RepeatCadence.weekly, 'Weekly'),
    (RepeatCadence.monthly, 'Monthly'),
    (RepeatCadence.yearly, 'Yearly'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _options.indexWhere((o) => o.$1 == value);
    final selected = index < 0 ? 1 : index; // default to Monthly

    return LayoutBuilder(
      builder: (context, c) {
        final segW = c.maxWidth / _options.length;
        return Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: segW * selected + 4,
                top: 4,
                bottom: 4,
                width: segW - 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (cadence, label) in _options)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (cadence != value) onChanged(cadence);
                        },
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cadence == value
                                  ? Colors.white
                                  : AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
