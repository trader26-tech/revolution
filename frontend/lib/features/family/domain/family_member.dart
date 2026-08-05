import 'package:flutter/material.dart';

/// The relations offered in the picker. Free text is still allowed via "Other".
const List<String> kRelations = [
  'Self',
  'Spouse',
  'Son',
  'Daughter',
  'Father',
  'Mother',
  'Brother',
  'Sister',
  'Other',
];

/// A family member owned by the head-of-family account. Mirrors a row of the
/// backend `family_members` table.
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.isSelf,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final String relation;

  /// True for the head's own "You" record.
  final bool isSelf;
  final Map<String, dynamic> metadata;

  /// First initial for avatar chips.
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// A stable, pleasant colour derived from the member id so each member reads
  /// consistently across the app.
  Color get color {
    const palette = [
      Color(0xFF4F46E5),
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
    ];
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  /// Icon hint by relation, for a friendlier avatar when there's no photo.
  IconData get icon {
    switch (relation.toLowerCase()) {
      case 'self':
        return Icons.person;
      case 'spouse':
        return Icons.favorite;
      case 'son':
      case 'daughter':
        return Icons.child_care;
      case 'father':
      case 'mother':
        return Icons.elderly;
      default:
        return Icons.person_outline;
    }
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'] as String,
        name: json['name'] as String,
        relation: json['relation'] as String? ?? 'Self',
        isSelf: json['is_self'] as bool? ?? false,
        metadata:
            (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// Payload for creating/updating a member.
class FamilyMemberDraft {
  const FamilyMemberDraft({
    required this.name,
    required this.relation,
    this.isSelf = false,
  });

  final String name;
  final String relation;
  final bool isSelf;

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        if (isSelf) 'is_self': true,
      };
}
