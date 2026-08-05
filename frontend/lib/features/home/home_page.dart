import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import '../tasks/presentation/widgets/quick_add_row.dart';
import '../tasks/presentation/widgets/task_tile.dart';

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
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              _TopBar(onSettings: _openSettings),
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
    final tasks = widget.store.tasks;

    if (tasks.isEmpty && !_adding) {
      return _EmptyContent(onAdd: _startAdd);
    }

    // The quick-add input row (when active) on top, then the tasks.
    final rows = <Widget>[
      if (_adding)
        QuickAddRow(
          controller: _addController,
          focusNode: _addFocus,
          onSubmitText: _confirmAdd,
          onTapOutsideEmpty: _closeAdd,
        ),
      for (final t in tasks)
        TaskTile(
          task: t,
          onToggle: () => widget.store.toggleDone(t),
          onTap: () => _editTask(t),
        ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 120),
      itemCount: rows.length,
      // A short, inset divider between rows — not edge-to-edge.
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        indent: 20,
        endIndent: 20,
        color: AppColors.hairline,
      ),
      itemBuilder: (_, i) => rows[i],
    );
  }
}

/// The glass top bar: Settings on the left. (Add now lives as the floating
/// button above the keyboard, so it's not here.)
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});

  final VoidCallback onSettings;

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
        ],
      ),
    );
  }
}

/// A calm, centred empty state.
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
