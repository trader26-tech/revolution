import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A category the user can add from the home "+" flow. Each one opens its OWN
/// tailored form that asks for only the fields that category needs — a birthday
/// never asks for a price, a subscription never asks for a document number.
///
/// This is the single registry the picker renders from; adding a new category
/// later is one entry here plus its form. We start with the two most common:
/// Subscriptions and Birthdays.
enum AddCategory {
  subscription,
  birthday;

  /// Card title in the picker.
  String get label => switch (this) {
        AddCategory.subscription => 'Subscription',
        AddCategory.birthday => 'Birthday',
      };

  /// One-line hint under the title — what this category is for.
  String get blurb => switch (this) {
        AddCategory.subscription => 'Netflix, Prime, gym…',
        AddCategory.birthday => 'Never miss the people who matter',
      };

  IconData get icon => switch (this) {
        AddCategory.subscription => Icons.subscriptions_rounded,
        AddCategory.birthday => Icons.cake_rounded,
      };

  /// The category's accent — used across its card and its form so the whole
  /// path feels colour-coordinated. Both sit in the Orbit palette.
  Color get color => switch (this) {
        AddCategory.subscription => AppColors.accent,
        AddCategory.birthday => const Color(0xFFFF6FB5), // warm pink for people
      };

  /// The categories offered right now, in display order. More land here later
  /// (Insurance, Documents, Renewals…), each with its own form.
  static const List<AddCategory> available = [
    AddCategory.subscription,
    AddCategory.birthday,
  ];
}
