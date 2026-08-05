import 'package:flutter/material.dart';

import '../../../core/theme/bamboo_palette.dart';

/// A top-level category (folder) the user creates themselves — just a name.
/// The icon and colour are assigned automatically so it always looks finished.
///
/// The icon is stored as an INDEX into a fixed const [_icons] list — never a
/// raw codepoint — so every glyph is a compile-time `Icons.*` reference. That
/// keeps it tree-shake-safe and, crucially, means it renders on iOS (dynamic
/// `IconData(codepoint)` can be shaken out and show as an empty box there).
class UserCategory {
  const UserCategory({
    required this.key,
    required this.label,
    required this.iconIndex,
    required this.colorValue,
  });

  final String key;
  final String label;
  final int iconIndex;
  final int colorValue;

  IconData get icon => _icons[iconIndex.clamp(0, _icons.length - 1)];
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'iconIndex': iconIndex,
        'color': colorValue,
      };

  factory UserCategory.fromJson(Map<String, dynamic> j) => UserCategory(
        key: j['key'] as String,
        label: j['label'] as String,
        // Back-compat: older records stored a raw 'icon' codepoint; fall back
        // to the folder icon (index 0) for those.
        iconIndex: (j['iconIndex'] as num?)?.toInt() ?? 0,
        colorValue: (j['color'] as num).toInt(),
      );

  /// Builds a category from just a name — assigns a stable key and auto-picks
  /// an icon + colour so the folder looks distinct without asking the user.
  factory UserCategory.fromName(String rawName) {
    final name = rawName.trim();
    final key =
        'user_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final hash = name.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b);
    final color = _palette[hash % _palette.length];
    return UserCategory(
      key: key,
      label: name,
      iconIndex: _guessIconIndex(name),
      colorValue: color.toARGB32(),
    );
  }

  // The fixed icon set — all const `Icons.*`, so they survive tree-shaking and
  // render everywhere including iOS. Order is the on-disk contract; only append.
  static const List<IconData> _icons = [
    Icons.folder_outlined, // 0 · default
    Icons.directions_car_outlined, // 1 · vehicle
    Icons.badge_outlined, // 2 · documents
    Icons.account_balance_wallet_outlined, // 3 · money
    Icons.home_outlined, // 4 · home
    Icons.favorite_outline, // 5 · health
    Icons.family_restroom_outlined, // 6 · family
    Icons.subscriptions_outlined, // 7 · subscriptions
  ];

  // A calm spread of accent colours that sit well on cream.
  static const _palette = <Color>[
    Bamboo.green,
    Color(0xFF6C8AE4), // periwinkle
    Color(0xFFE07A5F), // terracotta
    Color(0xFF8B5CF6), // violet
    Color(0xFF0EA5E9), // sky
    Color(0xFFEC4899), // pink
    Color(0xFF10B981), // emerald
  ];

  /// Very light keyword → icon-index guess so common folders get a fitting glyph.
  static int _guessIconIndex(String name) {
    final n = name.toLowerCase();
    bool has(List<String> ks) => ks.any(n.contains);
    if (has(['car', 'vehicle', 'bike', 'insurance'])) return 1;
    if (has(['gov', 'document', 'id', 'licen', 'passport', 'aadhaar'])) return 2;
    if (has(['bill', 'pay', 'bank', 'loan', 'emi', 'money'])) return 3;
    if (has(['home', 'house', 'rent'])) return 4;
    if (has(['health', 'medic', 'doctor', 'hospital'])) return 5;
    if (has(['school', 'kid', 'child', 'family', 'birthday'])) return 6;
    if (has(['sub', 'stream', 'ott', 'app', 'software'])) return 7;
    return 0;
  }
}
