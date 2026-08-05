import 'package:flutter/foundation.dart';

import '../../reminders/domain/catalog.dart';
import '../domain/personas.dart';

/// Holds the user's onboarding choices and derives the resolved reminder set.
///
/// Deliberately tiny — two selections in, a list of catalog items out. The
/// reveal and the "finish" step both read from here.
class OnboardingController extends ChangeNotifier {
  Persona? _primary;
  Persona? _addon;

  Persona? get primary => _primary;
  Persona? get addon => _addon;

  bool get hasPrimary => _primary != null;

  void selectPrimary(Persona p) {
    _primary = p;
    notifyListeners();
  }

  /// Tapping the selected add-on again clears it (it's optional).
  void toggleAddon(Persona p) {
    _addon = (_addon?.key == p.key) ? null : p;
    notifyListeners();
  }

  /// Resolved, de-duplicated catalog items for the current selection.
  List<CatalogItem> get resolvedItems {
    final primary = _primary;
    if (primary == null) return const [];
    return resolveItemKeys(primary: primary, addon: _addon)
        .map((k) => kCatalogByKey[k])
        .whereType<CatalogItem>()
        .toList();
  }
}
