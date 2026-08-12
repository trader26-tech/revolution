import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// A round accent button whose glyph plays a ONE-TIME morph from [from] into
/// [to] when it first appears — the shared "considered" motion used across the
/// Documents system (the add-document "+", the new-folder "+", the viewer's
/// share button…), so every action feels part of one consistent language.
///
/// A pure, tappable button: [onTap] fires on press; the morph is cosmetic.
class MorphIconButton extends StatefulWidget {
  const MorphIconButton({
    super.key,
    required this.from,
    required this.to,
    required this.onTap,
    this.tooltip,
    this.size = 46,
    this.delay = const Duration(milliseconds: 220),
  });

  final IconData from;
  final IconData to;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  /// A short beat before the morph, so the [from] glyph registers first.
  final Duration delay;

  @override
  State<MorphIconButton> createState() => _MorphIconButtonState();
}

class _MorphIconButtonState extends State<MorphIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: Container(
        width: s,
        height: s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentDeep],
          ),
          borderRadius: BorderRadius.circular(s / 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOutBack.transform(_c.value.clamp(0.0, 1.0));
            final outOpacity = (1 - (_c.value * 1.6)).clamp(0.0, 1.0);
            final inOpacity = ((_c.value - 0.4) / 0.6).clamp(0.0, 1.0);
            final glyph = s * 0.5;
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: outOpacity,
                  child: Transform.rotate(
                    angle: t * 0.9,
                    child: Transform.scale(
                      scale: 1 - 0.4 * t,
                      child: Icon(widget.from,
                          color: Colors.white, size: glyph),
                    ),
                  ),
                ),
                Opacity(
                  opacity: inOpacity,
                  child: Transform.rotate(
                    angle: (t - 1) * 0.9,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * t,
                      child: Icon(widget.to,
                          color: Colors.white, size: glyph * 0.96),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
