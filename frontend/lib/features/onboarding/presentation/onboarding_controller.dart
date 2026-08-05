import 'package:flutter/foundation.dart';

import '../../family/domain/family_member.dart';
import '../../reminders/domain/catalog.dart';
import '../domain/quiz.dart';

/// Holds the checklist selection and derives the resolved reminder set.
///
/// The user ticks any number of rows on one screen; each ticked row contributes
/// its item keys. The reveal and the finish step read [resolvedItems]/[count].
///
/// It also collects the family members the head adds during onboarding, saved
/// on finish so the whole family → members → reminders chain is set up day one.
class OnboardingController extends ChangeNotifier {
  final Set<String> _selected = <String>{};

  // Extra family members added during onboarding (the head's own "You" record
  // is created by the backend, so it's not in this list).
  final List<FamilyMemberDraft> _familyDrafts = [];

  List<FamilyMemberDraft> get familyDrafts => List.unmodifiable(_familyDrafts);

  void addFamilyMember(FamilyMemberDraft draft) {
    _familyDrafts.add(draft);
    notifyListeners();
  }

  void removeFamilyMemberAt(int index) {
    if (index >= 0 && index < _familyDrafts.length) {
      _familyDrafts.removeAt(index);
      notifyListeners();
    }
  }

  bool isSelected(QuizQuestion q) => _selected.contains(q.key);

  bool get hasAny => _selected.isNotEmpty;

  void toggle(QuizQuestion q) {
    if (!_selected.add(q.key)) _selected.remove(q.key);
    notifyListeners();
  }

  /// De-duplicated catalog items across every ticked row.
  List<CatalogItem> get resolvedItems {
    final keys = <String>{};
    for (final q in kQuiz) {
      if (_selected.contains(q.key)) keys.addAll(q.itemKeys);
    }
    return keys
        .map((k) => kCatalogByKey[k])
        .whereType<CatalogItem>()
        .toList();
  }

  int get count => resolvedItems.length;
}
