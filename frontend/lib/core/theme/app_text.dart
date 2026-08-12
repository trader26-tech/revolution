import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The app's ONE type scale — a small, consistent set of text styles so every
/// screen speaks the same language. Compact but readable: use these instead of
/// hardcoding `fontSize` per widget, so a "name" always looks like a name and a
/// "meta" always looks like a meta, everywhere.
///
/// Sizes (Plus Jakarta Sans, tightened tracking on the big ones):
///   display  26  — hero numbers (a big count / amount)
///   headline 20  — screen titles ("Documents", "Settings")
///   title    16  — section headers, card titles
///   body     14  — primary row text (a task/folder/document NAME)
///   label    12  — secondary text (a row's meta / subtitle)
///   caption  11  — the smallest text (badges, timestamps, kickers)
class AppText {
  const AppText._();

  static const display = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.05,
    color: AppColors.ink,
  );

  static const headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.1,
    color: AppColors.ink,
  );

  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
    color: AppColors.ink,
  );

  /// Primary row text — a NAME. The one everything's built around.
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.25,
    color: AppColors.ink,
  );

  /// Same size as [body] but regular weight — for sentences / values.
  static const bodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.3,
    color: AppColors.ink,
  );

  /// Secondary text — a row's META / subtitle.
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
    color: AppColors.inkSoft,
  );

  /// The smallest text — badges, kickers, timestamps.
  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
    color: AppColors.inkFaint,
  );
}
