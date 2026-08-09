import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
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
  /// A blank general reminder — no category, no name. The "Add a reminder" row.
  const AddPickerResult.blank()
      : category = null,
        item = null,
        query = null;

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

  /// Tapping a category row → open that category's form (no specific item).
  void _pickCategory(ReminderCategory cat) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(AddPickerResult.other(cat));
  }

  /// "Add a reminder" → a blank general reminder.
  void _pickBlank() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(const AddPickerResult.blank());
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
                  : _Browse(
                      onPickCategory: _pickCategory,
                      onBlank: _pickBlank,
                    ),
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
          // iPhone-style frosted-glass circular back button.
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onTap: onCancel,
          ),
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
          // Balance the back button so the title stays centred (a glass button
          // is ~44px).
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ── Browse (default): a clean list of CATEGORIES ─────────────────────────────

/// A short, human blurb per category for the row's second line.
String _blurbFor(String key) => switch (key) {
      'important_dates' => 'Birthdays, anniversaries, big days',
      'subscriptions' => 'Netflix, Prime, Spotify, gym…',
      'insurance' => 'Health, car, life — with the policy',
      'bills' => 'Electricity, rent, phone, internet',
      'investments' => 'SIPs, mutual funds, premiums',
      'documents' => 'Passport, licence, PAN, visa',
      'health_home' => 'Appointments, services, maintenance',
      _ => 'Reminders in this category',
    };

class _Browse extends StatelessWidget {
  const _Browse({required this.onPickCategory, required this.onBlank});
  final void Function(ReminderCategory) onPickCategory;
  final VoidCallback onBlank;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      children: [
        // Pick a category — one clean, tappable row each. Every row uses the
        // SAME neutral "add reminder" glyph (no per-category colour), so the
        // list reads as one calm, uniform set instead of a rainbow of icons.
        for (final cat in kReminderCatalog)
          _CategoryRow(
            title: cat.title,
            blurb: _blurbFor(cat.key),
            icon: Icons.add_alert_rounded,
            color: AppColors.inkSoft,
            onTap: () => onPickCategory(cat),
          ),
        const _RowDivider(),
        // The catch-all: a blank reminder, no category — same neutral glyph.
        _CategoryRow(
          title: 'Add a reminder',
          blurb: 'Anything else — just a name & date',
          icon: Icons.add_alert_rounded,
          color: AppColors.inkSoft,
          onTap: onBlank,
        ),
      ],
    );
  }
}

/// One category row — a coloured logo tile, title + blurb, and a chevron. Clean
/// and scannable, like a native list.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String blurb;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    blurb,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.inkFaint.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(80, 4, 20, 4),
        child: Divider(height: 1, color: AppColors.hairline),
      );
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
            // Every item shows the SAME neutral "add reminder" glyph — no
            // per-item colour or logo, so the list stays uniform and calm.
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(
                Icons.add_alert_rounded,
                size: 20,
                color: AppColors.inkSoft,
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
