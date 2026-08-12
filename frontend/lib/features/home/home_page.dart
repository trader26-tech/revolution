import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../add/presentation/added_success.dart';
import '../add/presentation/open_add_flow.dart';
import '../auth/data/auth_store.dart';
import '../documents/data/documents_store.dart';
import '../documents/presentation/documents_page.dart';
import '../settings/data/profile_store.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import 'presentation/collection_page.dart';
import 'presentation/upcoming_page.dart';
import 'presentation/widgets/home_dashboard.dart';
import 'presentation/widgets/quick_access_bar.dart';

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
  DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  // The LOCAL documents library — files kept on-device, opened from the
  // quick-access button above Browse. Loaded once so the button can show a count.
  final _documents = DocumentsStore();

  @override
  void initState() {
    super.initState();
    _documents.load();
  }

  @override
  void dispose() {
    _documents.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  /// Open the local Documents library (a pushed full screen).
  void _openDocuments() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentsPage(store: _documents)),
    );
  }

  /// The "+" — slide the Browse list up from the bottom ("Add to Revolution").
  /// Pick a category → its tailored add form opens → it's saved. On success,
  /// Revo pops in to celebrate, then we glide into that category's collection.
  ///
  /// To keep it one clean forward motion (no flash of Home in between), we push
  /// the collection page FIRST — hidden behind the opaque success page — so when
  /// the celebration ends and dismisses, the subscriptions/SIP/occasions page is
  /// revealed directly underneath.
  Future<void> _startAdd() async {
    final category = await showAddBrowseSheet(context);
    if (category == null || !mounted) return;
    final result = await openCategoryForm(context, widget.store, category);
    if (result == null || !mounted) return;
    final willAdd = result.task != null || result.selfSaved;
    if (!willAdd) return;
    // CRITICAL ordering: the frame the form closes, show the celebration FIRST
    // (it's cheap + opaque + instant, so it covers the screen immediately and
    // Home is never painted), THEN place the destination page underneath it,
    // THEN persist (async; it notifies listeners → a Home rebuild, now hidden
    // behind the celebration). Nothing awaited runs before the cover is up.
    final celebration = showAddedSuccess(context, label: addedLabel(category));
    _openCollection(category, instant: true);
    await persistAddResult(widget.store, result);
    await celebration;
  }

  /// Tapping a card opens its RICH edit form (routed by category), where every
  /// detail — including the full highlight text that's clipped on the card — is
  /// shown in full and editable. Non-form categories fall back to the quick
  /// details sheet.
  Future<void> _editTask(Task task) async {
    await openEditForm(
      context,
      widget.store,
      task,
      fallback: () => showTaskDetailsSheet(context, task),
    );
  }

  /// Open the full-screen vertical list of all upcoming reminders (from today
  /// onward, grouped day by day), reached from the "Up next" arrow.
  void _openUpcoming() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UpcomingPage(
        tasks: widget.store.tasks,
        onTap: (t) {
          Navigator.of(context).pop();
          _editTask(t);
        },
      ),
    ));
  }

  /// Open a category's collection page (all Subscriptions, all SIPs…), or the
  /// full "All" collection when [category] is null.
  ///
  /// [instant] skips the slide transition — used by the add flow, where this
  /// page is placed underneath the success celebration and must be settled by
  /// the time the celebration lifts (no visible slide, no flash).
  void _openCollection(TaskCategory? category, {bool instant = false}) {
    final page = CollectionPage(store: widget.store, category: category);
    Navigator.of(context).push(
      instant
          ? PageRouteBuilder(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, _, _) => page,
            )
          : MaterialPageRoute(builder: (_) => page),
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

  /// The "Up next" cards: scheduled, unfinished reminders in the 7-day window
  /// from today, soonest first.
  List<Task> _upNextFromToday(List<Task> all) {
    final start = _dayOf(DateTime.now());
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

    // Greeting → Up Next (from today) → the Browse grid, which is the easy-access
    // launcher to every product (no calendar, no raw task dump).
    final today = _dayOf(DateTime.now());
    final rows = <Widget>[
      // Greeting — Revo says "Good <time>, <name>" + "Welcome to Revolution".
      GreetingRevo(name: displayName, tasks: allTasks),
      const SizedBox(height: 6),
      // Up Next — the next 7 days from today, day by day. The arrow opens the
      // full vertical upcoming list.
      UpNextStrip(
        items: _upNextFromToday(allTasks),
        anchor: today,
        windowLabel: 'next 7 days',
        onTap: _editTask,
        onSeeAll: _openUpcoming,
      ),
      // Quick access — the launcher strip ABOVE Browse. Documents today; more
      // tiles can be added to this row later.
      AnimatedBuilder(
        animation: _documents,
        builder: (context, _) => QuickAccessBar(
          items: [
            QuickAccessItem(
              // A DOCUMENT-plus glyph — distinct from Home's plain "+" (add a
              // reminder). It morphs in from a plain "+" so the difference is
              // felt: "this plus is for documents".
              icon: Icons.note_add_rounded,
              morphFrom: Icons.add_rounded,
              label: 'Documents',
              badge: _documents.totalCount > 0
                  ? '${_documents.totalCount}'
                  : null,
              onTap: _openDocuments,
            ),
          ],
        ),
      ),
      // Browse — the launcher to every category's collection page.
      BrowseGrid(
        tasks: allTasks,
        onOpenCategory: _openCollection,
        onOpenAll: () => _openCollection(null),
      ),
    ];

    // Cap text scale across the whole home feed so large system fonts can never
    // push the greeting, the fixed-height cards, or the browse rows into overflow.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 120),
        children: rows,
      ),
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
