import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../reminders/domain/reminder_draft.dart';
import '../domain/item_catalog.dart';
import 'entry_sheet.dart';
import 'widgets/document_thumb.dart';

/// The item list for one category — e.g. Identity & Government → Aadhaar, PAN,
/// Passport… Searchable, each row a stylized document thumbnail. Tapping an item
/// opens the minimal entry sheet; a completed draft pops back up the stack.
class ItemListPage extends StatefulWidget {
  const ItemListPage({
    super.key,
    required this.categoryName,
    required this.items,
  });

  final String categoryName;
  final List<Item> items;

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final q = _search.text.trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Item> get _filtered =>
      widget.items.where((i) => i.matches(_query)).toList();

  Future<void> _open(Item item) async {
    final draft = await showEntrySheet(
      context,
      item: item,
      categoryName: widget.categoryName,
    );
    if (draft != null && mounted) {
      // Bubble the finished draft all the way back to whoever opened Add.
      Navigator.of(context).pop<ReminderDraft>(draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.ink),
        title: Text(
          widget.categoryName,
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('No matches',
                        style: TextStyle(color: AppColors.inkSoft)),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 88,
                      endIndent: 20,
                      color: AppColors.hairline,
                    ),
                    itemBuilder: (_, i) => _ItemRow(
                      item: items[i],
                      onTap: () => _open(items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            DocumentThumb(item: item, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(item),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
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

  String _subtitle(Item item) {
    switch (item.anchor) {
      case AnchorType.none:
        return 'No expiry · stored for reference';
      case AnchorType.expiry:
        return 'Remind ${item.leadDays} days before it expires';
      case AnchorType.issuePlusValidity:
        final yrs = (item.validityDays ?? 365) ~/ 365;
        return yrs >= 1
            ? 'Review every $yrs ${yrs == 1 ? "year" : "years"}'
            : 'Valid a few months · we\'ll nudge you';
    }
  }
}
