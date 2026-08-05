import 'package:flutter/material.dart';

import '../../domain/family_member.dart';

/// A round, colour-coded avatar for a family member — initial + relation icon.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 44,
    this.selected = false,
  });

  final FamilyMember member;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = member.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: selected ? Border.all(color: color, width: 2.5) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        member.initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
