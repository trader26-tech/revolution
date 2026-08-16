import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../data/documents_store.dart';
import '../domain/document.dart';
import 'add_document_sheet.dart';
import 'document_viewer_page.dart';
import 'folder_name_sheet.dart';
import 'widgets/doc_thumbnail.dart';
import 'widgets/morph_icon_button.dart';

/// The local Documents library — a private, on-device file tree.
///
/// ONE screen: folders expand INLINE (accordion) to reveal their sub-folders
/// and documents — no page pushes. Create folders from the "New folder" tile,
/// add a document / sub-folder from each folder's own "+". Nothing is uploaded.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    required this.store,
    this.embedded = false,
    this.isActive = true,
  });

  final DocumentsStore store;

  /// True when shown as a top-level nav TAB (inside the shell's IndexedStack)
  /// rather than a pushed route. Embedded → no back arrow (a tab has nothing to
  /// pop to); the nav bar keeps only the "new folder" action.
  final bool embedded;

  /// True when Documents is the VISIBLE tab. Each time it flips back to true, the
  /// row-entrance cascade re-plays — so arriving at Documents (from Home or any
  /// other tab) always greets you with the rows arriving one at a time, not a
  /// static list. For a pushed route this stays true, so it animates on open.
  final bool isActive;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage>
    with SingleTickerProviderStateMixin {
  DocumentsStore get store => widget.store;

  /// Which folders are expanded (by id). Persisted only for the session.
  final Set<String> _expanded = {};

  /// Drives the smooth one-at-a-time entrance cascade of the rows — the same
  /// motion Browse and the category pages use, so Documents feels part of the
  /// family instead of a flat, static list.
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Play on first mount only if Documents is the visible tab; otherwise wait
    // until it becomes active (didUpdateWidget) so the cascade isn't "used up"
    // invisibly while another tab is showing.
    if (widget.isActive) _intro.forward(from: 0);
    if (store.isInitialLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) => store.load());
    }
  }

  @override
  void didUpdateWidget(covariant DocumentsPage old) {
    super.didUpdateWidget(old);
    // Switched TO Documents (from Home/Browse) → replay the cascade from the top,
    // so entering the page always feels like the rows are being conjured in.
    if (widget.isActive && !old.isActive) {
      _intro.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _addDocument({String? intoFolderId}) async {
    HapticFeedback.selectionClick();
    final added = await showAddDocumentSheet(
      context,
      store: store,
      folderId: intoFolderId,
    );
    if (added != null && mounted) {
      // Reveal where it landed.
      if (intoFolderId != null) setState(() => _expanded.add(intoFolderId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved “${added.name}” on your phone')),
      );
    }
  }

  Future<void> _newFolder({String? parentId}) async {
    HapticFeedback.selectionClick();
    final name = await showFolderNameSheet(
      context,
      title: parentId != null ? 'New subfolder' : 'New folder',
    );
    if (name == null || name.trim().isEmpty) return;
    final created = await store.createFolder(name: name, parentId: parentId);
    // Auto-expand the parent so the new folder is visible.
    if (parentId != null && mounted) setState(() => _expanded.add(parentId));
    // And expand the new (empty) folder so its add affordances show.
    if (mounted) setState(() => _expanded.add(created.id));
  }

  void _toggle(String folderId) {
    setState(() {
      _expanded.contains(folderId)
          ? _expanded.remove(folderId)
          : _expanded.add(folderId);
    });
  }

  void _open(DocItem doc) {
    HapticFeedback.selectionClick();
    // View it IN-APP (image / PDF reader), never bouncing to an external app.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentViewerPage(doc: doc)),
    );
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
    if (ok) await store.deleteFolder(f.id);
  }

  /// A folder's "+" — create a sub-folder or add a document INSIDE it.
  Future<void> _addInside(DocFolder f) async {
    HapticFeedback.selectionClick();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add to “${f.displayName}”',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined,
                  color: AppColors.accent),
              title: const Text('New subfolder',
                  style: TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, 'folder'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.note_add_rounded, color: AppColors.accent),
              title: const Text('Add document',
                  style: TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, 'document'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'folder') {
      await _newFolder(parentId: f.id);
    } else if (choice == 'document') {
      await _addDocument(intoFolderId: f.id);
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
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ── Build ───────────────────────────────────────────────────────────────

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
            builder: (context, _) => Column(
              children: [
                const SizedBox(height: 6),
                // Slim nav — back · new-folder "+". The title lives BIG in the
                // hero below (same pattern as the category collection pages).
                _NavBar(
                  onBack: widget.embedded
                      ? null
                      : () => Navigator.of(context).pop(),
                  onNewFolder: () => _newFolder(),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (store.isInitialLoad) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    final rootFolders = store.foldersIn(null);
    final rootItems = store.itemsIn(null);

    // Collect every tree row, then wrap each in the cascade so folders AND
    // their documents flow in one at a time (the recursion makes threading an
    // index inline awkward — building the flat list first keeps it clean).
    final rows = <Widget>[
      for (final f in rootFolders) ..._folderNode(f, depth: 0),
      for (final d in rootItems)
        _DocRow(
          doc: d,
          onOpen: () => _open(d),
          onShare: () => _share(d),
          onRename: () => _renameItem(d),
          onDelete: () => _deleteItem(d),
        ),
    ];

    // The whole-library aggregate for under the title — ONE value: the total
    // number of items (documents) anywhere in the tree. No folder count; a
    // single clean number reads best.
    final totalFiles = store.totalCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 40),
      children: [
        // The header — a big, plain "Documents" title with a quiet aggregate of
        // the whole library beneath it. No box; clean text lines below.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Documents',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppColors.ink,
                ),
              ),
              if (totalFiles > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$totalFiles item${totalFiles == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
        // The tree — folders expand in place, each row cascading smoothly in.
        for (var i = 0; i < rows.length; i++)
          _CascadeIn(intro: _intro, index: i, child: rows[i]),
        if (rootFolders.isEmpty && rootItems.isEmpty) ...[
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_copy_rounded,
                      size: 38, color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                const Text('No documents yet', style: AppText.title),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tap ', style: AppText.label),
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDeep],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.create_new_folder_rounded,
                          color: Colors.white, size: 15),
                    ),
                    const Text(' to make a folder', style: AppText.label),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// One folder and, when expanded, its children — rendered as a flat list of
  /// widgets with a left indent per [depth], so any nesting reads as a tree.
  List<Widget> _folderNode(DocFolder f, {required int depth}) {
    final expanded = _expanded.contains(f.id);
    final subs = store.foldersIn(f.id);
    final docs = store.itemsIn(f.id);

    return [
      Padding(
        padding: EdgeInsets.only(left: depth * 14.0),
        child: _FolderRow(
          folder: f,
          expanded: expanded,
          itemCount: store.itemsUnder(f.id),
          subfolderCount: subs.length,
          onTap: () => _toggle(f.id),
          onAddInside: () => _addInside(f),
          onRename: () => _renameFolder(f),
          onDelete: () => _deleteFolder(f),
        ),
      ),
      if (expanded) ...[
        // Sub-folders first…
        for (final sub in subs) ..._folderNode(sub, depth: depth + 1),
        // …then this folder's documents.
        for (final d in docs)
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 14.0),
            child: _DocRow(
              doc: d,
              onOpen: () => _open(d),
              onShare: () => _share(d),
              onRename: () => _renameItem(d),
              onDelete: () => _deleteItem(d),
            ),
          ),
        // An empty folder still offers a clear add.
        if (subs.isEmpty && docs.isEmpty)
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 14.0),
            child: _AddHereTile(onTap: () => _addInside(f)),
          ),
      ],
    ];
  }
}

/// The entrance cascade for document/folder rows: each eases up, fades, and
/// gently scales into place a beat after the one above — the same smooth motion
/// Browse and the category pages use. Fixed per-row delay (capped) so long
/// trees stay just as fluid as short ones.
class _CascadeIn extends StatelessWidget {
  const _CascadeIn({
    required this.intro,
    required this.index,
    required this.child,
  });

  final Animation<double> intro;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      builder: (context, child) {
        const perRow = 0.11;
        const maxStart = 0.6;
        const window = 0.4;
        final start = (index * perRow).clamp(0.0, maxStart);
        final raw = ((intro.value - start) / window).clamp(0.0, 1.0);
        final eased = Curves.easeOutBack.transform(raw);
        final fade = Curves.easeOut.transform(raw);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(14 * (1 - fade), 44 * (1 - eased)),
            child: Transform.scale(
              scale: 0.88 + 0.12 * eased,
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

// ── Nav bar + hero ──────────────────────────────────────────────────────────

/// The slim nav bar — back (left) + new-folder "+" (right). No title: the title
/// lives BIG in the hero below, matching the category collection pages.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.onBack, required this.onNewFolder});

  /// Null when embedded as a tab → no back button is shown.
  final VoidCallback? onBack;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 4),
      child: Row(
        children: [
          if (onBack != null)
            GlassIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: onBack!,
            ),
          const Spacer(),
          MorphIconButton(
            from: Icons.add_rounded,
            to: Icons.create_new_folder_rounded,
            tooltip: 'New folder',
            onTap: onNewFolder,
          ),
        ],
      ),
    );
  }
}

// ── Tiles & rows ────────────────────────────────────────────────────────────

/// A subtle "Add a document here" tile for an empty, expanded folder.
class _AddHereTile extends StatelessWidget {
  const _AddHereTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A plain line — no box, matching the folder/doc rows.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 10),
              Text('Add to this folder',
                  style: AppText.label.copyWith(color: AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A folder row — tapping it EXPANDS/COLLAPSES in place (a rotating caret shows
/// the state). No right-arrow; its "+" adds inside, ⋯ renames/deletes.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.expanded,
    required this.itemCount,
    required this.subfolderCount,
    required this.onTap,
    required this.onAddInside,
    required this.onRename,
    required this.onDelete,
  });

  final DocFolder folder;
  final bool expanded;
  final int itemCount;
  final int subfolderCount;
  final VoidCallback onTap;
  final VoidCallback onAddInside;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // ONE value under the name — the AGGREGATE of everything inside (items
    // anywhere under this folder). No subfolder count; a single number reads
    // cleanest.
    final countLabel = '$itemCount item${itemCount == 1 ? '' : 's'}';
    // A plain LINE row — no box. Caret, folder glyph, name + count, and ONE menu
    // button on the right holding every action (add inside, rename, delete).
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
          child: Row(
            children: [
              // Rotating caret — the expand/collapse cue.
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: expanded ? 0.25 : 0.0,
                child: const Icon(Icons.chevron_right_rounded,
                    size: 22, color: AppColors.inkFaint),
              ),
              const SizedBox(width: 10),
              // A calm accent glyph — no chip box, just the icon.
              Icon(
                expanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                size: 26,
                color: AppColors.accent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      countLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              // ONE button — the whole action set lives here. "Add inside" leads
              // (it's the primary action), then rename/delete.
              _RowMenu(
                items: [
                  _MenuAction('add', Icons.add_rounded, 'Add inside', onAddInside,
                      accent: true),
                  _MenuAction('rename', Icons.edit_outlined, 'Rename', onRename),
                  _MenuAction('delete', Icons.delete_outline_rounded, 'Delete',
                      onDelete, danger: true),
                ],
              ),
            ],
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
    // A plain LINE row — no box. The thumbnail, the name, and the actions. Tap
    // opens the in-app viewer like a normal screen.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              // The actual document preview — image thumb / PDF first page.
              DocThumbnail(doc: doc, size: 44),
              const SizedBox(width: 16),
              // Just the document name — the thumbnail already shows the type.
              Expanded(
                child: Text(
                  doc.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                ),
              ),
              // ONE button — Open · Share · Rename · Delete all live here.
              _RowMenu(
                items: [
                  _MenuAction('open', Icons.open_in_new_rounded, 'Open', onOpen),
                  _MenuAction('share', Icons.ios_share_rounded, 'Share', onShare),
                  _MenuAction('rename', Icons.edit_outlined, 'Rename', onRename),
                  _MenuAction('delete', Icons.delete_outline_rounded, 'Delete',
                      onDelete, danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row overflow menu ───────────────────────────────────────────────────────

class _MenuAction {
  const _MenuAction(this.value, this.icon, this.label, this.onTap,
      {this.danger = false, this.accent = false});
  final String value;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  /// The primary action (e.g. "Add inside") — tinted accent so it reads as the
  /// lead option in the single menu.
  final bool accent;
}

/// The ONE action button per row — a single ⋯ that opens a menu holding every
/// action for that item (add / open / share / rename / delete), so each row has
/// exactly one control instead of a cluster of icon buttons.
class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.items});
  final List<_MenuAction> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, size: 22),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(8),
      splashRadius: 22,
      onSelected: (v) => items.firstWhere((a) => a.value == v).onTap(),
      itemBuilder: (_) => [
        for (final a in items)
          PopupMenuItem(
            value: a.value,
            height: 46,
            child: _MenuRow(
                icon: a.icon,
                label: a.label,
                danger: a.danger,
                accent: a.accent),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
    this.accent = false,
  });
  final IconData icon;
  final String label;
  final bool danger;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = danger
        ? const Color(0xFFFF6B6B)
        : (accent ? AppColors.accent : AppColors.ink);
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                color: c,
                fontWeight: accent ? FontWeight.w700 : FontWeight.w600)),
      ],
    );
  }
}
