import 'package:flutter/foundation.dart';

import '../../reminders/domain/catalog.dart';
import '../domain/quiz.dart';

/// Accumulates the user's quiz answers and derives the resolved reminder set.
///
/// Deliberately tiny: a "yes" to a question adds its item keys, a "no" adds
/// nothing. The reveal and the finish step read [resolvedItems].
class OnboardingController extends ChangeNotifier {
  final Set<String> _keys = <String>{};

  /// Record a yes/no for a question. Yes adds its items; no is a no-op.
  void answer(QuizQuestion q, {required bool yes}) {
    if (yes) _keys.addAll(q.itemKeys);
    notifyListeners();
  }

  /// Resolved catalog items for everything answered "yes" so far.
  List<CatalogItem> get resolvedItems => _keys
      .map((k) => kCatalogByKey[k])
      .whereType<CatalogItem>()
      .toList();

  int get count => resolvedItems.length;
}
