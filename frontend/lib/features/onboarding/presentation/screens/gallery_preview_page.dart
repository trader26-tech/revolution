import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'onboarding_list_screen.dart';
import 'onboarding_login_step.dart';

/// The checklist + phone tail of onboarding. The life-categories chip page
/// lives in the main OnboardingFlow (page 2), so this starts at the bills
/// list. Opened from the home ✨ button for testing.
class GalleryPreviewPage extends StatelessWidget {
  const GalleryPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingListScreen(
      onClose: () => Navigator.of(context).maybePop(),
      onContinue: (drafts) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _PhoneStep(count: drafts.length)),
      ),
    );
  }
}

/// Wraps the login step in its own scaffold for the phone-number screen.
class _PhoneStep extends StatelessWidget {
  const _PhoneStep({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: const BackButton(color: AppColors.inkSoft),
      ),
      body: SafeArea(
        child: OnboardingLoginStep(
          count: count,
          onDone: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved $count reminders 🎉')),
            );
          },
        ),
      ),
    );
  }
}
