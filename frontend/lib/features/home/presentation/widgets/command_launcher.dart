import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import 'interactive_flow.dart';

/// The ★ LAUNCHER — the full-screen "What do you want to do today?" chooser that
/// rises when the ★ command button is pressed. It clears the screen behind a
/// blurred aurora scrim, greets the user, and offers the four root operations
/// (Create · Read · Update · Delete) as big, tappable cards.
///
/// It's purely a *chooser*: on pick it dismisses and hands the chosen [FlowOp]
/// back to the caller, which drops the user into that flow (Home's inline
/// assistant). Nothing here mutates state — it's the beautiful front door.
Future<FlowOp?> showCommandLauncher(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<FlowOp>(
    _LauncherRoute(),
  );
}

/// A transparent modal route with its own choreographed transition — a blurred
/// scrim that fades in, and content that springs up from the ★. Using a route
/// (not a dialog) gives us a real back-button/swipe dismiss for free.
class _LauncherRoute extends PopupRoute<FlowOp> {
  @override
  Color? get barrierColor => null; // we paint our own blurred scrim

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Command launcher';

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return _LauncherView(animation: animation);
  }
}

class _LauncherView extends StatelessWidget {
  const _LauncherView({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    // Two eased tracks off the same controller: a quick scrim fade, and a
    // spring-y content rise that lands a touch later for a layered feel.
    final scrim = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final rise = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack, // gentle overshoot → feels alive
      reverseCurve: Curves.easeInCubic,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final blur = 22.0 * scrim.value;
        return Stack(
          children: [
            // Blurred, dimmed backdrop — the screen behind is "cleared".
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.9),
                        radius: 1.3,
                        colors: [
                          AppColors.accent
                              .withValues(alpha: 0.22 * scrim.value),
                          AppColors.bg.withValues(alpha: 0.86 * scrim.value),
                        ],
                        stops: const [0.0, 0.9],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // The content: greeting + option cards, rising from below.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A small close affordance, top-right.
                    Align(
                      alignment: Alignment.topRight,
                      child: Opacity(
                        opacity: scrim.value,
                        child: _CloseButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: Offset(0, (1 - rise.value) * 40),
                      child: Opacity(
                        opacity: scrim.value,
                        child: _Greeting(t: t),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // The four operation cards, each staggered up on the rise.
                    for (var i = 0; i < FlowOp.values.length; i++)
                      _StaggeredCard(
                        index: i,
                        rise: rise.value,
                        child: _OptionCard(
                          op: FlowOp.values[i],
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop(FlowOp.values[i]);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The greeting headline + subtitle above the options.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B7CFF), AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 19, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Text(
              'Revo',
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: 0.9),
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'What do you want\nto do today?',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick an action — I’ll take it from there.',
          style: TextStyle(
            color: AppColors.inkSoft.withValues(alpha: 0.95),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Slides + fades each card up in sequence off the shared rise progress, so the
/// four options cascade rather than snapping in together.
class _StaggeredCard extends StatelessWidget {
  const _StaggeredCard({
    required this.index,
    required this.rise,
    required this.child,
  });
  final int index;
  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Each card starts a little after the previous one and finishes by rise=1.
    const step = 0.08;
    final start = index * step;
    final local = ((rise - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: eased,
        child: Transform.translate(
          offset: Offset(0, (1 - eased) * 28),
          child: child,
        ),
      ),
    );
  }
}

/// One big operation card — a tinted glyph tile, a title, a one-line hint, and a
/// chevron. Tapping picks that [FlowOp].
class _OptionCard extends StatefulWidget {
  const _OptionCard({required this.op, required this.onTap});
  final FlowOp op;
  final VoidCallback onTap;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final (String hint, Color tint) = switch (widget.op) {
      FlowOp.create => ('Add a new reminder or item', const Color(0xFF7C5CFC)),
      FlowOp.read => ('See what you have today', const Color(0xFF4EA8FF)),
      FlowOp.update => ('Change something you saved', const Color(0xFFFFB454)),
      FlowOp.delete => ('Remove an item', const Color(0xFFFF6B6B)),
    };
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Tinted glyph tile.
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tint.withValues(alpha: 0.9),
                          tint.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(widget.op.icon, size: 23, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.op.label,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: TextStyle(
                            color: AppColors.inkSoft.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small circular close (×) at the top-right of the launcher.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(Icons.close_rounded,
            size: 20, color: AppColors.inkSoft),
      ),
    );
  }
}
