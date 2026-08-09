import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/brand_catalog.dart';
import '../domain/brand.dart';
import 'brand_logo.dart';

/// Opens the brand/app logo picker. Returns the chosen [Brand] (with a real
/// logo when one exists, or a letter-avatar fallback), or null if dismissed.
///
/// The user can type ANY name: popular brands surface as they type, and the
/// free-typed name is always offered as the first result — so any app/company
/// logo can be added. Smooth, instant, offline-safe.
/// Which curated shelf the picker shows before the user types.
enum BrandPickerMode { all, subscriptions, platforms }

Future<Brand?> showBrandPicker(
  BuildContext context, {
  bool subscriptionsOnly = false,
  BrandPickerMode mode = BrandPickerMode.all,
}) {
  // `subscriptionsOnly` kept for back-compat; `mode` wins when set.
  final resolved = mode != BrandPickerMode.all
      ? mode
      : (subscriptionsOnly ? BrandPickerMode.subscriptions : BrandPickerMode.all);
  return showModalBottomSheet<Brand>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _BrandPickerSheet(mode: resolved),
  );
}

class _BrandPickerSheet extends StatefulWidget {
  const _BrandPickerSheet({this.mode = BrandPickerMode.all});

  /// The curated shelf to show (subscriptions / investment platforms / general).
  final BrandPickerMode mode;

  bool get curated => mode != BrandPickerMode.all;

  @override
  State<_BrandPickerSheet> createState() => _BrandPickerSheetState();
}

class _BrandPickerSheetState extends State<_BrandPickerSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Brand> get _results => switch (widget.mode) {
        BrandPickerMode.subscriptions =>
          BrandCatalog.searchSubscriptions(_query),
        BrandPickerMode.platforms => BrandCatalog.searchPlatforms(_query),
        BrandPickerMode.all => BrandCatalog.search(_query),
      };

  @override
  Widget build(BuildContext context) {
    // Take most of the screen so the grid has room; leave the keyboard space.
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.88;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Text(
                      switch (widget.mode) {
                        BrandPickerMode.subscriptions => 'Choose a subscription',
                        BrandPickerMode.platforms => 'Choose a platform',
                        BrandPickerMode.all => 'Choose an icon',
                      },
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          )),
                ],
              ),
            ),
            _SearchField(
              controller: _controller,
              focus: _focus,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 4),
            // Searching → a clean vertical list of matches (one logo each, no
            // duplicates). Browsing → category-wise sections of top brand logos.
            Expanded(
              child: _query.trim().isEmpty
                  ? (widget.curated
                      ? _curatedBrowser()
                      : _categoryBrowser())
                  : Column(
                      children: [
                        _sectionLabel('Results'),
                        Expanded(
                            child: _resultsList(_results,
                                circular: widget.curated)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.inkFaint.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ),
      );

  /// A curated shelf — one grid of the mode's brands (subscriptions or SIP
  /// platforms), logos only. Feels like a purpose-built store.
  Widget _curatedBrowser() {
    final items = widget.mode == BrandPickerMode.platforms
        ? BrandCatalog.searchPlatforms('')
        : BrandCatalog.searchSubscriptions('');
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _BrandCell(
        brand: items[i],
        circular: true, // clean circular badge, no white square
        onTap: () => Navigator.pop(context, items[i]),
      ),
    );
  }

  /// The category-wise browser shown before the user types: each of the app's
  /// categories with ~10 top brand logos, so tapping is faster than typing.
  Widget _categoryBrowser() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      itemCount: BrandCatalog.categories.length,
      itemBuilder: (_, i) {
        final cat = BrandCatalog.categories[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title — a Material icon renders reliably (no "□?" tofu).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                children: [
                  Icon(cat.icon, size: 16, color: AppColors.inkFaint),
                  const SizedBox(width: 8),
                  Text(
                    cat.title,
                    style: const TextStyle(
                      color: AppColors.inkFaint,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              itemCount: cat.brands.length,
              itemBuilder: (_, j) {
                final b = cat.brands[j];
                return _BrandCell(
                    brand: b, onTap: () => Navigator.pop(context, b));
              },
            ),
          ],
        );
      },
    );
  }

  /// The search results as a clean vertical list — one row per app, a single
  /// logo each (multi-source fallback under the hood), no duplicates.
  Widget _resultsList(List<Brand> brands, {bool circular = false}) {
    if (brands.isEmpty) {
      return const Center(
        child: Text('Type any app or company name',
            style: TextStyle(color: AppColors.inkFaint)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: brands.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = brands[i];
        return _BrandRow(
            brand: b,
            circular: circular,
            onTap: () => Navigator.pop(context, b));
      },
    );
  }
}

/// One app in the search results: logo on the left, name, tap to add.
class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.brand,
    required this.onTap,
    this.circular = false,
  });

  final Brand brand;
  final VoidCallback onTap;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              BrandLogo(
                  brand: brand,
                  size: 44,
                  radius: 12,
                  bare: circular,
                  circular: circular),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  brand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontSize: 15),
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: controller,
          focusNode: focus,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search Netflix, HDFC, Zerodha…',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkFaint),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.inkFaint,
                    onPressed: onClear,
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}

class _BrandCell extends StatelessWidget {
  const _BrandCell({
    required this.brand,
    required this.onTap,
    this.circular = false,
  });

  final Brand brand;
  final VoidCallback onTap;

  /// Draw the logo as a clean circular badge (no white square) — used on the
  /// subscriptions shelf so tiles read as part of the orbit theme.
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrandLogo(
            brand: brand,
            size: 52,
            radius: 14,
            bare: circular,
            circular: circular,
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              brand.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
