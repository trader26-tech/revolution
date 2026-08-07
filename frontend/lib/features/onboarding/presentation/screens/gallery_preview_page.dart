import 'package:flutter/material.dart';

import 'onboarding_wizard.dart';

/// Dev entry point for the grouped onboarding wizard — opened from the home
/// screen's ✨ button so the whole flow can be tested on device.
class GalleryPreviewPage extends StatelessWidget {
  const GalleryPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingWizard(
      onClose: () => Navigator.of(context).maybePop(),
      onComplete: (drafts) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${drafts.length} reminders 🎉')),
        );
      },
    );
  }
}
