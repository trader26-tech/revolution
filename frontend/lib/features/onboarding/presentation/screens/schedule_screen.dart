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
/// Each picked item is a compact one-line card that reads like a form field:
/// the NAME on the left, and on the SAME line two small settable buttons — the
/// DAY ("15th") and HOW OFTEN ("Monthly"). Tapping the day opens a calendar
/// grid; tapping the frequency opens a preset list. Both arrive pre-filled from
/// the catalog's smart defaults, so the user usually just glances, taps the odd
/// value, and continues. Above the button, a momentum line ("3 more to go" …
/// "Last one") mirrors the wizard; the button fills as they advance the
/// categories, reading "Finish" on the last one and firing [onFinish] with a
/// ready-to-save draft per picked item.
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

String _ordinal(int d) {
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

/// A short label for a "times per year" preset — shown on the frequency button.
String _freqShort(int timesPerYear) => switch (timesPerYear) {
      1 => 'Yearly',
      2 => 'Twice a yr',
      4 => 'Quarterly',
      6 => 'Every 2 mo',
      _ => 'Monthly',
    };

/// One picked item's schedule card — designed to read like a form field the
/// user just fills: the NAME on the left, and on the SAME line two compact
/// value buttons on the right — the DAY ("15th") and HOW OFTEN ("Monthly").
/// Tapping either opens a focused picker (a calendar-grid for the day, a preset
/// list for the frequency). Minimal height, both settings at a glance.
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

  Future<void> _editDay(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DayPickerSheet(name: item.label, initial: draft.day),
    );
    if (picked != null) {
      draft.day = picked;
      onChanged();
    }
  }

  Future<void> _editFreq(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          _FreqPickerSheet(name: item.label, initial: draft.timesPerYear),
    );
    if (picked != null) {
      draft.timesPerYear = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 19, color: AppColors.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The two settable buttons, on one line.
          _ValueButton(
            icon: Icons.event_rounded,
            value: _ordinal(draft.day),
            onTap: () => _editDay(context),
          ),
          const SizedBox(width: 6),
          _ValueButton(
            icon: Icons.repeat_rounded,
            value: _freqShort(draft.timesPerYear),
            onTap: () => _editFreq(context),
          ),
        ],
      ),
    );
  }
}

/// A compact settable pill — an icon + its current value — that opens a picker
/// on tap. Two of these sit on one line (day + how-often) per item.
class _ValueButton extends StatelessWidget {
  const _ValueButton({
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
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

/// A small shared sheet chrome — grab handle, a title that names the item so
/// the user always knows WHAT they're setting, and the given body + confirm.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.body,
    required this.onConfirm,
    this.confirmLabel = 'Done',
  });

  final String title;
  final Widget body;
  final VoidCallback onConfirm;
  final String confirmLabel;

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
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            body,
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onConfirm,
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day-of-month picker — a clean CALENDAR GRID (1–31 in 7 columns). The
/// chosen day is a filled accent circle; tapping any day selects it with a
/// haptic tick. Reads like a real calendar, not an abstract dial.
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
    return _PickerSheet(
      title: 'What day is ${widget.name}?',
      confirmLabel: 'Set to ${_ordinal(_day)}',
      onConfirm: () => Navigator.of(context).pop(_day),
      body: _DayGrid(
        selected: _day,
        onPick: (d) {
          HapticFeedback.selectionClick();
          setState(() => _day = d);
        },
      ),
    );
  }
}

/// The 1–31 calendar grid.
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.selected, required this.onPick});
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 31,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final day = i + 1;
        final isSel = day == selected;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? AppColors.accent : AppColors.cardBorder,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSel ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The "how often" picker sheet — the same friendly year presets as a tidy
/// list, each naming what it means in plain words.
class _FreqPickerSheet extends StatefulWidget {
  const _FreqPickerSheet({required this.name, required this.initial});
  final String name;
  final int initial;

  @override
  State<_FreqPickerSheet> createState() => _FreqPickerSheetState();
}

class _FreqPickerSheetState extends State<_FreqPickerSheet> {
  late int _times = widget.initial;

  static const _options = <(int, String, String)>[
    (1, 'Once a year', 'Yearly'),
    (2, 'Twice a year', 'Every 6 months'),
    (4, 'Four times a year', 'Every 3 months'),
    (6, 'Six times a year', 'Every 2 months'),
    (12, 'Every month', '12 times a year'),
  ];

  @override
  Widget build(BuildContext context) {
    // Snap the stored value to the nearest preset for the initial highlight.
    return _PickerSheet(
      title: 'How often is ${widget.name}?',
      confirmLabel: 'Done',
      onConfirm: () => Navigator.of(context).pop(_times),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (times, title, sub) in _options)
            _FreqRow(
              title: title,
              subtitle: sub,
              selected: times == _times,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _times = times);
              },
            ),
        ],
      ),
    );
  }
}

class _FreqRow extends StatelessWidget {
  const _FreqRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.cardBorder,
                width: selected ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.accent : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.inkFaint.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
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
