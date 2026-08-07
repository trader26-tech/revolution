import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/starfield.dart';
import '../../domain/onboarding_category.dart';
import '../widgets/reminder_row.dart';
import '../widgets/reminder_confirm_sheet.dart';

/// The whole onboarding on ONE scrolling page.
///
/// Categories are shown as generic checkbox rows, grouped into light sections
/// (Subscriptions, Bills, Insurance, Money…). Common ones arrive ticked.
/// Ticking a row expands it in place to reveal compact detail fields — name,
/// day, frequency — so the user fills everything without leaving the page.
/// A single "Continue" at the bottom carries them to the phone-number step.
class OnboardingListScreen extends StatefulWidget {
  const OnboardingListScreen({
    super.key,
    required this.onContinue,
    this.onClose,
  });

  /// Fires with the picked drafts when the user taps Continue.
  final ValueChanged<Map<String, ReminderDraft>> onContinue;
  final VoidCallback? onClose;

  @override
  State<OnboardingListScreen> createState() => _OnboardingListScreenState();
}

class _OnboardingListScreenState extends State<OnboardingListScreen> {
  /// category.key → its staged draft. Presence == ticked.
  final Map<String, ReminderDraft> _drafts = {};

  @override
  void initState() {
    super.initState();
    for (final c in kOnboardingCategories) {
      if (c.preselected) {
        _drafts[c.key] = ReminderDraft(
          name: c.defaultName,
          day: c.defaultDay,
          frequency: c.defaultFrequency,
        );
      }
    }
  }

  void _toggle(OnboardingCategory c) {
    setState(() {
      if (_drafts.containsKey(c.key)) {
        _drafts.remove(c.key);
      } else {
        _drafts[c.key] = ReminderDraft(
          name: c.defaultName,
          day: c.defaultDay,
          frequency: c.defaultFrequency,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _drafts.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Starfield(
        // Dimmer behind a dense, scrolling list — present, never distracting.
        intensity: 0.7,
        child: SafeArea(
          child: Column(
            children: [
              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.inkSoft,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What do you\npay for?',
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "We've ticked the usual ones. Tick what's yours and "
                            "we'll fill in the rest — tweak anything inline.",
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final g in kOnboardingGroups) ...[
                      _SectionHeader(group: g),
                      const SizedBox(height: 10),
                      for (final c in g.categories)
                        ReminderRow(
                          category: c,
                          draft: _drafts[c.key],
                          onToggle: () => _toggle(c),
                          onChanged: (d) => setState(() => _drafts[c.key] = d),
                        ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
              // Bottom action.
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: n == 0
                        ? null
                        : () => widget.onContinue(Map.of(_drafts)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      n == 0
                          ? 'Pick at least one'
                          : 'Continue with $n reminders',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.group});
  final OnboardingGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Icon(group.icon, size: 18, color: group.color),
          const SizedBox(width: 8),
          Text(
            group.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
