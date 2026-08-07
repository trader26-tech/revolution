import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/onboarding_category.dart';
import '../widgets/reminder_confirm_sheet.dart';
import 'category_gallery_screen.dart';
import 'reminder_detail_screen.dart';

/// The multi-screen onboarding data flow (preview / to-be-wired):
///   1. Category gallery — pick which reminders you want.
///   2. Then walk each selected reminder through its OWN full screen to set the
///      name, day (knob), and frequency — one at a time.
///
/// Opened from the home dev button so the whole thing can be tested on device.
class GalleryPreviewPage extends StatefulWidget {
  const GalleryPreviewPage({super.key});

  @override
  State<GalleryPreviewPage> createState() => _GalleryPreviewPageState();
}

class _GalleryPreviewPageState extends State<GalleryPreviewPage> {
  Map<String, ReminderDraft> _drafts = {};

  /// The ordered list of selected categories to walk through.
  List<OnboardingCategory> get _selected => kOnboardingCategories
      .where((c) => _drafts.containsKey(c.key))
      .toList();

  Future<void> _continueToDetails() async {
    final selected = _selected;
    if (selected.isEmpty) return;

    // Walk each selected reminder through its own full screen.
    for (var i = 0; i < selected.length; i++) {
      final cat = selected[i];
      if (!mounted) return;
      final edited = await Navigator.of(context).push<ReminderDraft>(
        MaterialPageRoute(
          builder: (_) => ReminderDetailScreen(
            category: cat,
            draft: _drafts[cat.key]!,
            index: i,
            total: selected.length,
            onNext: (d) => Navigator.of(context).pop(d),
            onBack: i == 0 ? null : () => Navigator.of(context).maybePop(),
          ),
        ),
      );
      // If they backed out of a detail screen, stop the walk.
      if (edited == null) return;
      _drafts[cat.key] = edited;
    }

    if (!mounted) return;
    // Done — pop the whole preview. (In the real flow this continues to phone
    // login and saves the drafts to the account.)
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Set up ${selected.length} reminders 🎉')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _drafts.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: CategoryGalleryScreen(
                onChanged: (d) => setState(() => _drafts = Map.of(d)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: n == 0 ? null : _continueToDetails,
                  child: Text(
                    n == 0 ? 'Pick at least one' : 'Continue',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
