import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_category.dart';

/// Persists the top-level categories (folders) the user creates. On-device,
/// simple JSON list — these are UI groupings, not reminder data.
class UserCategoryStore {
  const UserCategoryStore();

  static const _key = 'user_categories_v1';

  Future<List<UserCategory>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List)
        .map((e) => UserCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<void> add(UserCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await all();
    // De-dupe by key so re-creating the same name is idempotent.
    if (current.any((c) => c.key == category.key)) return;
    final next = [...current, category];
    await prefs.setString(
      _key,
      jsonEncode(next.map((c) => c.toJson()).toList()),
    );
  }
}
