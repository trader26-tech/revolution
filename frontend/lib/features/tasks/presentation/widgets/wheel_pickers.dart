import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A bottom sheet with a scroll-wheel DATE picker (day · month · year), styled
/// to match the app's other "down popups". Returns the chosen date, or null.
Future<DateTime?> showDateWheel(
  BuildContext context, {
  required DateTime initial,
  int yearsBack = 1,
  int yearsForward = 30,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WheelSheet(
      title: 'On',
      child: _DateWheel(
        initial: initial,
        min: DateTime(now.year - yearsBack, 1, 1),
        max: DateTime(now.year + yearsForward, 12, 31),
      ),
    ),
  );
}

/// A bottom sheet with a scroll-wheel TIME picker. Returns the chosen time
/// mapped onto [dateOf], or null.
Future<DateTime?> showTimeWheel(
  BuildContext context, {
  required DateTime initial,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WheelSheet(
      title: 'At',
      child: _TimeWheel(initial: initial),
    ),
  );
}

/// Shared chrome: a title row and the wheel below. Each wheel owns its current
/// value and pops itself via its Done button.
class _WheelSheet extends StatelessWidget {
  const _WheelSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// The DATE scroll wheel (day / month / year) + a Done button.
class _DateWheel extends StatefulWidget {
  const _DateWheel({
    required this.initial,
    required this.min,
    required this.max,
  });

  final DateTime initial;
  final DateTime min;
  final DateTime max;

  @override
  State<_DateWheel> createState() => _DateWheelState();
}

class _DateWheelState extends State<_DateWheel> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: const CupertinoThemeData(
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  fontSize: 20,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: widget.initial,
              minimumDate: widget.min,
              maximumDate: widget.max,
              onDateTimeChanged: (d) => _value = d,
            ),
          ),
        ),
        _DoneButton(onDone: () => Navigator.of(context).pop(_value)),
      ],
    );
  }
}

/// The TIME scroll wheel + a Done button. Keeps the original date, swaps time.
class _TimeWheel extends StatefulWidget {
  const _TimeWheel({required this.initial});

  final DateTime initial;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: const CupertinoThemeData(
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  fontSize: 20,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: widget.initial,
              use24hFormat: false,
              onDateTimeChanged: (d) => _value = DateTime(
                widget.initial.year,
                widget.initial.month,
                widget.initial.day,
                d.hour,
                d.minute,
              ),
            ),
          ),
        ),
        _DoneButton(onDone: () => Navigator.of(context).pop(_value)),
      ],
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: onDone, child: const Text('Done')),
      ),
    );
  }
}
