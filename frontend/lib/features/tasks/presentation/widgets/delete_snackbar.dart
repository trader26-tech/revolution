import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';

/// Shows the small custom "Deleted · Undo" toast (never the default snackbar).
/// Shared by Home and Calendar so delete feedback is consistent.
///
/// [title] is the task name; [onUndo] restores it.
void showDeleteSnackBar(
  BuildContext context, {
  required String title,
  required VoidCallback onUndo,
}) {
  AppToast.show(
    context,
    message: 'Deleted “$title”',
    icon: Icons.delete_outline_rounded,
    iconColor: const Color(0xFFFF6B6B),
    actionLabel: 'Undo',
    onAction: onUndo,
    duration: const Duration(seconds: 2),
  );
}
