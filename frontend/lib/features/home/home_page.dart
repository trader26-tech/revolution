import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../auth/data/auth_store.dart';
import '../settings/data/profile_store.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import '../tasks/presentation/widgets/delete_snackbar.dart';
import '../tasks/presentation/widgets/quick_add_row.dart';
import '../tasks/presentation/widgets/task_tile.dart';
import 'domain/home_stats.dart';
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
  bool _adding = false;
  final _addController = TextEditingController();
  final _addFocus = FocusNode();

  /// The day selected in the week-strip calendar. The task list below shows
  /// reminders from this day onward. Defaults to today.
  DateTime _selectedDate = DateTime.now();

  DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _startAdd() {
    setState(() => _adding = true);
    // Focus after the row mounts so the keyboard opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _addFocus.requestFocus());
  }

  /// Add the current text and keep the field open for the next task (the ✓).
  void _confirmAdd() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    widget.store.add(text);
    _addController.clear();
    _addFocus.requestFocus(); // keep going
  }

  /// Finish adding — clear + dismiss the field and keyboard (the ✕ / tap-out).
  void _closeAdd() {
    _addController.clear();
    _addFocus.unfocus();
    setState(() => _adding = false);
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

  /// Remove a task, with a white, auto-dismissing Undo snackbar.
  void _deleteTask(Task task) {
    widget.store.remove(task);
    showDeleteSnackBar(
      context,
      title: task.title,
      onUndo: () => widget.store.restore(task),
    );
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
            final showEmpty = widget.store.tasks.isEmpty && !_adding;
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

  /// Tasks shown below the calendar: scheduled reminders from the selected day
  /// onward (soonest first), plus any unscheduled tasks so nothing is hidden.
  List<Task> _fromSelected(List<Task> all) {
    final start = _dayOf(_selectedDate);
    final scheduled = all
        .where((t) => t.isScheduled && !_dayOf(t.dueAt!).isBefore(start))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final unscheduled = all.where((t) => !t.isScheduled).toList();
    return [...scheduled, ...unscheduled];
  }

  Widget _buildList() {
    final allTasks = widget.store.tasks;

    // Truly empty (no tasks at all) → the welcoming empty state is drawn as a
    // full-screen centred layer behind this (see build), so nothing here.
    if (allTasks.isEmpty && !_adding) {
      return const SizedBox.shrink();
    }

    final tasks = _fromSelected(allTasks);
    final stats = computeHomeStats(allTasks);

    // The display name: prefer the one captured at onboarding/login
    // (AuthStore), fall back to the Settings profile name.
    final displayName = (AuthStore.instance.name?.trim().isNotEmpty ?? false)
        ? AuthStore.instance.name!.trim()
        : ProfileStore.instance.name;

    // Greeting, then the compact calendar, then Up Next, then the tasks from
    // the selected day onward.
    final rows = <Widget>[
      // Greeting — Revo says "Good <time>, <name>" + "Welcome to Revolution".
      GreetingRevo(name: displayName, tasks: allTasks),
      const SizedBox(height: 14),
      // Compact week-strip calendar — tap a day to filter the list below.
      WeekStripCalendar(
        tasks: allTasks,
        selected: _selectedDate,
        onSelect: (d) => setState(() => _selectedDate = d),
      ),
      // Up Next — the soonest reminders as cards; arrow → full upcoming list.
      UpNextStrip(
        items: stats.upNext,
        onTap: _editTask,
        onSeeAll: _openUpcoming,
      ),
      const SizedBox(height: 8),
      if (_adding)
        QuickAddRow(
          controller: _addController,
          focusNode: _addFocus,
          onSubmitText: _confirmAdd,
          onTapOutsideEmpty: _closeAdd,
          // The helper only shows on the very first add (nothing added yet).
          // Once an item exists, the row is just the field — clean continuation.
          showHint: tasks.isEmpty,
        ),
      for (final t in tasks)
        TaskTile(
          task: t,
          onToggle: () => widget.store.toggleDone(t),
          onOpenDetails: () => _editTask(t),
          onDelete: () => _deleteTask(t),
        ),
    ];

    // Cards carry their own vertical margins, so the list is a plain ListView
    // (no dividers) — each task reads as its own rounded card.
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
          // Add button, right corner.
          GlassIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Add reminder',
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
