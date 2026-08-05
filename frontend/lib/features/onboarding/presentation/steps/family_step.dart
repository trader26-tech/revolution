import 'package:flutter/material.dart';

import '../../../../core/theme/bamboo_palette.dart';
import '../../../family/domain/family_member.dart';
import '../../../family/presentation/widgets/edit_member_sheet.dart';
import '../../../mascot/presentation/bobo_mascot.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// Onboarding beat: "Who's in your family?"
///
/// The head adds the people they look after so every renewal can be linked to
/// the right person. Fully skippable — you always land with at least yourself.
class FamilyStep extends StatelessWidget {
  const FamilyStep({
    super.key,
    required this.controller,
    required this.onContinue,
  });

  final OnboardingController controller;
  final VoidCallback onContinue;

  Future<void> _add(BuildContext context) async {
    final result = await showEditMemberSheet(context);
    if (result == null) return;
    controller.addFamilyMember(
      FamilyMemberDraft(name: result.name, relation: result.relation),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final drafts = controller.familyDrafts;
        final text = Theme.of(context).textTheme;

        return OnboardingScaffold(
          cta: drafts.isEmpty ? 'Skip for now' : 'Continue',
          onCta: onContinue,
          footnote: 'You can add or change these any time.',
          centerContent: false,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(child: BoboMascot(size: 120, mood: BoboMood.happy)),
              const SizedBox(height: 16),
              Text(
                "Who's in your family?",
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Bamboo.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add the people you look after — link each renewal to the right '
                'person later.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: Bamboo.inkSoft),
              ),
              const SizedBox(height: 24),
              // The head themselves — always present, not editable here.
              _MemberRow(
                initial: 'Y',
                name: 'You',
                relation: 'Head of family',
                color: Bamboo.greenDeep,
              ),
              for (var i = 0; i < drafts.length; i++)
                _MemberRow(
                  initial: drafts[i].name.isEmpty
                      ? '?'
                      : drafts[i].name[0].toUpperCase(),
                  name: drafts[i].name,
                  relation: drafts[i].relation,
                  color: _paletteColor(i),
                  onRemove: () => controller.removeFamilyMemberAt(i),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add a family member'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Bamboo.greenDeep,
                  side: const BorderSide(color: Bamboo.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _paletteColor(int i) {
    const palette = [
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ];
    return palette[i % palette.length];
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.initial,
    required this.name,
    required this.relation,
    required this.color,
    this.onRemove,
  });

  final String initial;
  final String name;
  final String relation;
  final Color color;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Bamboo.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Text(
              initial,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Bamboo.ink,
                  ),
                ),
                Text(
                  relation,
                  style: const TextStyle(color: Bamboo.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Bamboo.inkSoft,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
