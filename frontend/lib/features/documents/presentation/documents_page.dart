import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../data/documents_store.dart';
import '../domain/document.dart';
import 'add_document_sheet.dart';
import 'folder_name_sheet.dart';

/// The local Documents library — a private, on-device file browser.
///
/// A real folder tree: create folders and sub-folders to any depth, drop
/// documents into any of them, navigate with a breadcrumb, and open / share /
/// rename / move / delete. Nothing is ever uploaded.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.store, this.folderId});

  final DocumentsStore store;

  /// The folder to open at (null = root). Deeper folders push a new page.
  final String? folderId;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  DocumentsStore get store => widget.store;
  String? get _folderId => widget.folderId;

  @override
  void initState() {
    super.initState();
    if (store.isInitialLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) => store.load());
    }
  }

  Future<void> _addDocument() async {
    HapticFeedback.selectionClick();
    final added = await showAddDocumentSheet(
      context,
      store: store,
      folderId: _folderId,
    );
    if (added != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved “${added.name}” on your phone')),
      );
    }
  }

  Future<void> _newFolder() async {
    HapticFeedback.selectionClick();
    final name = await showFolderNameSheet(context, title: 'New folder');
    if (name == null || name.trim().isEmpty) return;
    await store.createFolder(name: name, parentId: _folderId);
  }

  void _openFolder(DocFolder f) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentsPage(store: store, folderId: f.id),
      ),
    );
  }

  Future<void> _open(DocItem doc) async {
    HapticFeedback.selectionClick();
    final result = await OpenFilex.open(doc.localPath);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open this document")),
      );
    }
  }

  Future<void> _share(DocItem doc) async {
    HapticFeedback.selectionClick();
    await Share.shareXFiles(
      [XFile(doc.localPath, name: doc.originalName ?? doc.name)],
      subject: doc.name,
    );
  }

  Future<void> _renameItem(DocItem doc) async {
    final name = await showFolderNameSheet(
      context,
      title: 'Rename document',
      initial: doc.name,
      cta: 'Save',
    );
    if (name != null && name.trim().isNotEmpty) {
      await store.renameItem(doc.id, name);
    }
  }

  Future<void> _deleteItem(DocItem doc) async {
    final ok = await _confirm(
      title: 'Delete document?',
      body: '“${doc.name}” will be removed from your phone.',
    );
    if (ok) await store.removeItem(doc);
  }

  Future<void> _renameFolder(DocFolder f) async {
    final name = await showFolderNameSheet(
      context,
      title: 'Rename folder',
      initial: f.displayName,
      cta: 'Save',
    );
    if (name != null && name.trim().isNotEmpty) {
      await store.renameFolder(f.id, name);
    }
  }

  Future<void> _deleteFolder(DocFolder f) async {
    final n = store.itemsUnder(f.id);
    final ok = await _confirm(
      title: 'Delete folder?',
      body: n > 0
          ? '“${f.displayName}” and its $n document${n == 1 ? '' : 's'} will be '
              'removed from your phone.'
          : '“${f.displayName}” will be removed.',
    );
    if (ok) {
      await store.deleteFolder(f.id);
      if (mounted && _folderId == f.id) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: const TextStyle(color: AppColors.ink)),
        content: Text(body, style: const TextStyle(color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final folder = store.folderById(_folderId);
              return Column(
                children: [
                  const SizedBox(height: 6),
                  _TopBar(
                    title: folder?.displayName ?? 'Documents',
                    onBack: () => Navigator.of(context).pop(),
                    onAdd: _addDocument,
                    onNewFolder: _newFolder,
                    // Root has no ⋯ (nothing to rename/delete); a folder does.
                    onRenameFolder: folder == null ? null : () => _renameFolder(folder),
                    onDeleteFolder: folder == null ? null : () => _deleteFolder(folder),
                  ),
                  if (_folderId != null) _Breadcrumb(store: store, folderId: _folderId),
                  Expanded(child: _buildBody()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (store.isInitialLoad) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    final folders = store.foldersIn(_folderId);
    final items = store.itemsIn(_folderId);

    if (folders.isEmpty && items.isEmpty) {
      return _EmptyState(atRoot: _folderId == null);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      children: [
        if (folders.isNotEmpty) ...[
          const _SectionLabel('FOLDERS'),
          for (final f in folders)
            _FolderRow(
              folder: f,
              itemCount: store.itemsUnder(f.id),
              subfolderCount: store.foldersIn(f.id).length,
              onTap: () => _openFolder(f),
              onRename: () => _renameFolder(f),
              onDelete: () => _deleteFolder(f),
            ),
          const SizedBox(height: 8),
        ],
        if (items.isNotEmpty) ...[
          const _SectionLabel('DOCUMENTS'),
          for (final d in items)
            _DocRow(
              doc: d,
              onOpen: () => _open(d),
              onShare: () => _share(d),
              onRename: () => _renameItem(d),
              onDelete: () => _deleteItem(d),
            ),
        ],
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onAdd,
    required this.onNewFolder,
    this.onRenameFolder,
    this.onDeleteFolder,
  });

  final String title;
  final VoidCallback onBack;

  /// Tapping the corner "+" adds a document directly.
  final VoidCallback onAdd;

  /// Creating a folder — the small icon next to "+".
  final VoidCallback onNewFolder;
  final VoidCallback? onRenameFolder;
  final VoidCallback? onDeleteFolder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.6,
              ),
            ),
          ),
          // ONE corner button — the document-"+" that morphs in when the page
          // opens. Tapping it opens a small menu: Add document (primary) or New
          // folder. No separate folder icon.
          PopupMenuButton<String>(
            tooltip: 'Add',
            color: AppColors.card,
            offset: const Offset(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (v) {
              if (v == 'document') onAdd();
              if (v == 'folder') onNewFolder();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'document',
                child: _MenuRow(
                    icon: Icons.note_add_rounded, label: 'Add document'),
              ),
              PopupMenuItem(
                value: 'folder',
                child: _MenuRow(
                    icon: Icons.create_new_folder_outlined, label: 'New folder'),
              ),
            ],
            child: const _MorphAddButton(),
          ),
          if (onRenameFolder != null || onDeleteFolder != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
              color: AppColors.card,
              onSelected: (v) {
                if (v == 'rename') onRenameFolder?.call();
                if (v == 'delete') onDeleteFolder?.call();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: _MenuRow(icon: Icons.edit_outlined, label: 'Rename folder'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: _MenuRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete folder',
                    danger: true,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The corner add "+" that plays a ONE-TIME morph from a plain "+" into a
/// document-plus when the Documents page opens. A pure visual — the
/// PopupMenuButton wrapping it owns the tap (Add document / New folder).
class _MorphAddButton extends StatefulWidget {
  const _MorphAddButton();

  @override
  State<_MorphAddButton> createState() => _MorphAddButtonState();
}

class _MorphAddButtonState extends State<_MorphAddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    // A brief beat after the page settles, then morph "+" → document-plus.
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentDeep],
            ),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.38),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOutBack.transform(_c.value.clamp(0.0, 1.0));
              final outOpacity = (1 - (_c.value * 1.6)).clamp(0.0, 1.0);
              final inOpacity = ((_c.value - 0.4) / 0.6).clamp(0.0, 1.0);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: outOpacity,
                    child: Transform.rotate(
                      angle: t * 0.9,
                      child: Transform.scale(
                        scale: 1 - 0.4 * t,
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: inOpacity,
                    child: Transform.rotate(
                      angle: (t - 1) * 0.9,
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * t,
                        child: const Icon(Icons.note_add_rounded,
                            color: Colors.white, size: 23),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
  }
}

/// The breadcrumb trail — Documents › Folder › Sub-folder. Tapping a crumb pops
/// back to that level.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.store, required this.folderId});
  final DocumentsStore store;
  final String? folderId;

  @override
  Widget build(BuildContext context) {
    final path = store.pathTo(folderId);
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _Crumb(
              label: 'Documents',
              // The root Documents page is `path.length` pages down the stack.
              onTap: () => _popLevels(context, path.length),
              isLast: path.isEmpty,
            ),
            for (var i = 0; i < path.length; i++) ...[
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.inkFaint),
              _Crumb(
                label: path[i].displayName,
                // This crumb's page is `path.length - 1 - i` pages down.
                onTap: () => _popLevels(context, path.length - 1 - i),
                isLast: i == path.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pop exactly [n] routes (each folder level is one pushed DocumentsPage).
  void _popLevels(BuildContext context, int n) {
    final nav = Navigator.of(context);
    for (var k = 0; k < n && nav.canPop(); k++) {
      nav.pop();
    }
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap, required this.isLast});
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLast ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
            color: isLast ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.inkFaint,
          ),
        ),
      );
}

// ── Rows ────────────────────────────────────────────────────────────────────

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.itemCount,
    required this.subfolderCount,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final DocFolder folder;
  final int itemCount;
  final int subfolderCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (subfolderCount > 0) '$subfolderCount folder${subfolderCount == 1 ? '' : 's'}',
      '$itemCount document${itemCount == 1 ? '' : 's'}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.folder_rounded,
                      size: 22, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parts.join(' · '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                _RowMenu(
                  items: [
                    _MenuAction('rename', Icons.edit_outlined, 'Rename', onRename),
                    _MenuAction('delete', Icons.delete_outline_rounded, 'Delete',
                        onDelete, danger: true),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  final DocItem doc;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      doc.isPdf ? 'PDF' : 'Image',
      if (doc.sizeLabel != null) doc.sizeLabel!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    doc.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    size: 21,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  color: AppColors.inkSoft,
                  tooltip: 'Share',
                ),
                _RowMenu(
                  items: [
                    _MenuAction('open', Icons.open_in_new_rounded, 'Open', onOpen),
                    _MenuAction('rename', Icons.edit_outlined, 'Rename', onRename),
                    _MenuAction('delete', Icons.delete_outline_rounded, 'Delete',
                        onDelete, danger: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction(this.value, this.icon, this.label, this.onTap,
      {this.danger = false});
  final String value;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.items});
  final List<_MenuAction> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      color: AppColors.card,
      onSelected: (v) => items.firstWhere((a) => a.value == v).onTap(),
      itemBuilder: (_) => [
        for (final a in items)
          PopupMenuItem(
            value: a.value,
            child: _MenuRow(icon: a.icon, label: a.label, danger: a.danger),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.danger = false});
  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? const Color(0xFFFF6B6B) : AppColors.ink;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.atRoot});
  final bool atRoot;

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
              child: const Icon(Icons.folder_copy_rounded,
                  size: 44, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              atRoot ? 'Your private document vault' : 'This folder is empty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make folders, drop in any file, and open or share it anytime. '
              'Everything stays privately on your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 22),
            // Point to the "+" in the top-right corner.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tap ',
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkFaint),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentDeep],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.note_add_rounded,
                      color: Colors.white, size: 16),
                ),
                const Text(
                  ' to add a document',
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
