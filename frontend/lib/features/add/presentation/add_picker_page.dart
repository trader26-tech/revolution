import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/reminder_catalog.dart';

/// What the add picker resolved to.
///   • [item]/[category] — the user tapped a catalog item (its label + default
///     cadence + category accent seed the form).
///   • [query]           — the user typed a name and added it as-is.
/// The "Something else" row resolves to its [category] with a null [item].
class AddPickerResult {
  const AddPickerResult.item(this.category, this.item)
      : query = null;
  const AddPickerResult.other(this.category)
      : item = null,
        query = null;
  const AddPickerResult.query(this.query)
      : category = null,
        item = null;

  final ReminderCategory? category;
  final ReminderItem? item;
  final String? query;
}

/// The home "+" screen — one scannable page. A short intro, then every reminder
/// CATEGORY laid out as a section of tappable rows (Birthday, Car insurance,
/// Electricity bill…), each with an "Add your own" escape hatch. A live search
/// pinned at the bottom filters across everything. Tapping anything pops with an
/// [AddPickerResult].
class AddPickerPage extends StatefulWidget {
  const AddPickerPage({super.key});

  @override
  State<AddPickerPage> createState() => _AddPickerPageState();
}

class _AddPickerPageState extends State<AddPickerPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_search.text != _query) setState(() => _query = _search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pickItem(ReminderCategory cat, ReminderItem item) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      item.isOther
          ? AddPickerResult.other(cat)
          : AddPickerResult.item(cat, item),
    );
  }

  void _addTyped() {
    final q = _query.trim();
    if (q.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(AddPickerResult.query(q));
  }

  /// Flat (category, item) matches for the current query.
  List<(ReminderCategory, ReminderItem)> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <(ReminderCategory, ReminderItem)>[];
    for (final c in kReminderCatalog) {
      for (final i in c.items) {
        if (i.isOther) continue;
        if (i.label.toLowerCase().contains(q) ||
            c.title.toLowerCase().contains(q)) {
          out.add((c, i));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onCancel: () => Navigator.of(context).maybePop()),
            Expanded(
              child: searching
                  ? _Results(
                      query: _query.trim(),
                      matches: _matches,
                      onPick: _pickItem,
                      onAddTyped: _addTyped,
                    )
                  : _Browse(onPick: _pickItem),
            ),
            _SearchBar(controller: _search),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _CancelPill(onTap: onCancel),
          const Expanded(
            child: Text(
              'Add to Revolution',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 84), // balance the Cancel pill → keep title centred
        ],
      ),
    );
  }
}

class _CancelPill extends StatelessWidget {
  const _CancelPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Browse (default) ─────────────────────────────────────────────────────────

class _Browse extends StatelessWidget {
  const _Browse({required this.onPick});
  final void Function(ReminderCategory, ReminderItem) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'What should we remember?',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        for (final cat in kReminderCatalog) _CategorySection(cat: cat, onPick: onPick),
      ],
    );
  }
}

/// One category: a coloured header chip + its item rows.
class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.cat, required this.onPick});
  final ReminderCategory cat;
  final void Function(ReminderCategory, ReminderItem) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(cat.icon, size: 17, color: cat.color),
              ),
              const SizedBox(width: 10),
              Text(
                cat.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        for (final item in cat.items)
          _ItemRow(cat: cat, item: item, onTap: () => onPick(cat, item)),
      ],
    );
  }
}

/// One reminder row: a soft accent icon tile, the label, and a trailing "+".
/// The "Something else" row reads as a quieter, dashed-feel add affordance.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.cat, required this.item, required this.onTap});
  final ReminderCategory cat;
  final ReminderItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = item.isOther;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: other
                    ? Colors.white.withValues(alpha: 0.04)
                    : cat.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: other
                    ? Border.all(color: AppColors.cardBorder)
                    : null,
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: other ? AppColors.inkSoft : cat.color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                other ? 'Add your own' : item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: other ? FontWeight.w600 : FontWeight.w600,
                  color: other ? AppColors.inkSoft : AppColors.ink,
                ),
              ),
            ),
            Icon(
              Icons.add_rounded,
              size: 22,
              color: AppColors.inkFaint.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search results ───────────────────────────────────────────────────────────

class _Results extends StatelessWidget {
  const _Results({
    required this.query,
    required this.matches,
    required this.onPick,
    required this.onAddTyped,
  });

  final String query;
  final List<(ReminderCategory, ReminderItem)> matches;
  final void Function(ReminderCategory, ReminderItem) onPick;
  final VoidCallback onAddTyped;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        // Always offer the typed name first — anything can be added.
        InkWell(
          onTap: onAddTyped,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded,
                      size: 20, color: AppColors.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Add “$query”',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final (cat, item) in matches)
          _ItemRow(cat: cat, item: item, onTap: () => onPick(cat, item)),
      ],
    );
  }
}

// ── Bottom search bar ────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppColors.ink, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Search or add anything…',
            hintStyle: TextStyle(color: AppColors.inkFaint),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkFaint),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
