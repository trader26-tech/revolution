import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/day_knob.dart';
import '../widgets/frequency_picker.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// Onboarding page 4 — the SCHEDULE step: "Now, when should we remind you?"
///
/// The user has said WHAT to remember (page 2); here they say WHEN. We walk
/// them through it one category at a time (only the categories they actually
/// picked), each showing its picked items as a card carrying the three knobs
/// that matter: the day-of-month, how often it repeats, and — for repeating
/// ones — the "every N" interval (every 2 months, etc.).
///
/// Everything arrives pre-filled from the catalog's smart defaults, so the user
/// usually just glances, tweaks the odd date, and taps Continue. The button
/// fills as they advance the categories (same language as the chip wizard); on
/// the last one it reads "Finish" and fires [onFinish] with a ready-to-save
/// draft per picked item.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.picked,
    required this.drafts,
    this.onFinish,
  });

  /// The chip keys the user picked on page 2.
  final Set<String> picked;

  /// The live draft map (day/frequency/every), keyed by chip key. Edited in
  /// place here so the parent keeps the values; seeded from the catalog.
  final Map<String, ReminderDraft> drafts;

  /// Fired on the last category's "Finish" — the parent turns the drafts into
  /// real tasks and lands the user in the app. Null in previews.
  final ValueChanged<Map<String, ReminderDraft>>? onFinish;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Per-category entry cascade — replays on each category change.
  late final AnimationController _intro;
  final _scroll = ScrollController();

  /// Only the sections that have at least one picked item — the ones we walk.
  late List<OnboardingChipSection> _sections;

  @override
  void initState() {
    super.initState();
    _rebuildSections();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  @override
  void didUpdateWidget(covariant ScheduleScreen old) {
    super.didUpdateWidget(old);
    // Picks can change if the user backed up and edited page 2, so recompute the
    // walked sections and clamp the index.
    _rebuildSections();
    if (_index >= _sections.length) _index = math.max(0, _sections.length - 1);
  }

  void _rebuildSections() {
    _sections = [
      for (final s in kOnboardingChipSections)
        if (s.items.any((i) => widget.picked.contains(i.key))) s,
    ];
  }

  @override
  void dispose() {
    _intro.dispose();
    _scroll.dispose();
    super.dispose();
  }

  OnboardingChipSection get _section => _sections[_index];

  List<OnboardingChipItem> get _pickedItems =>
      _section.items.where((i) => widget.picked.contains(i.key)).toList();

  bool get _isLast => _index >= _sections.length - 1;

  void _next() {
    HapticFeedback.lightImpact();
    if (_isLast) {
      widget.onFinish?.call(widget.drafts);
      return;
    }
    setState(() => _index++);
    _replay();
  }

  void _replay() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _intro
      ..reset()
      ..forward();
  }

  double _p(double start, double end) =>
      ((_intro.value - start) / (end - start)).clamp(0.0, 1.0);

  Widget _reveal(double start, Widget child, {double window = 0.28}) {
    final t = Curves.easeOutCubic
        .transform(((_intro.value - start) / window).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    );
  }

  /// The reminder draft for [key], creating one from catalog defaults on first
  /// touch so the map always has an entry to edit.
  ReminderDraft _draftFor(OnboardingChipItem item) {
    return widget.drafts.putIfAbsent(
      item.key,
      () => ReminderDraft(
        name: item.defaultName,
        day: item.defaultDay,
        frequency: item.defaultFrequency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold/Starfield here — renders inside OnboardingFlow's sky.
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        final section = _section;
        final items = _pickedItems;
        const rowsStart = 0.46;
        final perRow = (0.98 - rowsStart) / math.max(1, items.length);

        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  // Header: Revo (tail-left) + the question.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        child: Opacity(
                          opacity: Curves.easeOut.transform(_p(0.0, 0.22)),
                          child: Transform.scale(
                            scale: 0.4 +
                                0.6 *
                                    Curves.easeOutBack.transform(_p(0.0, 0.24)),
                            // Tail points left to lean into the content.
                            child: Transform.flip(
                              flipX: true,
                              child: const AnimatedMascot(size: 56, glow: false),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _reveal(
                          0.14,
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'When should we\nremind you?',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    height: 1.14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _section.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _reveal(
                    0.30,
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        "Pick the day and how often — we'll do the rest.",
                        style: TextStyle(fontSize: 14.5, color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // One card per picked item in this category, cascading in.
                  for (var i = 0; i < items.length; i++)
                    _reveal(
                      rowsStart + perRow * i,
                      _ItemScheduleCard(
                        key: ValueKey('${section.key}:${items[i].key}'),
                        item: items[i],
                        draft: _draftFor(items[i]),
                        onChanged: () => setState(() {}),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom: reassurance + the filling Continue/Finish button.
            _reveal(
              0.9,
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bg.withValues(alpha: 0.0),
                      AppColors.bg.withValues(alpha: 0.85),
                      AppColors.bg,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Change any of this '),
                          TextSpan(
                            text: 'anytime in the app.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FillButton(
                      label: _isLast ? 'Finish' : 'Continue',
                      // Fill reflects how far through the categories we are.
                      progress: (_index + 1) / _sections.length,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One picked item's schedule card: name + icon, a day-of-month pill (opens the
/// DayKnob sheet), the frequency picker, and — for repeating cadences — an
/// "every N" interval stepper.
class _ItemScheduleCard extends StatelessWidget {
  const _ItemScheduleCard({
    super.key,
    required this.item,
    required this.draft,
    required this.onChanged,
  });

  final OnboardingChipItem item;
  final ReminderDraft draft;
  final VoidCallback onChanged;

  /// Cadences that a "every N" interval makes sense for.
  static const _intervalCadences = {
    RepeatCadence.weekly,
    RepeatCadence.monthly,
    RepeatCadence.yearly,
  };

  String _unitFor(RepeatCadence f, int n) => switch (f) {
        RepeatCadence.weekly => n == 1 ? 'week' : 'weeks',
        RepeatCadence.monthly => n == 1 ? 'month' : 'months',
        RepeatCadence.yearly => n == 1 ? 'year' : 'years',
        RepeatCadence.daily => n == 1 ? 'day' : 'days',
        RepeatCadence.none => '',
      };

  Future<void> _editDay(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DayPickerSheet(name: item.defaultName, initial: draft.day),
    );
    if (picked != null) {
      draft.day = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repeats = _intervalCadences.contains(draft.frequency);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: icon + name + the day pill.
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _DayPill(day: draft.day, onTap: () => _editDay(context)),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: frequency.
          FrequencyPicker(
            value: draft.frequency,
            onChanged: (f) {
              draft.frequency = f;
              // "every N" only applies to repeating cadences; reset otherwise.
              if (!_intervalCadences.contains(f)) draft.every = 1;
              onChanged();
            },
          ),
          // Row 3: the "every N" interval, only for repeating cadences.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: repeats
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _EveryStepper(
                      value: draft.every,
                      unit: _unitFor(draft.frequency, draft.every),
                      onChanged: (n) {
                        draft.every = n;
                        onChanged();
                      },
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The little "17th" day pill on a card — tap to open the knob.
class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.onTap});
  final int day;
  final VoidCallback onTap;

  static String _ordinal(int d) {
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_rounded,
                  size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                _ordinal(day),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A −/N/+ stepper for the "every N …" interval. Clamps to 1..12.
class _EveryStepper extends StatelessWidget {
  const _EveryStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  static const _min = 1;
  static const _max = 12;

  void _bump(int delta) {
    final next = (value + delta).clamp(_min, _max);
    if (next != value) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Every',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
        const Spacer(),
        _RoundBtn(
          icon: Icons.remove_rounded,
          enabled: value > _min,
          onTap: () => _bump(-1),
        ),
        SizedBox(
          width: 78,
          child: Text(
            value == 1 ? unit : '$value $unit',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        _RoundBtn(
          icon: Icons.add_rounded,
          enabled: value < _max,
          onTap: () => _bump(1),
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: AppColors.accent.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// The day-of-month picker in a sheet, built around the polished [DayKnob].
class _DayPickerSheet extends StatefulWidget {
  const _DayPickerSheet({required this.name, required this.initial});
  final String name;
  final int initial;

  @override
  State<_DayPickerSheet> createState() => _DayPickerSheetState();
}

class _DayPickerSheetState extends State<_DayPickerSheet> {
  late int _day = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Which day for ${widget.name}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            DayKnob(
              day: _day,
              size: 240,
              onChanged: (d) => setState(() => _day = d),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_day),
                child: const Text(
                  'Set day',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Continue/Finish button that fills left-to-right to show how far through
/// the categories the user is — the same language as the chip wizard's button.
class _FillButton extends StatelessWidget {
  const _FillButton({
    required this.label,
    required this.progress,
    required this.onPressed,
  });

  final String label;
  final double progress; // 0..1
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: AppColors.accentDeep,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The brighter fill sweeping across [progress] of the width.
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.accentDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
