import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../brand/data/brand_catalog.dart';
import '../../brand/domain/brand.dart';
import '../../brand/presentation/brand_logo.dart';
import '../domain/add_category.dart';

/// What the add picker resolved to. Exactly one field is set:
///   • [brand]    — the user tapped a brand → open the subscription form
///                  pre-filled with it.
///   • [category] — the user tapped a top action (Type or paste → subscription;
///                  Birthday; Insurance) → open that category's blank form.
///   • [query]    — the user typed a name and chose to add it as-is.
class AddPickerResult {
  const AddPickerResult.brand(this.brand)
      : category = null,
        query = null;
  const AddPickerResult.category(this.category)
      : brand = null,
        query = null;
  const AddPickerResult.query(this.query)
      : brand = null,
        category = null;

  final Brand? brand;
  final AddCategory? category;
  final String? query;
}

/// The home "+" screen — one rich, scannable page: a few quick actions at the
/// top (import a receipt, type it in), then the whole brand catalog laid out as
/// category sections of tappable rows, with a live search pinned at the bottom.
/// Tapping anything resolves the add and pops with an [AddPickerResult].
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

  void _pickBrand(Brand b) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(AddPickerResult.brand(b));
  }

  void _pickCategory(AddCategory c) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(AddPickerResult.category(c));
  }

  void _addTyped() {
    final q = _query.trim();
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      q.isEmpty
          ? const AddPickerResult.category(AddCategory.subscription)
          : AddPickerResult.query(q),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final results = searching ? BrandCatalog.search(_query) : const <Brand>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onCancel: () => Navigator.of(context).maybePop()),
            Expanded(
              child: searching
                  ? _SearchResults(
                      query: _query.trim(),
                      results: results,
                      onPickBrand: _pickBrand,
                      onAddTyped: _addTyped,
                    )
                  : _Browse(
                      onPickBrand: _pickBrand,
                      onPickCategory: _pickCategory,
                      onTypeOrPaste: _addTyped,
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
          _PillButton(label: 'Cancel', onTap: onCancel),
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
          // Balance the Cancel pill so the title stays centred.
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: const TextStyle(
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

// ── Browse (default) view ────────────────────────────────────────────────────

class _Browse extends StatelessWidget {
  const _Browse({
    required this.onPickBrand,
    required this.onPickCategory,
    required this.onTypeOrPaste,
  });

  final ValueChanged<Brand> onPickBrand;
  final ValueChanged<AddCategory> onPickCategory;
  final VoidCallback onTypeOrPaste;

  @override
  Widget build(BuildContext context) {
    final cats = BrandCatalog.categories;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const SizedBox(height: 8),
        // Quick actions — the ways in that aren't "pick a brand".
        _ActionRow(
          icon: Icons.photo_library_rounded,
          title: 'Import from photos',
          subtitle: 'Receipt, bill or renewal screenshots',
          onTap: onTypeOrPaste, // TODO: dedicated photo-import flow
        ),
        _ActionRow(
          icon: Icons.description_rounded,
          title: 'Import a file',
          subtitle: 'Bank statement or spreadsheet (PDF or CSV)',
          onTap: onTypeOrPaste, // TODO: dedicated file-import flow
        ),
        _ActionRow(
          icon: Icons.auto_awesome_rounded,
          title: 'Type or paste',
          subtitle: 'Name, price and how often you pay',
          onTap: onTypeOrPaste,
        ),
        const SizedBox(height: 6),
        // The other add types — birthday & insurance get their own tailored form.
        _ActionRow(
          icon: AddCategory.birthday.icon,
          accent: AddCategory.birthday.color,
          title: 'Birthday or anniversary',
          subtitle: 'Never miss the people who matter',
          onTap: () => onPickCategory(AddCategory.birthday),
        ),
        _ActionRow(
          icon: AddCategory.insurance.icon,
          accent: AddCategory.insurance.color,
          title: 'Insurance',
          subtitle: 'Health, car, life — with the policy attached',
          onTap: () => onPickCategory(AddCategory.insurance),
        ),
        const SizedBox(height: 8),
        // Every brand category as its own section of rows.
        for (final cat in cats) ...[
          _SectionHeader(title: cat.title.toUpperCase(), icon: cat.icon),
          for (final b in cat.brands)
            _BrandRow(brand: b, onTap: () => onPickBrand(b)),
        ],
      ],
    );
  }
}

/// A top quick-action row: a rounded accent icon tile, a title and a subtitle.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = AppColors.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;

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
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 24),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet all-caps section header with a small leading icon, and a hairline
/// above it to separate bands as you scroll — matching the catalog picker.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// One brand row: the real logo, the name, and a subtle add affordance.
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.brand, required this.onTap});
  final Brand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: BrandLogo(brand: brand, size: 44, radius: 10),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  brand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            Icon(
              Icons.add_rounded,
              color: AppColors.inkFaint.withValues(alpha: 0.7),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search results view ──────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.results,
    required this.onPickBrand,
    required this.onAddTyped,
  });

  final String query;
  final List<Brand> results;
  final ValueChanged<Brand> onPickBrand;
  final VoidCallback onAddTyped;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: [
        // Always offer the typed name as its own add, first — so any app or
        // company can be added, not only the ones in the catalog.
        _ActionRow(
          icon: Icons.add_circle_outline_rounded,
          title: 'Add “$query”',
          subtitle: 'Use this name as you typed it',
          onTap: onAddTyped,
        ),
        if (results.isNotEmpty)
          const _SectionHeader(title: 'MATCHES', icon: Icons.search_rounded),
        for (final b in results)
          _BrandRow(brand: b, onTap: () => onPickBrand(b)),
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
          decoration: InputDecoration(
            hintText: 'Search Netflix, HDFC, Zerodha…',
            hintStyle: const TextStyle(color: AppColors.inkFaint),
            prefixIcon:
                const Icon(Icons.search_rounded, color: AppColors.inkFaint),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.inkFaint,
                    onPressed: controller.clear,
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
