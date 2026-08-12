import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';
import '../data/documents_store.dart';
import '../domain/document.dart';
import 'add_document_sheet.dart';

/// The Documents tab — the go-to place for every file the user keeps.
///
/// One unified library: documents added here directly PLUS any file attached to
/// a reminder, grouped into folders (the task categories). Each row opens in the
/// native viewer or shares with one tap; the "+" adds a new document (name →
/// folder → file). Built to make add / view / share effortless.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.store});

  final DocumentsStore store;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  @override
  void initState() {
    super.initState();
    // Load the standalone library once, after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.store.isInitialLoad) widget.store.load();
    });
  }

  Future<void> _add() async {
    HapticFeedback.selectionClick();
    final added = await showAddDocumentSheet(context, store: widget.store);
    if (added != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added “${added.name}”')),
      );
    }
  }

  Future<void> _open(Document doc) async {
    HapticFeedback.selectionClick();
    final result = await OpenFilex.open(doc.localPath);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open this document")),
      );
    }
  }

  Future<void> _share(Document doc) async {
    HapticFeedback.selectionClick();
    // Share the actual on-device file.
    await Share.shareXFiles(
      [XFile(doc.localPath, name: doc.originalName ?? doc.name)],
      subject: doc.name,
    );
  }

  Future<void> _delete(Document doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete document?',
            style: TextStyle(color: AppColors.ink)),
        content: Text(
          '“${doc.name}” will be removed from your library.',
          style: const TextStyle(color: AppColors.inkSoft),
        ),
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
    if (ok != true) return;
    try {
      await widget.store.remove(doc);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete — try again")),
        );
      }
    }
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
          child: Column(
            children: [
              const SizedBox(height: 6),
              _TopBar(onAdd: _add, onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.store,
                  builder: (context, _) => _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final store = widget.store;
    if (store.isInitialLoad) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    final groups = store.byFolder;
    if (groups.isEmpty) {
      return _EmptyState(onAdd: _add);
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.card,
      onRefresh: store.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
        children: [
          for (final entry in groups.entries)
            _FolderSection(
              category: entry.key,
              docs: entry.value,
              onOpen: _open,
              onShare: _share,
              onDelete: _delete,
            ),
        ],
      ),
    );
  }
}

/// The glass top bar — back + title + a prominent "Add" button.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onAdd, required this.onBack});
  final VoidCallback onAdd;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Documents',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.6,
              ),
            ),
          ),
          GlassIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Add document',
            accent: true,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

/// One folder block: a category header with a count, then its document rows.
class _FolderSection extends StatelessWidget {
  const _FolderSection({
    required this.category,
    required this.docs,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final TaskCategory category;
  final List<Document> docs;
  final ValueChanged<Document> onOpen;
  final ValueChanged<Document> onShare;
  final ValueChanged<Document> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(category.icon, size: 17, color: category.color),
              ),
              const SizedBox(width: 10),
              Text(
                category.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${docs.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
        for (final d in docs)
          _DocRow(
            doc: d,
            onOpen: () => onOpen(d),
            onShare: () => onShare(d),
            onDelete: () => onDelete(d),
          ),
      ],
    );
  }
}

/// A single document row — icon, name, meta, and quick share. Tap opens it;
/// long-press / the ⋯ menu offers share + delete.
class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final Document doc;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (doc.isPdf) 'PDF' else 'Image',
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
                    color: doc.folder.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    doc.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    size: 21,
                    color: doc.folder.color,
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
                      if (meta.isNotEmpty) ...[
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
                    ],
                  ),
                ),
                // Quick share — the primary secondary action.
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  color: AppColors.inkSoft,
                  tooltip: 'Share',
                ),
                _MoreMenu(
                  onOpen: onOpen,
                  onShare: onShare,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onOpen, required this.onShare, this.onDelete});
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      color: AppColors.card,
      onSelected: (v) {
        switch (v) {
          case 'open':
            onOpen();
          case 'share':
            onShare();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'open',
          child: _MenuRow(icon: Icons.open_in_new_rounded, label: 'Open'),
        ),
        const PopupMenuItem(
          value: 'share',
          child: _MenuRow(icon: Icons.ios_share_rounded, label: 'Share'),
        ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              danger: true,
            ),
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

/// The welcoming empty state — a single, obvious call to add the first doc.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
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
              child: const Icon(Icons.folder_copy_rounded,
                  size: 44, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your documents, all in one place',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add any file — a statement, a policy, an ID — into a folder, and '
              'open or share it anytime. Kept privately on your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a document'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
