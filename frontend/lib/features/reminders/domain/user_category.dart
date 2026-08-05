import 'package:flutter/material.dart';

import '../../../core/theme/bamboo_palette.dart';

/// A top-level category (folder) the user creates themselves — just a name.
/// The icon and colour are assigned automatically so it always looks finished.
class UserCategory {
  const UserCategory({
    required this.key,
    required this.label,
    required this.iconCodePoint,
    required this.colorValue,
  });

  final String key;
  final String label;
  final int iconCodePoint;
  final int colorValue;

  IconData get icon =>
      IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'icon': iconCodePoint,
        'color': colorValue,
      };

  factory UserCategory.fromJson(Map<String, dynamic> j) => UserCategory(
        key: j['key'] as String,
        label: j['label'] as String,
        iconCodePoint: (j['icon'] as num).toInt(),
        colorValue: (j['color'] as num).toInt(),
      );

  /// Builds a category from just a name — assigns a stable key and auto-picks
  /// an icon + colour so the folder looks distinct without asking the user.
  factory UserCategory.fromName(String rawName) {
    final name = rawName.trim();
    final key = 'user_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final hash = name.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b);
    final color = _palette[hash % _palette.length];
    final icon = _guessIcon(name);
    return UserCategory(
      key: key,
      label: name,
      iconCodePoint: icon.codePoint,
      colorValue: color.toARGB32(),
    );
  }

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

  /// Very light keyword → icon guess so common folders get a fitting glyph.
  static IconData _guessIcon(String name) {
    final n = name.toLowerCase();
    bool has(List<String> ks) => ks.any(n.contains);
    if (has(['car', 'vehicle', 'bike', 'insurance'])) {
      return Icons.directions_car_outlined;
    }
    if (has(['gov', 'document', 'id', 'licen', 'passport', 'aadhaar'])) {
      return Icons.badge_outlined;
    }
    if (has(['bill', 'pay', 'bank', 'loan', 'emi', 'money'])) {
      return Icons.account_balance_wallet_outlined;
    }
    if (has(['home', 'house', 'rent'])) return Icons.home_outlined;
    if (has(['health', 'medic', 'doctor', 'hospital'])) {
      return Icons.favorite_outline;
    }
    if (has(['school', 'kid', 'child', 'family', 'birthday'])) {
      return Icons.family_restroom_outlined;
    }
    if (has(['sub', 'stream', 'ott', 'app', 'software'])) {
      return Icons.subscriptions_outlined;
    }
    return Icons.folder_outlined;
  }
}
