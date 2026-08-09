import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../add/presentation/added_success.dart';
import '../add/presentation/open_add_flow.dart';
import '../auth/data/auth_store.dart';
import '../settings/data/profile_store.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import 'presentation/collection_page.dart';
import 'presentation/upcoming_page.dart';
import 'presentation/widgets/home_dashboard.dart';

/// The Home screen.
///
/// Fast capture: tap ﹢, the keyboard opens on an inline field, type a name and
/// it's added instantly. Set the date/details later via the row's calendar
/// button or by tapping the task. A glass top bar holds Settings + Add.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final TaskStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// The day selected in the week-strip calendar. The task list below shows
  /// reminders from this day onward. Defaults to today.
  DateTime _selectedDate = DateTime.now();

  DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  /// The "+" — slide the Browse list up from the bottom ("Add to Revolution").
  /// Pick a category → its tailored add form opens → it's saved. On success,
  /// Revo pops in to celebrate, then we glide into that category's collection.
  Future<void> _startAdd() async {
    final category = await showAddBrowseSheet(context);
    if (category == null || !mounted) return;
    final result = await openCategoryForm(context, widget.store, category);
    final added = await persistAddResult(widget.store, result);
    if (!added || !mounted) return;
    await showAddedSuccess(context, label: '${category.label} added');
    if (!mounted) return;
    _openCollection(category);
  }

  Future<void> _editTask(Task task) async {
    final updated = await showTaskDetailsSheet(context, task);
    if (updated != null) widget.store.update(updated);
  }

  /// Open the full-screen list of all upcoming reminders (from the selected
  /// day onward), reached from the "Up next" arrow.
  void _openUpcoming() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UpcomingPage(
        tasks: widget.store.tasks,
        from: _selectedDate,
        onTap: (t) {
          Navigator.of(context).pop();
          _editTask(t);
        },
      ),
    ));
  }

  /// Open a category's collection page (all Subscriptions, all SIPs…), or the
  /// full "All" collection when [category] is null.
  void _openCollection(TaskCategory? category) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionPage(store: widget.store, category: category),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The empty state is centred against the WHOLE screen (behind the top
        // bar + nav), so the icon + text block sits optically dead-centre — not
        // pushed up by the top bar's height.
        AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final showEmpty = widget.store.tasks.isEmpty;
            if (!showEmpty) return const SizedBox.shrink();
            return Positioned.fill(
              child: _EmptyContent(onAdd: _startAdd),
            );
          },
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              _TopBar(
                onSettings: _openSettings,
                onAdd: _startAdd,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.store,
                  builder: (context, _) => _buildList(),
                ),
              ),
            ],
          ),
        ),
        // (No floating + button — adding is started from the top-right "+".
        // The inline quick-add row confirms on the keyboard's "done".)
      ],
    );
  }

  /// The "Up next" cards, anchored to the SELECTED calendar day: scheduled,
  /// unfinished reminders in the 7-day window starting on the selected day,
  /// soonest first. Picking a day in the strip moves this window with it.
  List<Task> _upNextFromSelected(List<Task> all) {
    final start = _dayOf(_selectedDate);
    final end = start.add(const Duration(days: 8)); // exclusive (7 days)
    return all
        .where((t) =>
            t.isScheduled &&
            !t.done &&
            !_dayOf(t.dueAt!).isBefore(start) &&
            _dayOf(t.dueAt!).isBefore(end))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  /// The little window label for Up next — "next 7 days" when today is picked,
  /// otherwise "from `Wkd D`" so the anchoring is explicit.
  String _upNextLabel() {
    final sel = _dayOf(_selectedDate);
    final today = _dayOf(DateTime.now());
    if (sel == today) return 'next 7 days';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'from ${wd[sel.weekday - 1]} ${sel.day}';
  }

  Widget _buildList() {
    final allTasks = widget.store.tasks;

    // Truly empty (no tasks at all) → the welcoming empty state is drawn as a
    // full-screen centred layer behind this (see build), so nothing here.
    if (allTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    // The display name: prefer the one captured at onboarding/login
    // (AuthStore), fall back to the Settings profile name.
    final displayName = (AuthStore.instance.name?.trim().isNotEmpty ?? false)
        ? AuthStore.instance.name!.trim()
        : ProfileStore.instance.name;

    // Greeting → calendar → Up Next (from the selected day) → the Browse grid,
    // which is the easy-access launcher to every product (no raw task dump).
    final rows = <Widget>[
      // Greeting — Revo says "Good <time>, <name>" + "Welcome to Revolution".
      GreetingRevo(name: displayName, tasks: allTasks),
      const SizedBox(height: 14),
      // Compact week-strip calendar — tap a day to move the Up Next window.
      WeekStripCalendar(
        tasks: allTasks,
        selected: _selectedDate,
        onSelect: (d) => setState(() => _selectedDate = d),
      ),
      // Up Next — reminders in the 7-day window from the SELECTED calendar day
      // (moves as you tap the strip); arrow → the full upcoming list.
      UpNextStrip(
        items: _upNextFromSelected(allTasks),
        windowLabel: _upNextLabel(),
        onTap: _editTask,
        onSeeAll: _openUpcoming,
      ),
      // Browse — the launcher to every category's collection page.
      BrowseGrid(
        tasks: allTasks,
        onOpenCategory: _openCollection,
        onOpenAll: () => _openCollection(null),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 120),
      children: rows,
    );
  }
}

/// The glass top bar: Settings on the left, Filter on the right. (Add lives as
/// the floating button above the keyboard, so it's not here.)
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSettings,
    required this.onAdd,
  });

  final VoidCallback onSettings;

  /// The "+" — add a reminder. Replaces the old filter button in the top-right.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
          const Spacer(),
          // Add button, right corner — accent-filled with a purple glow so it
          // reads as the app's one special action.
          GlassIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Add reminder',
            accent: true,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 44, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              'All clear',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap ﹢ to add your first task.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
