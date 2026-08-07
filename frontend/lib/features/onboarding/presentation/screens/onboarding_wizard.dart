import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/onboarding_category.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/reminder_confirm_sheet.dart';
import 'group_step_screen.dart';
import 'reminder_detail_screen.dart';
import 'onboarding_login_step.dart';

/// The full grouped onboarding wizard.
///
/// Flow (with a progress bar advancing across the top the whole way):
///   1..N  One step per [OnboardingGroup] — pick which reminders you have.
///   N+1   A quick review of everything picked (tap any to fine-tune the
///         name/day/frequency on its own screen).
///   N+2   A smooth phone/WhatsApp login to save it all to your account.
///
/// [onComplete] fires with the final drafts once login succeeds.
class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key, this.onComplete, this.onClose});

  final ValueChanged<Map<String, ReminderDraft>>? onComplete;
  final VoidCallback? onClose;

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final _pager = PageController();

  /// category.key → its staged draft. Presence == selected. Shared across steps.
  final Map<String, ReminderDraft> _drafts = {};

  int _page = 0;

  /// Total steps = one per group + review + login.
  int get _totalSteps => kOnboardingGroups.length + 2;
  int get _reviewIndex => kOnboardingGroups.length;
  int get _loginIndex => kOnboardingGroups.length + 1;

  @override
  void initState() {
    super.initState();
    // Pre-tick the near-universal categories with their smart defaults.
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

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pager.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < _totalSteps - 1) _goTo(_page + 1);
  }

  void _back() {
    if (_page == 0) {
      widget.onClose?.call();
    } else {
      HapticFeedback.selectionClick();
      _goTo(_page - 1);
    }
  }

  /// Accent for the current step (the group's colour, or the app accent on the
  /// review/login steps).
  Color get _accent => _page < kOnboardingGroups.length
      ? kOnboardingGroups[_page].color
      : AppColors.accent;

  List<OnboardingCategory> get _selected => kOnboardingCategories
      .where((c) => _drafts.containsKey(c.key))
      .toList();

  Future<void> _editReminder(OnboardingCategory c) async {
    final selected = _selected;
    final idx = selected.indexOf(c);
    final edited = await Navigator.of(context).push<ReminderDraft>(
      MaterialPageRoute(
        builder: (_) => ReminderDetailScreen(
          category: c,
          draft: _drafts[c.key]!,
          index: idx,
          total: selected.length,
          onNext: (d) => Navigator.of(context).pop(d),
        ),
      ),
    );
    if (edited != null) setState(() => _drafts[c.key] = edited);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back + progress bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: Icon(
                      _page == 0
                          ? Icons.close_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      size: _page == 0 ? 24 : 18,
                    ),
                    color: AppColors.inkSoft,
                  ),
                  Expanded(
                    child: OnboardingProgressBar(
                      step: _page,
                      total: _totalSteps,
                      accent: _accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  for (final g in kOnboardingGroups)
                    GroupStepScreen(
                      group: g,
                      drafts: _drafts,
                      onChanged: () => setState(() {}),
                    ),
                  _ReviewStep(
                    selected: _selected,
                    drafts: _drafts,
                    onEdit: _editReminder,
                  ),
                  OnboardingLoginStep(
                    count: _drafts.length,
                    onDone: () => widget.onComplete?.call(_drafts),
                  ),
                ],
              ),
            ),
            // Bottom action (hidden on the login step — it has its own).
            if (_page != _loginIndex) _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final onReview = _page == _reviewIndex;
    final label = onReview ? 'Looks good — continue' : 'Continue';
    final enabled = !onReview || _drafts.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: enabled ? _next : null,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (!onReview)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton(
                onPressed: _next,
                child: Text(
                  'Skip — none of these',
                  style: TextStyle(
                    color: AppColors.inkFaint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The review step: a tidy list of everything picked, grouped by section, each
/// row tappable to fine-tune its details.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.selected,
    required this.drafts,
    required this.onEdit,
  });

  final List<OnboardingCategory> selected;
  final Map<String, ReminderDraft> drafts;
  final ValueChanged<OnboardingCategory> onEdit;

  @override
  Widget build(BuildContext context) {
    if (selected.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "Nothing picked yet — go back and tap the ones you pay for.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 16),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Text(
          "Here's your list",
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${selected.length} reminders ready. Tap any to fine-tune the date or name.',
          style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),
        for (final c in selected) _ReviewRow(category: c, draft: drafts[c.key]!, onTap: () => onEdit(c)),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.category,
    required this.draft,
    required this.onTap,
  });

  final OnboardingCategory category;
  final ReminderDraft draft;
  final VoidCallback onTap;

  String get _dayOrdinal {
    final d = draft.day;
    if (d >= 11 && d <= 13) return '${d}th';
    switch (d % 10) {
      case 1:
        return '${d}st';
      case 2:
        return '${d}nd';
      case 3:
        return '${d}rd';
      default:
        return '${d}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(c.icon, color: c.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_dayOrdinal · ${draft.frequency.label}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
