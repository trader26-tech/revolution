import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// "How often each year" — a friendly, compact dial for choosing how many times
/// a year a reminder fires, without the abstract monthly/yearly/weekly language.
///
/// It's a single row of preset pills — 1× · 2× · 4× · 6× · 12× — with a bright
/// accent that SLIDES to the chosen one, and a short human caption underneath
/// that names what the choice means ("once a year", "every month"). Tapping a
/// pill picks it (with a haptic tick); no repeated +/− tapping, no sheet — one
/// glance, one tap. Occupies just two short lines of height.
class YearFrequencyPicker extends StatelessWidget {
  const YearFrequencyPicker({
    super.key,
    required this.timesPerYear,
    required this.onChanged,
    this.accent = AppColors.accent,
  });

  /// The current value — snapped to the nearest preset for display.
  final int timesPerYear;
  final ValueChanged<int> onChanged;
  final Color accent;

  /// The presets, each with its short pill label and the human caption shown
  /// under the row when it's selected.
  static const _options = <(int times, String pill, String caption)>[
    (1, '1×', 'Once a year'),
    (2, '2×', 'Twice a year'),
    (4, '4×', 'Every 3 months'),
    (6, '6×', 'Every 2 months'),
    (12, '12×', 'Every month'),
  ];

  /// Index of the preset nearest the current value, so any stored count lands on
  /// a sensible pill.
  int get _selected {
    var best = 0;
    var bestDist = (_options[0].$1 - timesPerYear).abs();
    for (var i = 1; i < _options.length; i++) {
      final d = (_options[i].$1 - timesPerYear).abs();
      if (d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A muted lead-in so the row reads as an answer to a question.
        const Text(
          'How often each year',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 8),
        // The pill row with a sliding accent behind the chosen preset.
        LayoutBuilder(
          builder: (context, c) {
            final segW = c.maxWidth / _options.length;
            return Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
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
                            color: accent.withValues(alpha: 0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _options.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final times = _options[i].$1;
                              if (times != timesPerYear) {
                                HapticFeedback.selectionClick();
                                onChanged(times);
                              }
                            },
                            child: Center(
                              child: Text(
                                _options[i].$2,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: i == selected
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
        ),
        const SizedBox(height: 6),
        // The human caption for the current choice — swaps with a soft fade so
        // the meaning is always spelled out under the abstract "N×".
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _options[selected].$3,
            key: ValueKey(_options[selected].$3),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}
