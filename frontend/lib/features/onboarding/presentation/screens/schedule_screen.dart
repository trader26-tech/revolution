import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/magic_text.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// Revo's per-category question — the category is baked into the ask, so he
/// speaks it directly ("When should we remind you about your subscriptions?")
/// rather than showing a separate category label.
String _questionFor(OnboardingChipSection s) => switch (s.key) {
  'subs' => 'When should we remind\nyou about your subscriptions?',
  'docs' => 'When should we remind\nyou about these documents?',
  'family' => "When are your\nfamily's special days?",
  'insure' => 'When are these\nrenewals due?',
  'invest' => 'When should we remind\nyou about these investments?',
  _ => 'When should we\nremind you?',
};

/// Onboarding page 4 — the SCHEDULE step: when to remind you.
///
/// The user has said WHAT to remember (page 2); here they say WHEN. We walk them
/// through it one category at a time (only the categories they actually picked).
/// Revo greets from the top-left and ASKS the category's question directly — it
/// materialises word by word, the same bubble effect as the chip wizard ("When
/// are your family's special days?"). No separate category label or sub-copy;
/// the question carries the context.
///
/// Each picked item reads as a plain-English SENTENCE you skim, not a form:
/// "Netflix — Every month · Mid-month", already filled from smart defaults.
/// Tapping the card opens ONE simple sheet with plain-English how-often options
/// (Every month / 3 months / 6 months / Once a year) and Start / Mid / End
/// day-of-month presets (with a "Pick exact day" escape hatch to the calendar
/// grid). Glance and go — the user only touches what's wrong. Above the button,
/// a momentum line ("3 more to go" … "Last one") mirrors the wizard; the button
/// fills as they advance the categories, reading "Finish" on the last one and
/// firing [onFinish] with a ready-to-save draft per picked item.
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

  /// Forward momentum above the button — how many categories are still ahead
  /// AFTER this one: "3 more to go" … "1 more to go" … then "Last one". Mirrors
  /// the chip wizard's language so the two steps read as one journey.
  String _remainingPhrase() {
    final remaining = _sections.length - 1 - _index;
    if (remaining <= 0) return 'Last one';
    return '$remaining more to go';
  }

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
        // Timeline (0..1): Revo pops (0..0.24), his question MATERIALISES word
        // by word (0.24..0.6, the same bubble effect as the chip wizard), then
        // the cards cascade in. No sub-copy — Revo's question carries the ask.
        const questionStart = 0.24;
        const questionEnd = 0.60;
        // Rows cascade across [rowsStart .. lastRowStart]; the last row STARTS
        // at lastRowStart and, with its reveal window, completes by 1.0 — so no
        // card is left stuck at partial opacity.
        const rowsStart = 0.60;
        const rowWindow = 0.26;
        const lastRowStart = 1.0 - rowWindow; // 0.74
        final perRow = items.length > 1
            ? (lastRowStart - rowsStart) / (items.length - 1)
            : 0.0;

        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  // Header: Revo (tail-left) + his question, which materialises
                  // word by word (the same bubble effect as the chip wizard).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        // Tail points left to lean into the content.
                        child: RevoEntrance(
                          t: _p(0.0, 0.24),
                          child: Transform.flip(
                            flipX: true,
                            child: const AnimatedMascot(size: 56, glow: false),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: MagicText(
                            // Keyed by category so it restarts on each change.
                            key: ValueKey(section.key),
                            text: _questionFor(section),
                            progress: _p(questionStart, questionEnd),
                            style: const TextStyle(
                              fontSize: 25,
                              height: 1.16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // One card per picked item in this category, cascading in.
                  for (var i = 0; i < items.length; i++)
                    _reveal(
                      rowsStart + perRow * i,
                      window: rowWindow,
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
            // Bottom: reassurance + the filling Continue/Finish button. Its
            // reveal must COMPLETE within the 0..1 timeline (start + window <=
            // 1.0), or the button caps at a fraction of full opacity and reads
            // as missing. 0.72 + 0.28 == 1.0.
            _reveal(
              0.72,
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
                    // Forward momentum — how many categories are left to set up,
                    // matching the chip wizard's "N more to go" language.
                    Text(
                      _remainingPhrase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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

/// Plain-English "how often" for a times-per-year value — the same words used
/// in the picker, so the card sentence and the options always match.
String _freqLabel(int timesPerYear) => switch (timesPerYear) {
      1 => 'Once a year',
      2 => 'Every 6 months',
      4 => 'Every 3 months',
      6 => 'Every 2 months',
      _ => 'Every month',
    };

/// Short month names, 1-indexed via [_monthNames[m - 1]].
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The full calendar date as a human string — "15 Mar".
String _dateLabel(int month, int day) =>
    '$day ${_monthNames[(month - 1).clamp(0, 11)]}';

/// Days in a (non-leap) month, so the day wheel never offers the 31st of Feb.
int _daysInMonth(int month) => switch (month) {
      2 => 29, // allow the 29th; leap-year exactness isn't needed for a reminder
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };

/// One picked item, shown as a plain-English SENTENCE you skim — the icon and
/// name on top, and under it "Every month · 15 Mar", already filled from smart
/// defaults. Tapping the whole card opens one sheet: plain-English how-often
/// options + a quick month/day wheel. Glance and go — only touch what's wrong.
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

  Future<void> _edit(BuildContext context) async {
    HapticFeedback.selectionClick();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ScheduleSheet(name: item.label, draft: draft),
    );
    if (changed == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _edit(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item.icon, size: 20, color: AppColors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_freqLabel(draft.timesPerYear)} · ${_dateLabel(draft.month, draft.day)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.inkFaint.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The single edit sheet for one item — how often (plain-English options) and
/// the date on a quick MONTH + DAY wheel. Full calendar date so it reads the
/// same for monthly ("the 15th") and yearly ("15 March") — one consistent,
/// flick-to-set control. One sheet, both settings.
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.name, required this.draft});
  final String name;
  final ReminderDraft draft;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late int _times = widget.draft.timesPerYear;
  late int _month = widget.draft.month.clamp(1, 12);
  late int _day = widget.draft.day.clamp(1, 31);

  static const _freqOptions = <(int, String)>[
    (12, 'Every month'),
    (4, 'Every 3 months'),
    (2, 'Every 6 months'),
    (1, 'Once a year'),
  ];

  void _save() {
    widget.draft
      ..timesPerYear = _times
      ..month = _month
      ..day = _day.clamp(1, _daysInMonth(_month));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              // A live echo of the full choice so the meaning is always spelled
              // out as they spin — "Every month · 15 Mar".
              Text(
                '${_freqLabel(_times)} · ${_dateLabel(_month, _day)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 20),
              const _SheetLabel('How often?'),
              const SizedBox(height: 10),
              // How often — a compact wrap of pill options (quick to tap).
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (times, label) in _freqOptions)
                    _FreqPill(
                      label: label,
                      selected: _times == times,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _times = times);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _SheetLabel('On this date'),
              const SizedBox(height: 6),
              // The month + day wheels — flick to set. Clamped so the day never
              // exceeds the month's length.
              _DateWheels(
                month: _month,
                day: _day,
                onChanged: (m, d) => setState(() {
                  _month = m;
                  _day = d;
                }),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

/// The month + day scroll wheels — an iOS-style flick-to-set date control. Two
/// side-by-side wheels; changing the month re-clamps the day so you can never
/// land on the 31st of a 30-day month.
class _DateWheels extends StatefulWidget {
  const _DateWheels({
    required this.month,
    required this.day,
    required this.onChanged,
  });

  final int month; // 1..12
  final int day; // 1..31
  final void Function(int month, int day) onChanged;

  @override
  State<_DateWheels> createState() => _DateWheelsState();
}

class _DateWheelsState extends State<_DateWheels> {
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    _monthCtrl = FixedExtentScrollController(initialItem: widget.month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: widget.day - 1);
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final month = _monthCtrl.selectedItem + 1;
    final maxDay = _daysInMonth(month);
    var day = _dayCtrl.selectedItem + 1;
    if (day > maxDay) {
      day = maxDay;
      // Snap the day wheel back into range for the shorter month.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dayCtrl.jumpToItem(day - 1);
      });
    }
    widget.onChanged(month, day);
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = _daysInMonth(_monthCtrl.hasClients
        ? _monthCtrl.selectedItem + 1
        : widget.month);
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The selection band — a soft accent row the centred value sits in.
          Center(
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Wheel(
                  controller: _monthCtrl,
                  count: 12,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    _emit();
                  },
                  labelFor: (i) => _monthNames[i],
                ),
              ),
              Expanded(
                flex: 2,
                child: _Wheel(
                  controller: _dayCtrl,
                  count: maxDay,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    _emit();
                  },
                  labelFor: (i) => '${i + 1}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One scroll wheel column used inside [_DateWheels].
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.onSelected,
    required this.labelFor,
  });

  final FixedExtentScrollController controller;
  final int count;
  final ValueChanged<int> onSelected;
  final String Function(int index) labelFor;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 40,
      perspective: 0.004,
      diameterRatio: 1.4,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) {
          if (i < 0 || i >= count) return null;
          return Center(
            child: Text(
              labelFor(i),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small muted section label inside the edit sheet.
class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.inkSoft,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// A pill option for the how-often choice.
class _FreqPill extends StatelessWidget {
  const _FreqPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.cardBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

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
