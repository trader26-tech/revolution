import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small, elegant toast — a floating pill near the bottom that fades + slides
/// in, lingers ~1.6s, then fades out. Used for ALL action feedback (add,
/// update, delete, saved…) so we never show the default black snackbar.
///
/// Optional [actionLabel] + [onAction] add a single inline action (e.g. Undo).
class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color? iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 1700),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);

    // Replace any toast already on screen so they never stack.
    _dismiss();

    final entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        icon: icon,
        iconColor: iconColor ?? AppColors.accent,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                onAction();
                _dismiss();
              },
        duration: duration,
        onFinished: _dismiss,
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.duration,
    required this.onFinished,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onFinished;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    // Hold, then fade out and remove.
    _hideTimer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      // Sit above the floating nav bar, centred.
      bottom: media.padding.bottom + 96,
      left: 24,
      right: 24,
      child: IgnorePointer(
        ignoring: widget.onAction == null,
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, widget.actionLabel != null ? 8 : 18, 12),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 18, color: widget.iconColor),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null) ...[
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: widget.onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
