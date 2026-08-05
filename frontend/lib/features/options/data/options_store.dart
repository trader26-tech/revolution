import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The kinds of user-customisable option lists.
enum OptionKind { list, category, paymentMethod }

extension OptionKindInfo on OptionKind {
  /// The persistence key + a human title for the picker.
  String get storageKey => switch (this) {
        OptionKind.list => 'opt_lists',
        OptionKind.category => 'opt_categories',
        OptionKind.paymentMethod => 'opt_payment_methods',
      };

  String get title => switch (this) {
        OptionKind.list => 'List',
        OptionKind.category => 'Category',
        OptionKind.paymentMethod => 'Payment Method',
      };

  /// The built-in options that always appear first.
  List<String> get defaults => switch (this) {
        OptionKind.list => const ['Personal', 'Work', 'Family', 'Shared'],
        OptionKind.category => const [
            'Other',
            'Entertainment',
            'Utilities',
            'Insurance',
            'Finance',
            'Health',
            'Vehicle',
          ],
        OptionKind.paymentMethod => const [
            'None',
            'Credit Card',
            'Debit Card',
            'UPI',
            'Net Banking',
            'Cash',
          ],
      };
}

/// Holds the user-customisable option lists (List, Category, Payment Method):
/// built-in defaults plus anything the user adds, persisted on-device.
///
/// Persistence is deliberately isolated in [_load]/[_persist] so this can be
/// swapped for a DB-backed repository later without touching any UI. The public
/// API ([optionsFor], [add]) would stay identical.
class OptionsStore extends ChangeNotifier {
  OptionsStore({SharedPreferences? prefs}) : _prefs = prefs;

  /// App-wide instance. Initialised once in main() via [load]. Kept as a simple
  /// singleton so any screen can reach user options without prop-drilling; when
  /// this moves to a DB, only this class changes.
  static final OptionsStore instance = OptionsStore();

  SharedPreferences? _prefs;

  // Only the USER-ADDED values per kind (defaults are merged in on read).
  final Map<OptionKind, List<String>> _custom = {
    for (final k in OptionKind.values) k: <String>[],
  };

  /// Load persisted custom options. Call once at startup.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    for (final k in OptionKind.values) {
      _custom[k] = _prefs!.getStringList(k.storageKey) ?? <String>[];
    }
    notifyListeners();
  }

  /// The full option list for [kind]: built-in defaults first, then the user's
  /// own additions (de-duplicated, case-insensitively).
  List<String> optionsFor(OptionKind kind) {
    final seen = <String>{};
    final out = <String>[];
    for (final v in [...kind.defaults, ..._custom[kind]!]) {
      if (seen.add(v.toLowerCase())) out.add(v);
    }
    return out;
  }

  /// Whether [value] already exists for [kind] (default or custom).
  bool contains(OptionKind kind, String value) {
    final v = value.trim().toLowerCase();
    return optionsFor(kind).any((o) => o.toLowerCase() == v);
  }

  /// Add a user option under [kind] and persist it. Returns the stored value
  /// (trimmed). No-op if blank or already present.
  Future<String?> add(OptionKind kind, String value) async {
    final v = value.trim();
    if (v.isEmpty || contains(kind, v)) return v.isEmpty ? null : v;
    _custom[kind] = [..._custom[kind]!, v];
    await _persist(kind);
    notifyListeners();
    return v;
  }

  /// Remove a user-added option (defaults can't be removed).
  Future<void> remove(OptionKind kind, String value) async {
    if (kind.defaults.any((d) => d.toLowerCase() == value.toLowerCase())) {
      return; // never remove a built-in
    }
    _custom[kind] = _custom[kind]!
        .where((o) => o.toLowerCase() != value.toLowerCase())
        .toList();
    await _persist(kind);
    notifyListeners();
  }

  Future<void> _persist(OptionKind kind) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(kind.storageKey, _custom[kind]!);
  }
}
