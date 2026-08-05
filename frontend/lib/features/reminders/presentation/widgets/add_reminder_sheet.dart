import 'package:flutter/material.dart';

import '../../data/reminders_repository.dart';
import '../../domain/catalog.dart';
import '../../domain/reminder.dart';
import '../../domain/scheduling.dart';
import 'reminder_form.dart';

/// Opens the add-reminder flow as a near-full-height sheet and resolves to the
/// created [Reminder] (or null if dismissed).
///
/// Design: one clean, tag-grouped, icon-forward picker. The user searches or
/// scans by category and taps a tile — that's it. Everything (dates, lead time,
/// defaults) is computed for them, so the common path is zero typing. A quiet
/// "Customise" path stays for the rare case they want to tweak.
Future<Reminder?> showAddReminderSheet(
  BuildContext context, {
  required RemindersRepository repository,
}) {
  return showModalBottomSheet<Reminder>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddReminderSheet(repository: repository),
  );
}

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet({required this.repository});
  final RemindersRepository repository;

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _search = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final q = _search.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Categories filtered to those with items matching the query (or all when
  /// the query is empty).
  List<_CatGroup> get _groups {
    final out = <_CatGroup>[];
    for (final c in kCategories) {
      final items = _query.isEmpty
          ? c.items
          : c.items
              .where((i) => i.title.toLowerCase().contains(_query))
              .toList();
      if (items.isNotEmpty) out.add(_CatGroup(c, items));
    }
    return out;
  }

  /// Tap-to-add: build the fully-prefilled draft and save immediately.
  Future<void> _quickAdd(ReminderCategory category, CatalogItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    final draft = Scheduling.draftFor(item, from: DateTime.now());
    try {
      final created = await widget.repository.create(draft);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save: $e")),
        );
      }
    }
  }

  /// The quiet "customise" path — opens the full form for fine control.
  Future<void> _customise(ReminderCategory category, CatalogItem item) async {
    final created = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CustomiseScreen(
          repository: widget.repository,
          category: category,
          item: item,
        ),
      ),
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final groups = _groups;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            _SearchBar(controller: _search),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: groups.isEmpty
                  ? _NoResults(query: _query)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24, top: 4),
                      itemCount: groups.length,
                      itemBuilder: (_, i) {
                        final g = groups[i];
                        return _CategorySection(
                          group: g,
                          onTapItem: (item) => _quickAdd(g.category, item),
                          onLongPressItem: (item) =>
                              _customise(g.category, item),
                        );
                      },
                    ),
            ),
            _Hint(scheme: scheme),
          ],
        ),
      ),
    );
  }
}

/// A category paired with its (possibly filtered) items.
class _CatGroup {
  const _CatGroup(this.category, this.items);
  final ReminderCategory category;
  final List<CatalogItem> items;
}

/// One tag-headed section: a coloured category header + a grid of icon tiles.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.group,
    required this.onTapItem,
    required this.onLongPressItem,
  });

  final _CatGroup group;
  final ValueChanged<CatalogItem> onTapItem;
  final ValueChanged<CatalogItem> onLongPressItem;

  @override
  Widget build(BuildContext context) {
    final c = group.category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The "tag" — a coloured pill with the category icon + name.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 16, color: c.color),
                    const SizedBox(width: 7),
                    Text(
                      c.label,
                      style: TextStyle(
                        color: c.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The icon-forward grid — logo first, one short line of text.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 118,
            mainAxisExtent: 108,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: group.items.length,
          itemBuilder: (_, i) {
            final item = group.items[i];
            return _ItemTile(
              item: item,
              color: c.color,
              onTap: () => onTapItem(item),
              onLongPress: () => onLongPressItem(item),
            );
          },
        ),
      ],
    );
  }
}

/// A single tappable tile: a big coloured logo and a short label. Minimal text.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  final CatalogItem item;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  _shortLabel(item.title),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Trims noise words so tiles read as short nouns ("Passport", not "Passport
  /// Renewal") — less text, faster to scan.
  static String _shortLabel(String title) {
    const noise = [
      ' Renewal',
      ' Payment',
      ' Due',
      ' Update',
      ' Verification',
      ' Premium',
    ];
    var out = title;
    for (final n in noise) {
      if (out.endsWith(n)) {
        out = out.substring(0, out.length - n.length);
        break;
      }
    }
    return out;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search — passport, bill, insurance…',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Text(
        'Tap to add instantly · long-press to customise',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Nothing matches "$query"',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The optional customise screen — the full prefilled form, opened only on a
/// long-press. Most users never see it.
class _CustomiseScreen extends StatefulWidget {
  const _CustomiseScreen({
    required this.repository,
    required this.category,
    required this.item,
  });

  final RemindersRepository repository;
  final ReminderCategory category;
  final CatalogItem item;

  @override
  State<_CustomiseScreen> createState() => _CustomiseScreenState();
}

class _CustomiseScreenState extends State<_CustomiseScreen> {
  bool _submitting = false;

  Future<void> _submit(ReminderDraft draft) async {
    setState(() => _submitting = true);
    try {
      final created = await widget.repository.create(draft);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ReminderForm(
          category: widget.category,
          item: widget.item,
          submitting: _submitting,
          onSubmit: _submit,
        ),
      ),
    );
  }
}
