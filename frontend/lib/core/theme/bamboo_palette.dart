import 'package:flutter/material.dart';

/// The panda / bamboo palette — a calm, natural light world.
///
/// Warm cream paper, fresh bamboo greens, soft leaf accents, and a panda-ink
/// near-black for text. This is the single source of colour truth so every
/// screen feels like one place.
class Bamboo {
  const Bamboo._();

  // Backgrounds — warm cream "paper", never pure white.
  static const cream = Color(0xFFF7F4EC);
  static const creamHi = Color(0xFFFCFAF4);
  static const mist = Color(0xFFEFF3E8); // faint green haze at the top

  // Bamboo greens — the brand core.
  static const green = Color(0xFF3FA96A); // primary
  static const greenDeep = Color(0xFF2E7D4F);
  static const leaf = Color(0xFF7BC47F);
  static const sprout = Color(0xFFA9D8A0);

  // Warm bamboo-cane / accent for highlight numbers.
  static const cane = Color(0xFFC9A24B);

  // Panda ink for text.
  static const ink = Color(0xFF23261F);
  static const inkSoft = Color(0xFF5B6152);

  // Surfaces / cards.
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE6E3D8);

  static const blush = Color(0xFFFF9CB6); // Bobo's cheeks, for tiny accents
}
