import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_category.dart';
import 'day_knob.dart';
import 'frequency_picker.dart';

/// The things a reminder needs, captured in onboarding.
class ReminderDraft {
  ReminderDraft({
    required this.name,
    required this.day,
    required this.frequency,
    this.month = 1,
    this.every = 1,
  });

  String name;
  int day; // day-of-month 1–31

  /// Month 1–12. Meaningful for yearly reminders (the actual date, "15 March");
  /// for monthly it just seeds which month the first reminder lands in.
  int month;

  RepeatCadence frequency;

  /// The interval multiplier for [frequency] — "every N weeks/months/…". 1 is
  /// the plain cadence (every month); 2 is "every 2 months", etc. UI-ONLY for
  /// now: the server task model doesn't carry an interval yet, so this is
  /// captured and shown but not persisted. See onboarding schedule screen.
  int every;

  /// How many times a year this reminder fires — the single dial the onboarding
  /// schedule screen exposes. Reading it collapses (frequency, every) back to a
  /// count; writing it picks the cleanest (frequency, every) that yields that
  /// count. The supported values are the presets 1, 2, 4, 6, 12 (yearly →
  /// monthly), so any stored pair maps to one of them.
  int get timesPerYear {
    final perYear = switch (frequency) {
      RepeatCadence.yearly => 1,
      RepeatCadence.monthly => 12,
      RepeatCadence.weekly => 52,
      RepeatCadence.daily => 365,
      RepeatCadence.none => 1,
    };
    final n = (perYear / (every < 1 ? 1 : every)).round();
    return n < 1 ? 1 : n;
  }

  set timesPerYear(int times) {
    // 1/yr is a clean yearly; everything else is monthly-with-an-interval so the
    // day-of-month stays meaningful (every N months on the chosen day).
    if (times <= 1) {
      frequency = RepeatCadence.yearly;
      every = 1;
    } else {
      frequency = RepeatCadence.monthly;
      every = (12 / times).round().clamp(1, 12);
    }
  }
}

/// A premium sheet to confirm/adjust one reminder — name, the semicircular
/// day-of-month knob, and the frequency. Pre-filled from the category's smart
/// defaults, so the user usually just glances and taps Save. Returns the edited
/// [ReminderDraft], or null if dismissed.
Future<ReminderDraft?> showReminderConfirmSheet(
  BuildContext context, {
  required OnboardingCategory category,
  ReminderDraft? initial,
}) {
  return showModalBottomSheet<ReminderDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ConfirmSheet(category: category, initial: initial),
  );
}

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.category, this.initial});
  final OnboardingCategory category;
  final ReminderDraft? initial;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? widget.category.defaultName,
  );
  late int _day = widget.initial?.day ?? widget.category.defaultDay;
  late RepeatCadence _freq =
      widget.initial?.frequency ?? widget.category.defaultFrequency;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(ReminderDraft(
      name: _name.text.trim().isEmpty
          ? widget.category.defaultName
          : _name.text.trim(),
      day: _day,
      frequency: _freq,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Category chip header.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(c.icon, color: c.color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // The knob date picker — the hero.
            DayKnob(
              day: _day,
              accent: c.color,
              onChanged: (d) => setState(() => _day = d),
            ),
            const SizedBox(height: 4),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name.
                  const _FieldLabel('NAME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.bg,
                      hintText: c.defaultName,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.color, width: 2),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Frequency.
                  const _FieldLabel('HOW OFTEN'),
                  const SizedBox(height: 8),
                  FrequencyPicker(
                    value: _freq,
                    accent: c.color,
                    onChanged: (f) => setState(() => _freq = f),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Save',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.inkFaint,
      ),
    );
  }
}
