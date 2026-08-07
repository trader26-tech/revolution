import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';

/// A segmented pill for choosing how often a reminder repeats. The selected
/// segment slides under the label (animated), with a haptic tick per change.
class FrequencyPicker extends StatelessWidget {
  const FrequencyPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = AppColors.accent,
  });

  final RepeatCadence value;
  final ValueChanged<RepeatCadence> onChanged;
  final Color accent;

  // The options offered during onboarding, in order.
  static const _options = <(RepeatCadence, String)>[
    (RepeatCadence.monthly, 'Monthly'),
    (RepeatCadence.yearly, 'Yearly'),
    (RepeatCadence.weekly, 'Weekly'),
    (RepeatCadence.none, 'One-time'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _options.indexWhere((o) => o.$1 == value);
    final selected = index < 0 ? 0 : index;

    return LayoutBuilder(
      builder: (context, c) {
        final segW = c.maxWidth / _options.length;
        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Stack(
            children: [
              // Sliding selection.
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
                          if (cadence != value) {
                            HapticFeedback.selectionClick();
                            onChanged(cadence);
                          }
                        },
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.5,
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
