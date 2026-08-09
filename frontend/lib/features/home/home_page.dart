import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../add/presentation/open_add_flow.dart';
import '../onboarding/presentation/onboarding_flow.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/domain/task_filter.dart';
import '../tasks/presentation/filter_sheet.dart';
import '../tasks/presentation/open_task_details.dart';
import '../tasks/presentation/widgets/delete_snackbar.dart';
import '../update/data/update_service.dart';
import '../update/presentation/update_prompt.dart';
import '../settings/data/profile_store.dart';
import 'domain/home_groups.dart';
import 'domain/home_stats.dart';
import 'presentation/search_page.dart';
import 'presentation/widgets/home_dashboard.dart';
import 'presentation/widgets/home_loading.dart';
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
  TaskFilter _filter = TaskFilter.all; // scoped by the stat cards
  bool _laterExpanded = true; // "Scheduled" (later) section, open by default

  @override
  void initState() {
    super.initState();
    // On launch, quietly check for a newer sideloaded build and prompt if one
    // is available. Best-effort — never blocks or errors the UI.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.instance.check();
    if (info.available && mounted) {
      await showUpdatePrompt(context, info);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  /// DEV: replay the onboarding flow (intro → chips → payoff → schedule).
  /// Opened WITHOUT an onDone handler, so its Skip/Finish signs out and drops
  /// you on the phone login page every time — handy for testing login again and
  /// again from Home.
  void _openOnboardingPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const OnboardingFlow(),
      ),
    );
  }

  /// Open the funnel filter sheet.
  Future<void> _openFilter() async {
    final picked = await showFilterSheet(context, current: _filter);
    if (picked != null) setState(() => _filter = picked);
  }

  /// Open full-screen search: find any item and run every operation on it —
  /// open (read/update via the editor), toggle done, or delete with Undo. All
  /// reuse the same handlers as the home rows.
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchPage(
          store: widget.store,
          onOpen: _editTask,
          onToggle: (t) => widget.store.toggleDone(t),
          onDelete: _deleteTask,
        ),
      ),
    );
  }

  /// Tapping a category card → open search (where the user can find everything
  /// in that category). A dedicated filtered view can replace this later.
  void _openCategory(TaskCategory _) => _openSearch();

  /// Press + → pick a category (Subscription, Birthday, Insurance) → fill its
  /// tailored form. Subscription/Birthday hand back a ready-to-save [Task];
  /// Insurance saves itself (it needs the task id to upload its document) and
  /// just signals a refresh.
  Future<void> _startAdd() async {
    final result = await openAddFlow(context, widget.store);
    if (result == null || !mounted) return;
    // Insurance already created + uploaded itself — nothing to persist here.
    if (result.selfSaved) return;
    final task = result.task;
    if (task == null) return;
    try {
      // Create with the name + icon, then persist the rest of the form's fields.
      final created = await widget.store.add(
        task.title,
        iconName: task.iconName,
        iconDomain: task.iconDomain,
      );
      await widget.store.update(created.copyWith(
        dueAt: task.dueAt,
        clearDueAt: task.dueAt == null,
        repeat: task.repeat,
        amount: task.amount,
        clearAmount: task.amount == null,
        currency: task.currency,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't add task: $e")),
        );
      }
    }
  }

  /// Tap a task → the full "Update details" screen (same page, update mode).
  Future<void> _editTask(Task task) async {
    final updated = await openTaskDetails(
      context,
      existing: task,
      // Delete button at the bottom of the editor → remove with Undo.
      onDelete: () => _deleteTask(task),
    );
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
    return Stack(
      children: [
        // The empty state is centred against the WHOLE screen (behind the top
        // bar + nav). It only shows once loading has settled — never during the
        // initial fetch (which would flash "All clear").
        AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final showEmpty = !widget.store.isInitialLoad &&
                widget.store.tasks.isEmpty &&
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
                filterActive: _filter.isActive,
              ),
              const SizedBox(height: 8),
              // Everything below the top bar scrolls together: greeting → search
              // → Revo + hero metrics → Up Next → category cards → the list.
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [widget.store, ProfileStore.instance]),
                  builder: (context, _) => _buildBody(),
                ),
              ),
            ],
          ),
        ),
        // The iPhone-style floating "+" — a large circular accent button pinned
        // to the bottom-right. Sits above the floating nav bar, so it's always
        // one thumb-reach away without competing with the top bar.
        Positioned(
          right: 20,
          bottom: 96,
          child: _AddFab(onTap: _startAdd),
        ),
      ],
    );
  }

  /// The whole scrollable Home: greeting → search → Revo + hero metrics →
  /// Up Next cards → category cards → the grouped task list.
  Widget _buildBody() {
    final allTasks = widget.store.tasks;

    // Still fetching for the first time → a premium shimmer skeleton.
    if (widget.store.isInitialLoad) {
      return const HomeLoading();
    }
    // Server error with nothing to show → a clear error, not a blank list.
    if (widget.store.error != null && allTasks.isEmpty) {
      return _ServerError(
        error: widget.store.error!,
        onRetry: () => widget.store.load(),
      );
    }
    // Truly empty → the welcoming empty state (drawn behind this).
    if (allTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final stats = computeHomeStats(allTasks);
    final groups = groupForHome(allTasks, filter: _filter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
      children: [
        // 1 · Greeting — Revo says "Good afternoon, <name>" + "Welcome to
        //     Revolution", with his live entrance. He lives HERE, not in the
        //     hero.
        GreetingRevo(name: ProfileStore.instance.name, tasks: allTasks),
        const SizedBox(height: 18),
        // 2 · Search.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _SearchTapBar(onTap: _openSearch),
        ),
        const SizedBox(height: 18),
        // 3 · THE hero — one card, everything at a glance (Suball-style).
        HeroMetricsCard(stats: stats),
        // 4 · Up Next — the soonest reminders as cards.
        UpNextStrip(items: stats.upNext, onTap: _editTask),
        // 5 · Category cards.
        CategoryCards(
          stats: stats,
          tasks: allTasks,
          onTapCategory: _openCategory,
        ),
        const SizedBox(height: 8),
        // 6 · The grouped list below.
        if (groups.isEmpty)
          _FilteredEmpty(
            filter: _filter,
            onClear: () => setState(() => _filter = TaskFilter.all),
          )
        else ...[
          // Pending = overdue & not done. Shown first, in red, to nudge action.
          if (groups.pending.isNotEmpty)
            TaskSection(
              title: 'Pending',
              icon: Icons.error_outline_rounded,
              accent: const Color(0xFFDC2626),
              tasks: groups.pending,
              onToggleTask: (t) => widget.store.toggleDone(t),
              onOpenTask: _editTask,
              onDeleteTask: _deleteTask,
            ),
          if (groups.today.isNotEmpty)
            TaskSection(
              title: 'Today',
              tasks: groups.today,
              onToggleTask: (t) => widget.store.toggleDone(t),
              onOpenTask: _editTask,
              onDeleteTask: _deleteTask,
            ),
          // The upcoming week, with each task's date shown on its tile.
          if (groups.next7.isNotEmpty)
            TaskSection(
              title: 'Next 7 days',
              tasks: groups.next7,
              onToggleTask: (t) => widget.store.toggleDone(t),
              onOpenTask: _editTask,
              onDeleteTask: _deleteTask,
            ),
          // Everything further out — collapsible.
          if (groups.remaining.isNotEmpty)
            TaskSection(
              title: 'Scheduled',
              tasks: groups.remaining,
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
    required this.onFilter,
    required this.filterActive,
  });

  final VoidCallback onSettings;

  /// Funnel → the filter sheet.
  final VoidCallback onFilter;

  /// Whether a non-"All" filter is applied — marks the funnel with a dot.
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    // Right corner only: Filter · Settings. (Add is now a floating button in the
    // bottom-right; the dev onboarding button was removed.)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          const Spacer(),
          // Funnel filter, with an accent dot when active.
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

/// The floating "+" action button — bottom-right, iPhone-style. A large circle
/// in the accent with a soft violet glow, so adding a reminder is always a
/// thumb-reach away. Scales down slightly on press for a tactile feel.
class _AddFab extends StatefulWidget {
  const _AddFab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9A80FF), AppColors.accent],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

/// The tap-to-search pill that sits above the hero. It's a lightweight decoy of
/// a search field — tapping it opens the real full-screen [SearchPage] (with a
/// live keyboard), rather than typing inline. Reads as a search box, behaves as
/// a button.
class _SearchTapBar extends StatelessWidget {
  const _SearchTapBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, size: 21, color: AppColors.inkSoft),
            SizedBox(width: 10),
            Text(
              'Search your reminders',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.inkFaint,
              ),
            ),
          ],
        ),
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
