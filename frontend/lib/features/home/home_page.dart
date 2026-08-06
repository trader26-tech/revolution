import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../auth/data/auth_store.dart';
import '../calendar/domain/occurrences.dart';
import '../onboarding/data/onboarding_store.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/domain/task_filter.dart';
import '../tasks/presentation/filter_sheet.dart';
import '../tasks/presentation/task_details_sheet.dart';
import '../tasks/presentation/widgets/delete_snackbar.dart';
import '../tasks/presentation/widgets/quick_add_row.dart';
import 'widgets/monthly_agenda.dart';

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
  TaskFilter _filter = TaskFilter.all;
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

  Future<void> _openFilter() async {
    final picked = await showFilterSheet(context, current: _filter);
    if (picked != null) setState(() => _filter = picked);
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
                onFilter: _openFilter,
                onIntro: _replayFullFlow,
                filterActive: _filter.isActive,
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
    final tasks = applyFilter(allTasks, _filter);

    // Surface a server error clearly instead of silently showing an empty list.
    if (widget.store.error != null && allTasks.isEmpty && !_adding) {
      return _ServerError(
        error: widget.store.error!,
        onRetry: () => widget.store.load(),
      );
    }

    // Truly empty (no tasks at all) → the welcoming empty state is drawn as a
    // full-screen centred layer behind this (see build), so nothing here.
    if (allTasks.isEmpty && !_adding) {
      return const SizedBox.shrink();
    }
    // Have tasks, but the current filter hides them all.
    if (tasks.isEmpty && !_adding) {
      return _FilteredEmpty(
        filter: _filter,
        onClear: () => setState(() => _filter = TaskFilter.all),
      );
    }

    // Split into scheduled (grouped by month → date) and unscheduled tasks.
    final scheduled = [for (final t in tasks) if (t.isScheduled) t];
    final unscheduled = [for (final t in tasks) if (!t.isScheduled) t];

    // Expand into dated occurrences so a recurring task appears in EVERY month
    // it's due. Window: from the start of the current month, forward ~2 years,
    // plus any past-due occurrences (so overdue items still show at the top).
    final now = DateTime.now();
    final windowStart = DateTime(now.year - 1, now.month, 1);
    final windowEnd = DateTime(now.year + 2, now.month, 1);
    final occ = expandOccurrences(scheduled, from: windowStart, to: windowEnd);
    final months = groupByMonth(occ);

    final quickAdd = _adding
        ? QuickAddRow(
            controller: _addController,
            focusNode: _addFocus,
            onSubmitText: _confirmAdd,
            onTapOutsideEmpty: _closeAdd,
            showHint: tasks.isEmpty,
          )
        : null;

    return MonthlyAgenda(
      months: months,
      unscheduled: unscheduled,
      leading: quickAdd,
      onToggle: (t) => widget.store.toggleDone(t),
      onOpenDetails: _editTask,
      onDelete: _deleteTask,
    );
  }
}

/// The glass top bar: Settings on the left, Filter on the right. (Add lives as
/// the floating button above the keyboard, so it's not here.)
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSettings,
    required this.onFilter,
    required this.onIntro,
    required this.filterActive,
  });

  final VoidCallback onSettings;
  final VoidCallback onFilter;

  /// TEMP (dev): replays the onboarding so it can be reviewed anytime.
  final VoidCallback onIntro;

  /// Whether a non-"All" filter is applied — shows an accent dot on the button.
  final bool filterActive;

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
          const SizedBox(width: 10),
          // TEMP (dev): replay onboarding for review.
          GlassIconButton(
            icon: Icons.auto_awesome_rounded,
            tooltip: 'Onboarding (dev)',
            onTap: onIntro,
          ),
          const Spacer(),
          // Filter button, right corner. A small accent dot marks it active.
          Stack(
            clipBehavior: Clip.none,
            children: [
              GlassIconButton(
                icon: Icons.filter_alt_outlined,
                tooltip: 'Filter',
                onTap: onFilter,
              ),
              if (filterActive)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2),
                    ),
                  ),
                ),
            ],
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
