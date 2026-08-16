import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../add/presentation/widgets/orbit_form.dart' show showFrequencyPicker;
import '../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';

/// Opens the UPDATE flow — one condensed bottom sheet that MORPHS through three
/// steps in place, so the whole "edit an existing reminder" journey stays on a
/// single crisp card with minimal scrolling:
///
///   1. CATEGORY  — pick which kind of thing to update (or "All").
///   2. ITEM      — pick the specific reminder from that category.
///   3. EDIT      — an inline card of just the KEY fields for that category,
///                  editable in place; Save writes straight to the store.
///
/// Self-contained: the caller just triggers it (e.g. from the ★ command area).
Future<void> showUpdateFlow(BuildContext context, TaskStore store) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _UpdateFlowSheet(store: store),
  );
}

class _UpdateFlowSheet extends StatefulWidget {
  const _UpdateFlowSheet({required this.store});
  final TaskStore store;

  @override
  State<_UpdateFlowSheet> createState() => _UpdateFlowSheetState();
}

enum _Step { category, item, edit }

class _UpdateFlowSheetState extends State<_UpdateFlowSheet> {
  _Step _step = _Step.category;

  /// null = the "All" pseudo-category (every item).
  TaskCategory? _category;
  Task? _task;

  TaskStore get store => widget.store;

  /// Categories that actually have items, so we never show an empty bucket.
  List<TaskCategory> get _liveCategories {
    final counts = <TaskCategory, int>{};
    for (final t in store.tasks) {
      counts.update(t.category, (v) => v + 1, ifAbsent: () => 1);
    }
    // Keep the browse display order, but only the ones with items.
    final ordered = [
      ...kBrowseCategories.where(counts.containsKey),
      // Any category with items that isn't in the browse list (insurance/bills).
      ...counts.keys.where((c) => !kBrowseCategories.contains(c)),
    ];
    return ordered;
  }

  List<Task> get _itemsInCategory {
    final all = store.tasks.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (_category == null) return all;
    return all.where((t) => t.category == _category).toList();
  }

  void _pickCategory(TaskCategory? c) {
    HapticFeedback.selectionClick();
    setState(() {
      _category = c;
      _step = _Step.item;
    });
  }

  void _pickItem(Task t) {
    HapticFeedback.selectionClick();
    setState(() {
      _task = t;
      _step = _Step.edit;
    });
  }

  void _back() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_step == _Step.edit) {
        _step = _Step.item;
      } else if (_step == _Step.item) {
        _step = _Step.category;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grip.
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.inkFaint.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                _header(),
                const SizedBox(height: 14),
                // The morphing body — one step at a time, cross-fading + sliding.
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final title = switch (_step) {
      _Step.category => 'Update',
      _Step.item => _category?.label ?? 'All reminders',
      _Step.edit => _task?.title ?? 'Edit',
    };
    final sub = switch (_step) {
      _Step.category => 'What would you like to update?',
      _Step.item => 'Pick one to edit',
      _Step.edit => 'Change what you need, then save',
    };
    return Row(
      children: [
        if (_step != _Step.category)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: _back,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 18, color: AppColors.inkSoft),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    return switch (_step) {
      _Step.category => _CategoryStep(
          key: const ValueKey('cat'),
          categories: _liveCategories,
          countFor: (c) => store.tasks.where((t) => t.category == c).length,
          totalCount: store.tasks.length,
          onPick: _pickCategory,
        ),
      _Step.item => _ItemStep(
          key: const ValueKey('item'),
          items: _itemsInCategory,
          onPick: _pickItem,
        ),
      _Step.edit => _EditStep(
          key: ValueKey('edit-${_task?.id}'),
          task: _task!,
          onSaved: (updated) {
            store.update(updated);
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop();
          },
        ),
    };
  }
}

// ── Step 1: category ─────────────────────────────────────────────────────────

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({
    super.key,
    required this.categories,
    required this.countFor,
    required this.totalCount,
    required this.onPick,
  });

  final List<TaskCategory> categories;
  final int Function(TaskCategory) countFor;
  final int totalCount;
  final ValueChanged<TaskCategory?> onPick;

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) {
      return const _EmptyNote('Nothing to update yet — add a reminder first.');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in categories)
          _RowTile(
            icon: c.icon,
            label: c.label,
            trailing: '${countFor(c)}',
            onTap: () => onPick(c),
          ),
        // "All" pseudo-category last.
        _RowTile(
          icon: Icons.all_inclusive_rounded,
          label: 'All reminders',
          trailing: '$totalCount',
          onTap: () => onPick(null),
        ),
      ],
    );
  }
}

// ── Step 2: item ─────────────────────────────────────────────────────────────

class _ItemStep extends StatelessWidget {
  const _ItemStep({super.key, required this.items, required this.onPick});
  final List<Task> items;
  final ValueChanged<Task> onPick;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyNote('No items in this category.');
    }
    // Cap the visible height so a long list scrolls WITHIN the sheet instead of
    // pushing it off-screen — the card stays condensed.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final t in items)
            _RowTile(
              icon: t.category.icon,
              label: t.title,
              trailing: _peek(t),
              onTap: () => onPick(t),
            ),
        ],
      ),
    );
  }

  /// A tiny right-aligned hint of the item's key value, so the list is scannable.
  String _peek(Task t) {
    if (t.hasAmount) {
      return '${currencyOf(t.currency).symbol}${formatAmount(t.amount!.round().toString(), currencyOf(t.currency).grouping)}';
    }
    return '';
  }
}

// ── Step 3: the inline edit card ─────────────────────────────────────────────

class _EditStep extends StatefulWidget {
  const _EditStep({super.key, required this.task, required this.onSaved});
  final Task task;
  final ValueChanged<Task> onSaved;

  @override
  State<_EditStep> createState() => _EditStepState();
}

class _EditStepState extends State<_EditStep> {
  late final TextEditingController _amount;
  late RepeatCadence _cycle;
  late int _interval;
  DateTime? _date;
  int _remindDaysBefore = 0;

  bool get _hasAmount =>
      switch (widget.task.category) {
        TaskCategory.subscription ||
        TaskCategory.bills ||
        TaskCategory.investment ||
        TaskCategory.policies =>
          true,
        _ => false,
      };

  bool get _hasFrequency => switch (widget.task.category) {
        TaskCategory.subscription ||
        TaskCategory.bills ||
        TaskCategory.investment ||
        TaskCategory.policies =>
          true,
        _ => false,
      };

  /// Every editable category has a meaningful date; label it per kind.
  String get _dateLabel => switch (widget.task.category) {
        TaskCategory.subscription || TaskCategory.bills => 'Next payment',
        TaskCategory.investment => 'Next date',
        TaskCategory.policies => 'Matures on',
        TaskCategory.birthday => 'Date',
        TaskCategory.medicine => 'Starts',
        _ => 'When',
      };

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _amount = TextEditingController(
      text: t.amount == null
          ? ''
          : formatAmount(_trim(t.amount!), currencyOf(t.currency).grouping),
    );
    _cycle = t.repeat;
    _interval = t.repeatTimes < 1 ? 1 : t.repeatTimes;
    _date = t.dueAt;
    _remindDaysBefore = t.remindDaysBefore;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _num(String s) =>
      double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showOrbitDatePicker(
      context,
      initial: _date ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 60),
      title: _dateLabel,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickFrequency() async {
    final r = await showFrequencyPicker(context,
        unit: _cycle == RepeatCadence.none ? RepeatCadence.monthly : _cycle,
        interval: _interval);
    if (r != null) {
      setState(() {
        _cycle = r.unit;
        _interval = r.interval;
      });
    }
  }

  void _save() {
    final t = widget.task;
    final amount = _hasAmount ? _num(_amount.text) : t.amount;
    widget.onSaved(t.copyWith(
      amount: amount,
      clearAmount: _hasAmount && amount == null,
      repeat: _hasFrequency ? _cycle : t.repeat,
      repeatTimes: _hasFrequency ? _interval : t.repeatTimes,
      dueAt: _date,
      clearDueAt: _date == null,
      remindDaysBefore: _remindDaysBefore,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The condensed edit card — just the key fields, as aligned rows.
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              if (_hasAmount) ...[
                _AmountRow(
                  label: 'Amount',
                  controller: _amount,
                  symbol: currencyOf(t.currency).symbol,
                ),
                const _Divider(),
              ],
              if (_hasFrequency) ...[
                _NavRow(
                  label: 'Frequency',
                  value: frequencyLabel(_cycle, _interval),
                  onTap: _pickFrequency,
                ),
                const _Divider(),
              ],
              _NavRow(
                label: _dateLabel,
                value: _date == null ? 'Set a date' : _fmtDate(_date!),
                onTap: _pickDate,
              ),
              if (t.category == TaskCategory.birthday) ...[
                const _Divider(),
                _RemindRow(
                  days: _remindDaysBefore,
                  onChanged: (d) => setState(() => _remindDaysBefore = d),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Save — full width, the one clear action.
        GestureDetector(
          onTap: _save,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              'Save changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }
}

// ── Shared small pieces ──────────────────────────────────────────────────────

/// A tappable list row — accent icon chip, label, a right hint, a chevron.
class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: AppColors.accent, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (trailing.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  trailing,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.inkFaint.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row with a right-aligned amount input (currency symbol + number).
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.controller,
    required this.symbol,
  });
  final String label;
  final TextEditingController controller;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(label, style: _labelStyle),
          const Spacer(),
          Text(symbol,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              )),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: IntrinsicWidth(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                cursorColor: AppColors.accent,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: AppColors.inkFaint,
                    fontWeight: FontWeight.w700,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row — label + right value + chevron (opens a picker).
class _NavRow extends StatelessWidget {
  const _NavRow(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(label, style: _labelStyle),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.inkFaint.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact reminder lead-time stepper (used for occasions).
class _RemindRow extends StatelessWidget {
  const _RemindRow({required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  static const _presets = [0, 1, 3, 7, 14, 30];

  String _label(int d) =>
      switch (d) { 0 => 'On the day', 1 => '1 day before', _ => '$d days before' };

  int get _index {
    var best = 0, bestDiff = (days - _presets[0]).abs();
    for (var i = 1; i < _presets.length; i++) {
      final diff = (days - _presets[i]).abs();
      if (diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final i = _index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text('Remind', style: _labelStyle),
          const Spacer(),
          _btn(Icons.remove_rounded, i < _presets.length - 1,
              () => onChanged(_presets[i + 1])),
          SizedBox(
            width: 104,
            child: Text(_label(_presets[i]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                )),
          ),
          _btn(Icons.add_rounded, i > 0, () => onChanged(_presets[i - 1])),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon,
            size: 17, color: enabled ? AppColors.accent : AppColors.inkFaint),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 16),
        color: AppColors.hairline,
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const Icon(Icons.inbox_rounded, size: 20, color: AppColors.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.3,
                  color: AppColors.inkSoft,
                )),
          ),
        ],
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 14.5,
  fontWeight: FontWeight.w600,
  color: AppColors.inkSoft,
);
