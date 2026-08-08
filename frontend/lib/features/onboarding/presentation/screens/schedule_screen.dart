import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mascot.dart';
import '../../../brand/domain/brand.dart';
import '../../../brand/presentation/brand_logo.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_chip_catalog.dart';
import '../widgets/magic_text.dart' show MagicText, RevoEntrance;
import '../widgets/reminder_confirm_sheet.dart';
import '../widgets/repeat_every_picker.dart';

/// Onboarding page 4 — the SCHEDULE step: when to remind you.
///
/// ONE scrollable screen, matching page 2's shape. Revo greets from the
/// top-left with a single question; below him the picked items scroll as a
/// SECTIONED list — a header per category (SUBSCRIPTIONS, DOCUMENTS, …) with its
/// picked items' schedule cards under it. Each card reads as a plain-English
/// sentence ("Netflix — Every month · 15 Mar"), pre-filled from smart defaults;
/// tapping it opens one sheet (how-often pills + a month/day wheel). Glance and
/// go — only touch what's wrong. One "Finish" at the bottom fires [onFinish]
/// with the ready-to-save drafts.
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

  /// Fired on "Finish" — the parent turns the drafts into real tasks and lands
  /// the user in the app. Null in previews.
  final ValueChanged<Map<String, ReminderDraft>>? onFinish;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  /// One-shot entrance, timed in ABSOLUTE MILLISECONDS so the reveal is a clean
  /// top-to-bottom WATERFALL — identical choreography to page 2:
  ///   0..500     Revo enters.  —— pause ——
  ///   900..1900  the question MATERIALISES word by word (shimmer).  —— pause ——
  ///   2300       the tagline, then EACH row (header, then each card) fades in
  ///              one after another a fixed [_beatGap] apart, in reading order.
  late final AnimationController _intro;
  final _scroll = ScrollController();

  /// Only the sections that have at least one picked item — the ones we show.
  late List<OnboardingChipSection> _sections;

  static const _revoMs = 500;
  static const _questionStartMs = 900;
  static const _questionEndMs = 1900;
  static const _taglineMs = 2300;
  static const _cascadeStartMs = 2600;
  static const _beatGap = 140;
  static const _beatWindow = 340;

  int get _beatCount =>
      _sections.fold(0, (n, s) => n + 1 + _pickedItems(s).length);

  int get _totalMs =>
      _cascadeStartMs + ((_beatCount - 1).clamp(0, 1 << 30)) * _beatGap +
          _beatWindow;

  double get _ms => _intro.value * _totalMs;

  @override
  void initState() {
    super.initState();
    _rebuildSections();
    _intro = AnimationController(vsync: this, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _intro.duration = Duration(milliseconds: _totalMs);
      _intro.forward();
    });
  }

  @override
  void didUpdateWidget(covariant ScheduleScreen old) {
    super.didUpdateWidget(old);
    // Picks can change if the user backed up and edited page 2.
    _rebuildSections();
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

  List<OnboardingChipItem> _pickedItems(OnboardingChipSection s) =>
      s.items.where((i) => widget.picked.contains(i.key)).toList();

  /// 0→1 progress across an absolute ms window — for MagicText's shimmer and the
  /// fixed-phase reveals.
  double _win(num startMs, num endMs) =>
      ((_ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

  Widget _reveal(num startMs, Widget child, {num window = _beatWindow}) {
    // Entrance over → everything is permanently visible. Without this, a row
    // that scrolls into view AFTER the intro finished (a lower section built
    // lazily by ListView) computes opacity from a past window and renders
    // invisible — the "missing columns" bug.
    if (_intro.isCompleted) return child;
    final t = Curves.easeOutCubic.transform(_win(startMs, startMs + window));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    );
  }

  /// A header/card's entrance in the waterfall, starting at absolute [startMs].
  Widget _beatReveal(num startMs, Widget child) {
    if (_intro.isCompleted) return child;
    final raw = _win(startMs, startMs + _beatWindow);
    final ease = Curves.easeOutCubic.transform(raw);
    final spring = Curves.easeOutBack.transform(raw);
    return Opacity(
      opacity: ease,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - ease)),
        child: Transform.scale(
          scale: 0.9 + 0.1 * spring,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }

  /// The reminder draft for [item], creating one from catalog defaults on first
  /// touch so the map always has an entry to edit.
  ReminderDraft _draftFor(OnboardingChipItem item) {
    return widget.drafts.putIfAbsent(
      item.key,
      // Prefill to the NEXT upcoming date from today, not a stale catalog
      // default — so onboarding in August shows "10 Sep", not "10 Jan".
      () => ReminderDraft.smart(
        name: item.defaultName,
        defaultDay: item.defaultDay,
        frequency: item.defaultFrequency,
        now: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Each row's beat is derived STATICALLY from its position in the list (each
    // section contributes 1 header + its cards), NOT from build order. ListView
    // builds rows lazily as they scroll into view, so a build-order cursor would
    // hand a lower section — built late — the wrong (or a past) start time,
    // rendering its cards invisible. Position-derived beats are stable forever.
    final sectionBaseBeat = <int>[];
    var acc = 0;
    for (final s in _sections) {
      sectionBaseBeat.add(acc);
      acc += 1 + _pickedItems(s).length; // header + cards
    }
    num startOf(int beat) => _cascadeStartMs + beat * _beatGap;

    // No Scaffold/Starfield here — renders inside OnboardingFlow's sky.
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  // Header: Revo (tail-left) + the question, materialising word
                  // by word — the same signature shimmer as page 2.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        child: RevoEntrance(
                          t: _win(0, _revoMs),
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
                            text: 'When should we\nremind you?',
                            progress: _win(_questionStartMs, _questionEndMs),
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _reveal(
                    _taglineMs,
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        'Tap any to change — we filled in the rest',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // The picked items, sectioned. Each row's beat is derived from
                  // its fixed position (sectionBaseBeat), so lazily-built lower
                  // sections still get correct, stable start times.
                  for (var s = 0; s < _sections.length; s++)
                    _ScheduleSection(
                      section: _sections[s],
                      items: _pickedItems(_sections[s]),
                      draftFor: _draftFor,
                      onChanged: () => setState(() {}),
                      topGap: s == 0 ? 0 : 22,
                      // Header is the section's base beat; each card the beats
                      // after it.
                      headerReveal: (child) =>
                          _reveal(startOf(sectionBaseBeat[s]), child),
                      cardReveal: (i, child) =>
                          _beatReveal(startOf(sectionBaseBeat[s] + 1 + i), child),
                    ),
                ],
              ),
            ),
            // Bottom: one Finish, the sky fading up into it. Reveals with the
            // tagline so the primary action is present while the cards cascade.
            _reveal(
              _taglineMs,
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
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
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onFinish?.call(widget.drafts);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Finish',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One category block on the single-scroll schedule: a header (the category
/// name as a quiet all-caps kicker) followed by its picked items' cards.
class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.section,
    required this.items,
    required this.draftFor,
    required this.onChanged,
    required this.topGap,
    required this.headerReveal,
    required this.cardReveal,
  });

  final OnboardingChipSection section;
  final List<OnboardingChipItem> items;
  final ReminderDraft Function(OnboardingChipItem) draftFor;
  final VoidCallback onChanged;
  final double topGap;

  /// Wraps the header, and each card (by its index [i]), in its own staggered
  /// entrance, so the cascade flows continuously across sections. Index-based so
  /// the beat can be derived from the card's fixed position.
  final Widget Function(Widget child) headerReveal;
  final Widget Function(int i, Widget child) cardReveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topGap),
        headerReveal(
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 12),
            child: Row(
              children: [
                Icon(section.icon, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  section.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          cardReveal(
            i,
            _ItemScheduleCard(
              key: ValueKey('${section.key}:${items[i].key}'),
              item: items[i],
              draft: draftFor(items[i]),
              onChanged: onChanged,
            ),
          ),
      ],
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

/// How many times a year "every [count] [unit]" fires.
int _timesPerYearFrom(int count, RepeatCadence unit) {
  final n = count < 1 ? 1 : count;
  final perYear = switch (unit) {
    RepeatCadence.daily => 365,
    RepeatCadence.weekly => 52,
    RepeatCadence.monthly => 12,
    RepeatCadence.yearly => 1,
    RepeatCadence.none => 1,
  };
  final t = (perYear / n).round();
  return t < 1 ? 1 : t;
}

/// The cleanest "every [count] [unit]" that yields [timesPerYear] — the inverse
/// of [_timesPerYearFrom], picking whole-number intervals people recognise
/// (every month, every 3 months, once a year, …).
(int, RepeatCadence) _everyFromTimesPerYear(int timesPerYear) {
  final t = timesPerYear < 1 ? 1 : timesPerYear;
  return switch (t) {
    1 => (1, RepeatCadence.yearly),
    2 => (6, RepeatCadence.monthly),
    3 => (4, RepeatCadence.monthly),
    4 => (3, RepeatCadence.monthly),
    6 => (2, RepeatCadence.monthly),
    12 => (1, RepeatCadence.monthly),
    _ when t >= 365 => (1, RepeatCadence.daily),
    _ when t >= 52 => (1, RepeatCadence.weekly),
    _ => (1, RepeatCadence.monthly),
  };
}

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
                _ItemIcon(item: item),
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

/// The leading icon tile for a scheduled item — the real brand logo when the
/// item has a [OnboardingChipItem.domain] (Netflix, Spotify, …), or the clean
/// Material glyph otherwise (Mom, electricity, …). Same 42×42 rounded tile
/// either way, so the column stays perfectly uniform.
class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.item});
  final OnboardingChipItem item;

  @override
  Widget build(BuildContext context) {
    final hasBrand = item.domain != null && item.domain!.isNotEmpty;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Brand logos read best on a neutral tile; glyphs keep the accent wash.
        color: hasBrand
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasBrand
          ? BrandLogo(
              brand: Brand(name: item.label, domain: item.domain!),
              size: 26,
            )
          : Icon(item.icon, size: 20, color: AppColors.ink),
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
  // The repeat is edited as a natural "every N unit" pair; it maps to/from the
  // draft's times-per-year so the rest of onboarding is unchanged.
  late int _count;
  late RepeatCadence _unit;
  late int _month = widget.draft.month.clamp(1, 12);
  late int _day = widget.draft.day.clamp(1, 31);

  @override
  void initState() {
    super.initState();
    final seed = _everyFromTimesPerYear(widget.draft.timesPerYear);
    _count = seed.$1;
    _unit = seed.$2;
  }

  /// Times-per-year for the current (count, unit) — the value the draft stores.
  int get _times => _timesPerYearFrom(_count, _unit);

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
              const SizedBox(height: 12),
              // How often — the natural-language "every N unit" control.
              RepeatEveryPicker(
                count: _count,
                unit: _unit,
                onCountChanged: (n) => setState(() => _count = n),
                onUnitChanged: (u) => setState(() => _unit = u),
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

