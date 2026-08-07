import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_category.dart';
import '../widgets/day_knob.dart';
import '../widgets/frequency_picker.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// A FULL SCREEN to enter one reminder's details — name, the semicircular
/// knob date picker, and frequency. Used to walk the user through each selected
/// category, one screen at a time, after the gallery.
///
/// [index]/[total] drive the "2 of 5" progress. The button says "Next" until
/// the last one, then "Done".
class ReminderDetailScreen extends StatefulWidget {
  const ReminderDetailScreen({
    super.key,
    required this.category,
    required this.draft,
    required this.index,
    required this.total,
    required this.onNext,
    this.onBack,
  });

  final OnboardingCategory category;
  final ReminderDraft draft;
  final int index;
  final int total;

  /// Called with the (possibly edited) draft when the user taps Next/Done.
  final ValueChanged<ReminderDraft> onNext;
  final VoidCallback? onBack;

  @override
  State<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.draft.name);
  late int _day = widget.draft.day;
  late RepeatCadence _freq = widget.draft.frequency;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onNext(ReminderDraft(
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
    final isLast = widget.index == widget.total - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back + "N of M" progress.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: widget.onBack == null
                        ? Colors.transparent
                        : AppColors.inkSoft,
                  ),
                  const Spacer(),
                  Text(
                    '${widget.index + 1} of ${widget.total}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header.
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: c.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(c.icon, color: c.color, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.label,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const Text(
                                'When is it due?',
                                style: TextStyle(color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // The knob — hero, centred.
                    Center(
                      child: DayKnob(
                        day: _day,
                        accent: c.color,
                        onChanged: (d) => setState(() => _day = d),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name.
                    const _Label('NAME'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _fieldDecoration(c.color, widget.category.defaultName),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Frequency.
                    const _Label('HOW OFTEN'),
                    const SizedBox(height: 8),
                    FrequencyPicker(
                      value: _freq,
                      accent: c.color,
                      onChanged: (f) => setState(() => _freq = f),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom action.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Done' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(Color accent, String hint) => InputDecoration(
        filled: true,
        fillColor: AppColors.card,
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: accent, width: 2),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.inkFaint,
        ),
      );
}
