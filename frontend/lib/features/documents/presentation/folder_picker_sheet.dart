import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/documents_store.dart';
import 'folder_name_sheet.dart';

/// A navigable "choose a folder" sheet — the dropdown-style destination picker
/// that replaces the old category chips. Browse into folders, create a new one
/// anywhere, and pick the current folder as the destination.
///
/// Returns the chosen folder id (null = the root / "Documents"), or null via
/// [Navigator.pop] with no value if dismissed — the caller distinguishes with a
/// sentinel, so this sheet ALWAYS pops a [FolderChoice].
class FolderChoice {
  const FolderChoice(this.folderId);
  final String? folderId; // null = root
}

Future<FolderChoice?> showFolderPickerSheet(
  BuildContext context, {
  required DocumentsStore store,
  String? initialFolderId,
}) {
  return showModalBottomSheet<FolderChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FolderPickerSheet(store: store, startAt: initialFolderId),
  );
}

class _FolderPickerSheet extends StatefulWidget {
  const _FolderPickerSheet({required this.store, this.startAt});
  final DocumentsStore store;
  final String? startAt;

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  DocumentsStore get store => widget.store;
  late String? _current = widget.startAt;

  Future<void> _newFolderHere() async {
    final name = await showFolderNameSheet(context, title: 'New folder');
    if (name == null || name.trim().isEmpty) return;
    final created = await store.createFolder(name: name, parentId: _current);
    // Step INTO the folder just created, so the next tap "Save here" lands in it.
    setState(() => _current = created.id);
  }

  @override
  Widget build(BuildContext context) {
    final subs = store.foldersIn(_current);
    final path = store.pathTo(_current);
    final currentName =
        path.isEmpty ? 'Documents' : path.last.displayName;

    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header: back (when nested) + current location.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_current != null)
                      IconButton(
                        onPressed: () => setState(
                          () => _current = store.folderById(_current)?.parentId,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.ink),
                      )
                    else
                      const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _newFolderHere,
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('New'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.cardBorder),
              // Sub-folder list (scrolls). Tapping one steps into it.
              Flexible(
                child: subs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          _current == null
                              ? 'No folders yet — save here, or make one.'
                              : 'No sub-folders here.',
                          style: const TextStyle(color: AppColors.inkFaint),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: subs.length,
                        itemBuilder: (_, i) {
                          final f = subs[i];
                          final n = store.itemsUnder(f.id);
                          return ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_rounded,
                                  size: 20, color: AppColors.accent),
                            ),
                            title: Text(
                              f.displayName,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '$n document${n == 1 ? '' : 's'}',
                              style: const TextStyle(color: AppColors.inkFaint),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkFaint),
                            onTap: () => setState(() => _current = f.id),
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: AppColors.cardBorder),
              // The commit action — save into the folder we're viewing.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(FolderChoice(_current));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _current == null
                          ? 'Save to Documents'
                          : 'Save to “$currentName”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
