import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../../documents/data/documents_store.dart';
import '../../../documents/domain/document.dart';
import '../../../tasks/data/task_store.dart';
import '../../../tasks/domain/category_visuals.dart';
import '../../../tasks/domain/task.dart';

/// The ★ QUICK-ACCESS SEARCH — a command-palette / Spotlight. Type anything and
/// jump straight to it: a reminder, a document, or a category. Typing something
/// new can also add it. This is the ★'s root content (before any chat).
class QuickSearch extends StatelessWidget {
  const QuickSearch({
    super.key,
    required this.store,
    required this.documents,
    required this.query,
    required this.progress,
    required this.onOpenTask,
    required this.onOpenDocument,
    required this.onOpenCategory,
    required this.onAdd,
  });

  final TaskStore store;
  final DocumentsStore documents;

  /// The live text from the search field.
  final String query;

  /// 0→1 entrance progress (fades the content in).
  final double progress;

  final ValueChanged<Task> onOpenTask;
  final ValueChanged<DocItem> onOpenDocument;
  final ValueChanged<TaskCategory> onOpenCategory;
  final ValueChanged<String> onAdd;

  static const _perGroup = 5;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Rebuild when tasks OR documents change.
      animation: Listenable.merge([store, documents]),
      builder: (context, _) {
        final reveal = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
        final q = query.trim();
        return Opacity(
          opacity: reveal,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
            child: q.isEmpty ? _idle(context) : _results(context, q),
          ),
        );
      },
    );
  }

  // ── Idle (empty query) ─────────────────────────────────────────────────────
  Widget _idle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find anything',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 26,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Search your reminders, documents & categories — or type to add.',
          style: TextStyle(
            color: AppColors.inkSoft.withValues(alpha: 0.95),
            fontSize: 14.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        _GroupLabel('Jump to a category'),
        const SizedBox(height: 4),
        for (final c in TaskCategory.values)
          _ResultRow(
            icon: c.icon,
            title: c.label,
            subtitle: _categoryCount(c),
            onTap: () => onOpenCategory(c),
          ),
      ],
    );
  }

  String _categoryCount(TaskCategory c) {
    final n = store.tasks.where((t) => t.category == c && !t.done).length;
    return n == 0 ? 'No reminders' : (n == 1 ? '1 reminder' : '$n reminders');
  }

  // ── Results (with a query) ─────────────────────────────────────────────────
  Widget _results(BuildContext context, String q) {
    final tasks = _matchTasks(q);
    final docs = _matchDocs(q);
    final cats = _matchCategories(q);

    final children = <Widget>[];

    if (tasks.isNotEmpty) {
      children.add(_GroupLabel('Reminders'));
      for (final t in tasks.take(_perGroup)) {
        children.add(_ResultRow(
          icon: t.category.icon,
          title: t.title,
          subtitle: _taskMeta(t),
          onTap: () => onOpenTask(t),
        ));
      }
      if (tasks.length > _perGroup) {
        children.add(_MoreLine('+${tasks.length - _perGroup} more reminders'));
      }
      children.add(const SizedBox(height: 12));
    }

    if (docs.isNotEmpty) {
      children.add(_GroupLabel('Documents'));
      for (final d in docs.take(_perGroup)) {
        children.add(_ResultRow(
          icon: d.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
          title: d.name,
          subtitle: d.isPdf ? 'PDF' : 'Image',
          onTap: () => onOpenDocument(d),
        ));
      }
      if (docs.length > _perGroup) {
        children.add(_MoreLine('+${docs.length - _perGroup} more documents'));
      }
      children.add(const SizedBox(height: 12));
    }

    if (cats.isNotEmpty) {
      children.add(_GroupLabel('Categories'));
      for (final c in cats) {
        children.add(_ResultRow(
          icon: c.icon,
          title: c.label,
          subtitle: _categoryCount(c),
          onTap: () => onOpenCategory(c),
        ));
      }
      children.add(const SizedBox(height: 12));
    }

    // Always offer to add what was typed.
    children.add(_ResultRow(
      icon: Icons.add_rounded,
      accent: true,
      title: 'Add “$q”',
      subtitle: 'Create a new reminder',
      onTap: () => onAdd(q),
    ));

    // Nothing matched (only the Add row) → a gentle line above it.
    if (tasks.isEmpty && docs.isEmpty && cats.isEmpty) {
      children.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'No matches for “$q”.',
            style: TextStyle(
              color: AppColors.inkSoft.withValues(alpha: 0.9),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  String _taskMeta(Task t) {
    final bits = <String>[t.category.label];
    if (t.hasAmount) {
      final cur = currencyOf(t.currency);
      final a = t.amount!;
      final body = a == a.roundToDouble()
          ? formatAmount(a.round().toString(), cur.grouping)
          : a.toStringAsFixed(2);
      bits.add('${cur.symbol}$body');
    }
    return bits.join('  ·  ');
  }

  // ── Matching (fuzzy, best-first) ───────────────────────────────────────────
  List<Task> _matchTasks(String query) {
    final q = query.toLowerCase();
    final qWords = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final scored = <(Task, int)>[];
    for (final t in store.tasks) {
      if (t.done) continue;
      final title = t.title.toLowerCase();
      var score = 0;
      if (title == q) {
        score = 100;
      } else if (title.contains(q)) {
        score = 70;
      } else if (q.contains(title) && title.isNotEmpty) {
        score = 55;
      } else {
        final tWords = title.split(RegExp(r'\s+')).toSet();
        final overlap = qWords.where(tWords.contains).length;
        if (overlap > 0) score = 25 * overlap;
      }
      // Secondary fields — lower weight so title always wins.
      if (score == 0) {
        final hay = [
          t.note ?? '',
          t.subCategory ?? '',
          t.category.label,
        ].join(' ').toLowerCase();
        if (hay.contains(q)) score = 15;
      }
      if (score > 0) scored.add((t, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  List<DocItem> _matchDocs(String query) {
    final q = query.toLowerCase();
    return documents.allItems.where((d) {
      final name = d.name.toLowerCase();
      final orig = (d.originalName ?? '').toLowerCase();
      return name.contains(q) || orig.contains(q);
    }).toList();
  }

  List<TaskCategory> _matchCategories(String query) {
    final q = query.toLowerCase();
    return TaskCategory.values.where((c) {
      return c.label.toLowerCase().contains(q) ||
          c.singular.toLowerCase().contains(q);
    }).toList();
  }
}

/// A small uppercase group label.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.inkFaint,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// One tappable result row — a tinted glyph, a title, a subtitle, a chevron.
class _ResultRow extends StatefulWidget {
  const _ResultRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.accent = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: _down
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: widget.accent ? 0.9 : 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(widget.icon,
                  size: 20,
                  color: widget.accent ? Colors.white : AppColors.accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.inkSoft.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _MoreLine extends StatelessWidget {
  const _MoreLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 61, top: 2, bottom: 4),
      child: Text(text,
          style: TextStyle(
            color: AppColors.inkFaint,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}
