import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shows a clean, WHITE "Deleted · Undo" snackbar that auto-dismisses after a
/// few seconds. Shared by Home and Calendar so delete feedback is consistent.
///
/// [title] is the task name; [onUndo] restores it.
void showDeleteSnackBar(
  BuildContext context, {
  required String title,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
  final controller = messenger.showSnackBar(
    SnackBar(
      // White card, dark text — not the default dark M3 snackbar.
      backgroundColor: AppColors.card,
      elevation: 6,
      // FIXED (not floating): floating snackbars can hang around and overlap the
      // add button. Fixed reliably auto-dismisses.
      behavior: SnackBarBehavior.fixed,
      // Auto-closes on its own so it can never get "stuck".
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          const Icon(Icons.delete_outline_rounded,
              size: 20, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Deleted “$title”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'Undo',
        textColor: AppColors.accentDeep,
        onPressed: onUndo,
      ),
    ),
  );

  // Hard guarantee it goes away: force-close after 3s regardless of behaviour,
  // so it can never get stuck on screen.
  Timer(const Duration(seconds: 3), () {
    controller.close();
  });
}
