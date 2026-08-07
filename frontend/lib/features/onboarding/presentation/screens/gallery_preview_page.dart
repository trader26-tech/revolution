import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/reminder_confirm_sheet.dart';
import 'category_gallery_screen.dart';

/// A standalone page to preview/test the new category gallery + knob date
/// picker before the full flow is wired. Opened from the home dev button.
class GalleryPreviewPage extends StatefulWidget {
  const GalleryPreviewPage({super.key});

  @override
  State<GalleryPreviewPage> createState() => _GalleryPreviewPageState();
}

class _GalleryPreviewPageState extends State<GalleryPreviewPage> {
  Map<String, ReminderDraft> _drafts = {};

  @override
  Widget build(BuildContext context) {
    final n = _drafts.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // A slim top bar with a close button.
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
                  onPressed: n == 0 ? null : () => Navigator.of(context).maybePop(),
                  child: Text(
                    n == 0
                        ? 'Pick at least one'
                        : 'Continue with $n reminder${n == 1 ? '' : 's'}',
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
