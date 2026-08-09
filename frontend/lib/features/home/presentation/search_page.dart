import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/widgets/task_tile.dart';

/// A full-screen search over everything the user has added. Type to filter live;
/// tap a result to open it for the full read / update / delete — the same editor
/// the home rows use, so every operation is available from here.
///
/// [onOpen] opens a task for edit (read + update + delete via the editor's own
/// delete button). [onToggle] flips done straight from a result row.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.store,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final TaskStore store;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onDelete;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _query = _controller.text.trim());
    });
    // Open the keyboard immediately — search is about typing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Case-insensitive match on the title. Empty query → everything (so opening
  /// search shows the full list to browse/act on).
  List<Task> get _results {
    final all = widget.store.tasks;
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((t) => t.title.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar row: back + the field ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.ink),
                  ),
                  Expanded(child: _SearchField(
                    controller: _controller,
                    focusNode: _focus,
                    onClear: () => _controller.clear(),
                  )),
                ],
              ),
            ),
            // ── Live results ──
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  final results = _results;
                  if (results.isEmpty) {
                    return _EmptyResults(query: _query);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final task = results[i];
                      // Reuse the exact home row — same look, same swipe-to-
                      // delete, same tap-to-open editor. Consistency for free.
                      return TaskTile(
                        key: ValueKey(task.id),
                        task: task,
                        onToggle: () => widget.onToggle(task),
                        onOpenDetails: () => widget.onOpen(task),
                        onDelete: () => widget.onDelete(task),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pill search field, with a leading magnifier and a clear button.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, size: 22, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: AppColors.accent,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: const InputDecoration(
                hintText: 'Search your reminders',
                hintStyle: TextStyle(
                  color: AppColors.inkFaint,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox(width: 14);
              return IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.inkSoft),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final searching = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.inbox_rounded,
              size: 44,
              color: AppColors.inkFaint,
            ),
            const SizedBox(height: 14),
            Text(
              searching ? 'No matches for “$query”' : 'Nothing to search yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
