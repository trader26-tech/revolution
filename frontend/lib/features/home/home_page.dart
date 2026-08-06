import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../auth/data/auth_store.dart';
import '../onboarding/data/onboarding_store.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/domain/task_filter.dart';
import '../tasks/presentation/task_details_sheet.dart';
import '../tasks/presentation/widgets/delete_snackbar.dart';
import '../tasks/presentation/widgets/quick_add_row.dart';
import 'domain/home_groups.dart';
import 'presentation/widgets/stat_cards.dart';
import 'presentation/widgets/task_section.dart';

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
  TaskFilter _filter = TaskFilter.all; // scoped by the stat cards
  bool _laterExpanded = false; // the "Scheduled" (later) section, collapsed
  final _addController = TextEditingController();
  final _addFocus = FocusNode();

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

  /// Replay the REAL first-run flow: reset onboarding + sign out, so the app
  /// returns to the top of the sequence — Onboarding → Phone number → Home.
  /// (The OnboardingGate/AuthGate at the app root react to these stores.)
  Future<void> _replayFullFlow() async {
    await OnboardingStore.instance.reset();
    await AuthStore.instance.logout();
  }

  /// Tapping a stat card scopes the list to it; tapping the selected one again
  /// clears back to All.
  void _tapCard(TaskFilter f) {
    setState(() => _filter = _filter == f ? TaskFilter.all : f);
  }

  void _startAdd() {
    setState(() => _adding = true);
    // Focus after the row mounts so the keyboard opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _addFocus.requestFocus());
  }

  /// Add the current text and keep the field open for the next task (the ✓).
  Future<void> _confirmAdd() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    _addController.clear();
    _addFocus.requestFocus(); // keep going
    try {
      await widget.store.add(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't add task: $e")),
        );
      }
    }
  }

  /// Finish adding — clear + dismiss the field and keyboard (the ✕ / tap-out).
  void _closeAdd() {
    _addController.clear();
    _addFocus.unfocus();
    setState(() => _adding = false);
  }

  Future<void> _editTask(Task task) async {
    final updated = await showTaskDetailsSheet(context, task);
    if (updated == null) return;
    try {
      await widget.store.update(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save: $e")),
        );
      }
    }
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
    // Keyboard height — the FAB rides just above it while adding, and sits above
    // the floating nav bar when idle.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    // Just enough to clear the floating nav bar (~64h + 16 margin) — the FAB
    // rests low, right above the nav, not high up the screen.
    const navBarClearance = 44.0;

    return Stack(
      children: [
        // The empty state is centred against the WHOLE screen (behind the top
        // bar + nav), so the icon + text block sits optically dead-centre — not
        // pushed up by the top bar's height.
        AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            // Don't show the welcoming empty state over a server error.
            final showEmpty = widget.store.tasks.isEmpty &&
                !_adding &&
                widget.store.error == null;
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
                onIntro: _replayFullFlow,
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
        // The single morphing + / ✓ button, bottom-right. It slides up to sit
        // above the keyboard while adding, and rests above the nav when idle.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          right: 0,
          bottom: _adding ? keyboardInset : navBarClearance,
          child: SafeArea(
            top: false,
            child: QuickAddBar(
              adding: _adding,
              onStart: _startAdd,
              onConfirm: _confirmAdd,
              onClose: _closeAdd,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final allTasks = widget.store.tasks;

    // Surface a server error clearly instead of silently showing an empty list.
    if (widget.store.error != null && allTasks.isEmpty && !_adding) {
      return _ServerError(
        error: widget.store.error!,
        onRetry: () => widget.store.load(),
      );
    }
    // Truly empty (no tasks at all) → the welcoming empty state (drawn behind).
    if (allTasks.isEmpty && !_adding) {
      return const SizedBox.shrink();
    }

    final stats = statsFor(allTasks);
    final groups = groupForHome(allTasks, filter: _filter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
      children: [
        // Stat cards — the filters, as tappable cards.
        StatCards(stats: stats, active: _filter, onTap: _tapCard),
        const SizedBox(height: 20),

        // Quick-add row sits at the very top of the groups while adding.
        if (_adding)
          QuickAddRow(
            controller: _addController,
            focusNode: _addFocus,
            onSubmitText: _confirmAdd,
            onTapOutsideEmpty: _closeAdd,
            showHint: allTasks.isEmpty,
          ),

        // Nothing matches the active card's filter.
        if (groups.isEmpty && !_adding)
          _FilteredEmpty(
            filter: _filter,
            onClear: () => setState(() => _filter = TaskFilter.all),
          )
        else ...[
          if (groups.today.isNotEmpty)
            TaskSection(
              title: 'Today',
              tasks: groups.today,
              onToggleTask: (t) => widget.store.toggleDone(t),
              onOpenTask: _editTask,
              onDeleteTask: _deleteTask,
            ),
          if (groups.tomorrow.isNotEmpty)
            TaskSection(
              title: 'Tomorrow',
              tasks: groups.tomorrow,
              onToggleTask: (t) => widget.store.toggleDone(t),
              onOpenTask: _editTask,
              onDeleteTask: _deleteTask,
            ),
          // "Scheduled" = everything later, collapsed by default.
          if (groups.later.isNotEmpty)
            TaskSection(
              title: 'Scheduled',
              tasks: groups.later,
              collapsible: true,
              expanded: _laterExpanded,
              onToggleExpanded: () =>
                  setState(() => _laterExpanded = !_laterExpanded),
              onToggleTask: (t) => widget.store.toggleDone(t),
              onOpenTask: _editTask,
              onDeleteTask: _deleteTask,
            ),
          // Tasks with no date yet.
          if (groups.unscheduled.isNotEmpty)
            TaskSection(
              title: 'No date',
              tasks: groups.unscheduled,
              onToggleTask: (t) => widget.store.toggleDone(t),
              onOpenTask: _editTask,
              onDeleteTask: _deleteTask,
            ),
        ],
      ],
    );
  }
}

/// The glass top bar: a greeting/title on the left, Settings on the right.
/// (The filter is gone — filtering is done via the stat cards. Add lives as the
/// floating button above the keyboard.)
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSettings,
    required this.onIntro,
  });

  final VoidCallback onSettings;

  /// TEMP (dev): replays the onboarding so it can be reviewed anytime.
  final VoidCallback onIntro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: Row(
        children: [
          const Text(
            'Home',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // TEMP (dev): replay onboarding for review.
          GlassIconButton(
            icon: Icons.auto_awesome_rounded,
            tooltip: 'Onboarding (dev)',
            onTap: onIntro,
          ),
          const SizedBox(width: 10),
          GlassIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

/// A calm, centred empty state.
/// Shown when tasks exist but the active filter hides them all.
/// Shown when the server can't be reached — makes failures visible (with a
/// retry) instead of a silently-empty list.
class _ServerError extends StatelessWidget {
  const _ServerError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        const Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.inkFaint),
        const SizedBox(height: 16),
        const Text(
          "Couldn't reach the server",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.filter, required this.onClear});

  final TaskFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filter.icon, size: 44, color: AppColors.inkFaint),
            const SizedBox(height: 16),
            Text(
              'No ${filter.label.toLowerCase()} tasks',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onClear, child: const Text('Show all')),
          ],
        ),
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
