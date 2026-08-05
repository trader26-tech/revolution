import 'package:flutter/material.dart';

/// The app palette — a warm, cozy cream-and-caramel world built around Bobo the
/// puppy. (Class name kept as [Bamboo] for stability across the codebase; the
/// values are the dog/cream theme, no more green.)
///
/// Warm cream "paper", soft caramel/tan accents, and a warm near-black ink for
/// text. Single source of colour truth so every screen feels like one place.
class Bamboo {
  const Bamboo._();

  // Backgrounds — warm cream "paper", never pure white.
  static const cream = Color(0xFFFFF8EE);
  static const creamHi = Color(0xFFFFFCF6);
  static const mist = Color(0xFFFBEFDD); // warm tan haze at the top

  // Caramel / tan — the brand core (formerly bamboo green). Named `green`,
  // `leaf`, `sprout` etc. only so existing references keep compiling.
  static const green = Color(0xFFE0A45C); // primary — warm caramel
  static const greenDeep = Color(0xFFC5843B); // deeper caramel
  static const leaf = Color(0xFFECC48E); // soft tan
  static const sprout = Color(0xFFF3D9B0); // pale tan

  // Accent for highlight numbers — rich toffee.
  static const cane = Color(0xFFB07A34);

  // Warm ink for text.
  static const ink = Color(0xFF3A2E22);
  static const inkSoft = Color(0xFF7A6A57);

  // Surfaces / cards.
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFEFE6D6);

  static const blush = Color(0xFFFF9CB6); // Bobo's cheeks, for tiny accents

  // Bobo's coat tones (shared with the mascot fallback painter).
  static const coat = Color(0xFFFFF3DE);
  static const brown = Color(0xFF8A5A2B);
}
