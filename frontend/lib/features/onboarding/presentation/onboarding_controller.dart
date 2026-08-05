import 'package:flutter/foundation.dart';

import '../../reminders/domain/catalog.dart';
import '../domain/quiz.dart';

/// Holds the checklist selection and derives the resolved reminder set.
///
/// The user ticks any number of rows on one screen; each ticked row contributes
/// its item keys. The reveal and the finish step read [resolvedItems]/[count].
class OnboardingController extends ChangeNotifier {
  final Set<String> _selected = <String>{};

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
