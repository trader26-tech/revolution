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
Future<Brand?> showBrandPicker(BuildContext context) {
  return showModalBottomSheet<Brand>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _BrandPickerSheet(),
  );
}

class _BrandPickerSheet extends StatefulWidget {
  const _BrandPickerSheet();

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

  List<Brand> get _results => BrandCatalog.search(_query);

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
                  Text('Choose an icon',
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
            if (_query.trim().isNotEmpty)
              _LivePreview(brand: BrandCatalog.resolve(_query),
                  onAdd: () => Navigator.pop(context, BrandCatalog.resolve(_query))),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _query.trim().isEmpty ? 'Popular' : 'Matches',
                  style: const TextStyle(
                    color: AppColors.inkFaint,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            Expanded(child: _grid(_results)),
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

  Widget _grid(List<Brand> brands) {
    if (brands.isEmpty) {
      return const Center(
        child: Text('Type any app or company name',
            style: TextStyle(color: AppColors.inkFaint)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: brands.length,
      itemBuilder: (_, i) {
        final b = brands[i];
        return _BrandCell(brand: b, onTap: () => Navigator.pop(context, b));
      },
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

/// A prominent live preview of the free-typed name → its resolved logo, with a
/// clear "Add" affordance. Makes "type anything, get its logo" obvious.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.brand, required this.onAdd});

  final Brand brand;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                BrandLogo(brand: brand, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brand.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              fontSize: 15)),
                      const Text('Tap to add this icon',
                          style: TextStyle(
                              color: AppColors.inkSoft, fontSize: 12.5)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Add',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandCell extends StatelessWidget {
  const _BrandCell({required this.brand, required this.onTap});

  final Brand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrandLogo(brand: brand, size: 52, radius: 14),
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
