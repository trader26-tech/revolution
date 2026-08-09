import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Opens the Orbit date picker — a fast, space-themed bottom sheet with three
/// snapping scroll wheels (day · month · year), a live preview of the chosen
/// date, and Today/Tomorrow shortcuts. Optimised for quick entry of ANY date,
/// from a far-past birthday to a next-year renewal.
///
/// Returns the chosen [DateTime] (date only, time zeroed), or null if dismissed.
Future<DateTime?> showOrbitDatePicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'Pick a date',
}) {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(now.year - 100, 1, 1);
  final last = lastDate ?? DateTime(now.year + 50, 12, 31);
  final seed = _clampDate(initial, first, last);

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrbitDatePicker(
      initial: seed,
      first: first,
      last: last,
      title: title,
    ),
  );
}

DateTime _clampDate(DateTime d, DateTime lo, DateTime hi) {
  if (d.isBefore(lo)) return lo;
  if (d.isAfter(hi)) return hi;
  return DateTime(d.year, d.month, d.day);
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

class _OrbitDatePicker extends StatefulWidget {
  const _OrbitDatePicker({
    required this.initial,
    required this.first,
    required this.last,
    required this.title,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_OrbitDatePicker> createState() => _OrbitDatePickerState();
}

class _OrbitDatePickerState extends State<_OrbitDatePicker> {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _wd = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  late int _day = widget.initial.day;
  late int _month = widget.initial.month; // 1-12
  late int _year = widget.initial.year;

  late final int _minYear = widget.first.year;
  late final int _maxYear = widget.last.year;

  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _minYear);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  DateTime get _selected => DateTime(_year, _month, _day);

  bool get _withinBounds =>
      !_selected.isBefore(DateTime(widget.first.year, widget.first.month, widget.first.day)) &&
      !_selected.isAfter(DateTime(widget.last.year, widget.last.month, widget.last.day));

  /// After any wheel change, clamp the day to the month's length (e.g. moving to
  /// February from the 31st snaps to 28/29) and keep the day wheel in sync.
  void _reconcileDay() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
      // Animate the day wheel to the clamped value.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dayCtrl.hasClients) _dayCtrl.jumpToItem(_day - 1);
      });
    }
  }

  void _setToDate(DateTime d) {
    HapticFeedback.selectionClick();
    setState(() {
      _year = d.year;
      _month = d.month;
      _day = d.day;
    });
    // Move every wheel to the new value.
    const dur = Duration(milliseconds: 260);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_yearCtrl.hasClients) {
        _yearCtrl.animateToItem(_year - _minYear,
            duration: dur, curve: Curves.easeOut);
      }
      if (_monthCtrl.hasClients) {
        _monthCtrl.animateToItem(_month - 1,
            duration: dur, curve: Curves.easeOut);
      }
      if (_dayCtrl.hasClients) {
        _dayCtrl.animateToItem(_day - 1, duration: dur, curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final today = DateTime.now();

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber.
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkFaint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              // Context title — tells the user WHICH date they're picking.
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Live preview — the big, human-readable date.
              Text(
                _wd[_selected.weekday - 1],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.accent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [AppColors.ink, Color(0xFFB9A8FF)],
                ).createShader(r),
                child: Text(
                  '$_day ${_months[_month - 1]} $_year',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // The three wheels with a highlighted centre band.
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centre selection band.
                    IgnorePointer(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        // Day.
                        Expanded(
                          flex: 3,
                          child: _Wheel(
                            controller: _dayCtrl,
                            count: _daysInMonth(_year, _month),
                            selectedIndex: _day - 1,
                            labelFor: (i) => '${i + 1}',
                            onSelected: (i) => setState(() {
                              _day = i + 1;
                            }),
                          ),
                        ),
                        // Month.
                        Expanded(
                          flex: 5,
                          child: _Wheel(
                            controller: _monthCtrl,
                            count: 12,
                            selectedIndex: _month - 1,
                            labelFor: (i) => _months[i],
                            onSelected: (i) => setState(() {
                              _month = i + 1;
                              _reconcileDay();
                            }),
                          ),
                        ),
                        // Year.
                        Expanded(
                          flex: 3,
                          child: _Wheel(
                            controller: _yearCtrl,
                            count: _maxYear - _minYear + 1,
                            selectedIndex: _year - _minYear,
                            labelFor: (i) => '${_minYear + i}',
                            onSelected: (i) => setState(() {
                              _year = _minYear + i;
                              _reconcileDay();
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick chip — jump to today.
              _Chip(
                label: 'Today',
                onTap: () => _setToDate(today),
              ),
              const SizedBox(height: 16),

              // Set button.
              GestureDetector(
                onTap: _withinBounds
                    ? () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop(_selected);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _withinBounds
                        ? const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDeep])
                        : null,
                    color: _withinBounds ? null : AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _withinBounds
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _withinBounds ? 'Set date' : 'Out of range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _withinBounds ? Colors.white : AppColors.inkFaint,
                    ),
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

/// One snapping wheel column with a fade top/bottom and haptic ticks.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.selectedIndex,
    required this.labelFor,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int selectedIndex;
  final String Function(int) labelFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0.0, 0.28, 0.72, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        perspective: 0.006,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          onSelected(i);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, i) {
            if (i < 0 || i >= count) return null;
            final selected = i == selectedIndex;
            return Center(
              child: Text(
                labelFor(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: selected ? 20 : 18,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.ink : AppColors.inkSoft,
                  letterSpacing: -0.3,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}
