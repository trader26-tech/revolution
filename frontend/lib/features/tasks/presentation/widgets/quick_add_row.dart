import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The inline quick-add input row: a radio circle and an auto-focused text
/// field. Adding + closing are driven by the floating buttons above the
/// keyboard (see [QuickAddBar]) and by the keyboard's own submit action.
///
/// The controller + focus node are owned by the parent so the floating ✓ button
/// can read/clear the field.
class QuickAddRow extends StatelessWidget {
  const QuickAddRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitText,
    required this.onTapOutsideEmpty,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Called when the keyboard's "done" action fires.
  final VoidCallback onSubmitText;

  /// Called when the user taps outside while the field is empty.
  final VoidCallback onTapOutsideEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked,
              size: 22, color: AppColors.inkFaint),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmitText(),
              onTapOutside: (_) {
                if (controller.text.trim().isEmpty) onTapOutsideEmpty();
              },
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Add a task…',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.inkFaint),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating action bar that sits just above the keyboard while adding:
/// a small ✕ to close and a prominent accent ✓ to add the current task and
/// keep going. Positioned by the caller above [MediaQuery.viewInsets.bottom].
class QuickAddBar extends StatelessWidget {
  const QuickAddBar({
    super.key,
    required this.onConfirm,
    required this.onClose,
  });

  /// Add the current text and keep the field open for the next task.
  final VoidCallback onConfirm;

  /// Finish adding — dismiss the field and keyboard.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Small close (✕) button.
          _RoundButton(
            icon: Icons.close_rounded,
            size: 44,
            background: AppColors.card,
            foreground: AppColors.inkSoft,
            border: AppColors.cardBorder,
            onTap: onClose,
            tooltip: 'Close',
          ),
          const SizedBox(height: 12),
          // Prominent accent tick (✓) — add & continue.
          _RoundButton(
            icon: Icons.check_rounded,
            size: 56,
            accent: true,
            onTap: onConfirm,
            tooltip: 'Add task',
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.accent = false,
    this.background,
    this.foreground,
    this.border,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool accent;
  final Color? background;
  final Color? foreground;
  final Color? border;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: accent
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.accentDeep],
                )
              : null,
          color: accent ? null : background,
          border: border == null ? null : Border.all(color: border!),
          boxShadow: [
            BoxShadow(
              color: (accent ? AppColors.accent : Colors.black)
                  .withValues(alpha: accent ? 0.35 : 0.10),
              blurRadius: accent ? 16 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: accent ? Colors.white : foreground,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
