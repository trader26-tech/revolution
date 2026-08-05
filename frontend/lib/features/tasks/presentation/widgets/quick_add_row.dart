import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The inline quick-add input row: a plain auto-focused text field. Adding +
/// closing are driven by the floating buttons above the keyboard (see
/// [QuickAddBar]) and by the keyboard's own submit action.
///
/// No leading circle — a bare tick on an empty input reads as a task you can
/// "check off", which is confusing. When [showHint] is true (the very first
/// add, nothing captured yet) a divider + short helper anchor the field; once
/// an item exists the row is just the field, for clean continuation.
class QuickAddRow extends StatelessWidget {
  const QuickAddRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitText,
    required this.onTapOutsideEmpty,
    this.showHint = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Called when the keyboard's "done" action fires.
  final VoidCallback onSubmitText;

  /// Called when the user taps outside while the field is empty.
  final VoidCallback onTapOutsideEmpty;

  /// Show the anchoring line + helper (first add only).
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    // Left inset lines the field text up with the task titles below (tile
    // padding 16 + circle 20 + gap 12 = 48), so the rows read as one column.
    final field = Padding(
      padding: const EdgeInsets.fromLTRB(48, 14, 16, 14),
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
    );

    if (!showHint) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        const Divider(
          height: 1,
          thickness: 1,
          indent: 48,
          endIndent: 16,
          color: AppColors.hairline,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(48, 8, 16, 10),
          child: Text(
            'Add as many as you like — details later.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The single floating action button, bottom-right.
///
/// It IS the add control: a **+** when idle, which morphs into a **✓** while
/// adding (same spot, animated icon swap). While adding, a small **✕** appears
/// just above it to finish. The caller positions this above the nav bar when
/// idle and above the keyboard while adding.
class QuickAddBar extends StatelessWidget {
  const QuickAddBar({
    super.key,
    required this.adding,
    required this.onStart,
    required this.onConfirm,
    required this.onClose,
  });

  /// Whether we're mid-add (button shows ✓ + the ✕ is visible).
  final bool adding;

  /// Idle tap on the + — begin adding.
  final VoidCallback onStart;

  /// Tap on the ✓ — add the current text and keep going.
  final VoidCallback onConfirm;

  /// Tap on the ✕ — finish adding.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20, bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The ✕ only exists while adding — it animates in/out above the FAB.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: adding
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RoundButton(
                      icon: Icons.close_rounded,
                      size: 44,
                      background: AppColors.card,
                      foreground: AppColors.inkSoft,
                      border: AppColors.cardBorder,
                      onTap: onClose,
                      tooltip: 'Close',
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // The morphing main button: + ↔ ✓, always accent, always same spot.
          _RoundButton(
            size: 58,
            accent: true,
            onTap: adding ? onConfirm : onStart,
            tooltip: adding ? 'Add task' : 'Add',
            iconWidget: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                adding ? Icons.check_rounded : Icons.add_rounded,
                key: ValueKey(adding),
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.onTap,
    required this.size,
    this.icon,
    this.iconWidget,
    this.accent = false,
    this.background,
    this.foreground,
    this.border,
    this.tooltip,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;

  /// An animated icon (e.g. an AnimatedSwitcher) used instead of a static [icon].
  final Widget? iconWidget;
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
        alignment: Alignment.center,
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
        child: iconWidget ??
            Icon(
              icon,
              size: size * 0.5,
              color: accent ? Colors.white : foreground,
            ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
