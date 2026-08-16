import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../home/browse_page.dart';
import '../home/home_page.dart';
import '../home/presentation/command_chat_page.dart' show openCommandChat;
import '../home/presentation/widgets/command_chat_controller.dart';
import '../tasks/data/task_store.dart';
import '../update/data/update_service.dart';
import '../update/presentation/update_prompt.dart';

/// The app shell: two tabs behind a floating glass nav — Home (today's bubbles)
/// and Browse (the launcher to every category's collection + Documents).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.verified = true, this.onVerify});

  /// Whether the session is phone-verified. Kept for the auth gate's API even
  /// when the verify banner isn't currently rendered.
  final bool verified;

  /// Starts phone verification (opens the OTP flow). Null hides any prompt.
  final VoidCallback? onVerify;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _tab = 0;

  /// [_morph] used to drive an in-bar nav⇄command-field morph. The ★ now opens a
  /// full-screen chat page instead, so the bar stays in its nav+★ resting state
  /// (t=0); the controller is retained (kept at rest) to avoid churning the
  /// bottom-bar widget tree, and can be reclaimed if an in-bar morph returns.
  late final AnimationController _morph;

  /// Home's state handle (kept for the auth/verify plumbing + any future
  /// shell→Home calls).
  final _homeKey = GlobalKey<HomePageState>();

  // One shared task store so Home and Browse stay in sync.
  final _store = TaskStore();

  /// The command-chat engine — OWNED here so the conversation persists across
  /// opening/closing the full-screen chat (reopening ★ resumes where you left
  /// off). Created once with the shared store.
  late final CommandChatController _chat;

  /// Whether the full-screen [CommandChatPage] is currently pushed — so tapping a
  /// nav tab can pop it.
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      // Matches the chat page's entrance (560/300ms) so the home bar's morph and
      // the page's fade-in read as one continuous motion.
      duration: const Duration(milliseconds: 560),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _chat = CommandChatController(_store);
    // Restore saved tasks (and their icons) from on-device storage.
    _store.load();
    // Check for a newer app version on launch, and prompt (blocking if the
    // build is below the server's min-supported → mandatory update).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  /// The ★ opens the full-screen "What do you want to do today?" launcher — a
  /// beautiful full-screen chat: the greeting "What do you want to do today?"
  /// with the Create/Read/Update/Delete options + a free-text field, and the
  /// whole conversation continues IN that page (picking Create does NOT bounce
  /// back here). The controller is shell-owned, so reopening resumes the thread.
  Future<void> _openCommand() async {
    if (_chatOpen) return;
    _chatOpen = true;
    // Morph the home bar IN PLACE as the chat opens — the Home·Browse pill
    // shrinks to a button (dot) and the ★ widens — so as the page fades in over
    // it, the bottom bar reads as one continuous motion into the page's field.
    _morph.forward();
    await openCommandChat(context, _chat);
    // Route popped (home dot, or a nav-tab tap called maybePop).
    if (mounted) {
      _chatOpen = false;
      _morph.reverse();
    }
  }

  /// Pop the full-screen chat if it's open — used when a nav tab is tapped so
  /// switching to Home/Browse closes the chat.
  void _closeCommand() {
    if (_chatOpen) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      _chatOpen = false;
      _morph.reverse();
    }
  }

  /// Ask the backend if a newer build exists. When one does, show the update
  /// prompt — dismissible for an optional update, non-dismissible (blocking)
  /// when it's forced, so every device converges on the latest version. Fails
  /// silently offline; it re-checks on the next launch.
  Future<void> _checkForUpdate() async {
    final info = await UpdateService.instance.check();
    if (!mounted || !info.available) return;
    await showUpdatePrompt(context, info);
  }

  @override
  void dispose() {
    _morph.dispose();
    _chat.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      // isActive == "this page is the visible tab" — drives each page's entrance
      // replay. Command mode is an OVERLAY on Home, so Home stays active.
      HomePage(key: _homeKey, store: _store, isActive: _tab == 0),
      BrowsePage(store: _store, isActive: _tab == 1),
    ];

    return Scaffold(
      extendBody: true, // let the background flow under the floating bar
      body: AnimatedBuilder(
        animation: _morph,
        builder: (context, _) {
          // easeOutExpo: responds instantly to the tap then glides to a smooth
          // stop — reads faster and less "laggy" than easeOutCubic at this speed.
          final t = Curves.easeOutExpo.transform(_morph.value);
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.bgTop, AppColors.bg],
                  ),
                ),
                child: IndexedStack(index: _tab, children: pages),
              ),

              // The space-colour AURORA WASH — blooms once as command mode opens,
              // then settles to a quiet ambient glow around the edges.
              if (_morph.value > 0.001)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _AuroraWash(t: t),
                  ),
                ),

              // The morphing bottom bar: nav+★  ⇄  dot+command-field.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _BottomBar(
                    t: t,
                    tab: _tab,
                    onTab: (i) {
                      // Tapping a nav tab closes the full-screen chat (if open)
                      // and switches to that tab.
                      _closeCommand();
                      setState(() => _tab = i);
                    },
                    onOpenCommand: _openCommand,
                    onCloseCommand: _closeCommand,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The soft space-colour aurora that washes around the screen edges when command
/// mode opens — a violet→indigo glow that blooms in, then settles quiet. Never
/// fights the text; it just signals "the command chat is here". [t] is 0→1.
class _AuroraWash extends StatelessWidget {
  const _AuroraWash({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    // Bloom brighter mid-open, then settle to a calm resting glow.
    final settle = 0.5 + 0.5 * t; // 0.5→1 as it settles in
    final bloom = (t < 0.6 ? t / 0.6 : 1.0);
    final edge = (0.10 + 0.14 * bloom) * settle;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, 1.15), // just below the input
          radius: 1.3,
          colors: [
            AppColors.accent.withValues(alpha: edge * 1.4),
            const Color(0xFF3A2A8C).withValues(alpha: edge),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

/// The morphing bottom bar. [t] (0→1) slides between:
///   t=0 → the Home·Browse nav (left) + the circular ★ command button (right)
///   t=1 → a small dot-button (left) + the widened ★ (right), played as the
///         full-screen chat page rises over the bar.
/// The two halves swap width as [t] moves, so it reads as one fluid morph.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.t,
    required this.tab,
    required this.onTab,
    required this.onOpenCommand,
    required this.onCloseCommand,
  });

  final double t;
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onOpenCommand;
  final VoidCallback onCloseCommand;

  static const _h = 60.0; // bar height
  static const _gap = 12.0; // gap between the two elements
  // Resting width of the nav pill so it HUGS the Home·Browse buttons instead of
  // stretching across the bar. Sized for the widest resting state (Home selected
  // → "Home" pill + a plain Browse icon) plus the pill's own side padding.
  // Bumped from 184 to fit the larger selected pill (52px tall, 20px pad,
  // 24px icon, 15.5 label) without the FittedBox scaling it down.
  static const _navNatural = 200.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final total = c.maxWidth;
          // NAV STATE (t=0): a compact cluster pinned LEFT — the nav pill HUGS its
          // Home·Browse buttons and the ★ sits right beside it as a clean CIRCLE
          // (width == height). The rest of the bar is empty.
          // COMMAND STATE (t=1): the ★ grows into the full-width command field and
          // the nav collapses to a dot. We interpolate both widths from their
          // compact resting sizes to their expanded sizes; the exact remainder
          // becomes a trailing spacer so nothing overflows at any t.
          //
          // Left: natural pill width (t=0) → dot (t=1).
          final leftW = (_navNatural + (_h - _navNatural) * t)
              .clamp(_h, total - _gap - _h);
          // Right: a circle (_h, t=0) → everything left over (t=1).
          final rightMax = total - _gap - leftW; // fills the remainder when open
          final rightW = (_h + (rightMax - _h) * t).clamp(_h, rightMax);
          // Whatever's unused sits as an empty spacer BETWEEN the pill and the ★,
          // so the nav pill hugs the LEFT while the ★ stays pinned to the far
          // RIGHT edge. As command mode opens the spacer shrinks to zero and the
          // ★ grows leftward into the full-width field.
          final middle = (total - leftW - _gap - rightW).clamp(0.0, total);

          return SizedBox(
            height: _h,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                SizedBox(
                  width: leftW,
                  child: _NavHalf(
                    collapsed: t,
                    index: tab,
                    onReopen: onCloseCommand,
                    onChanged: onTab,
                  ),
                ),
                // Flexible gap: keeps the ★ at the far right in nav state, then
                // collapses (through the fixed _gap) as the field expands.
                SizedBox(width: _gap + middle),
                SizedBox(
                  width: rightW,
                  child: _RightHalf(
                    t: t,
                    onOpenCommand: onOpenCommand,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The LEFT element: the light "liquid glass" nav pill (Home · Browse), which
/// shrinks into a round grid button as [collapsed] → 1. The container width is
/// driven by the parent; here we just crossfade the pill contents ⇄ the dot
/// glyph. In command mode the whole thing is tappable to reopen the nav.
class _NavHalf extends StatelessWidget {
  const _NavHalf({
    required this.collapsed,
    required this.index,
    required this.onReopen,
    required this.onChanged,
  });
  final double collapsed;
  final int index;
  final VoidCallback onReopen;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Fade the nav contents out QUICKLY (done by t=0.35) so they never linger to
    // overflow as the pill narrows; the dot fades in after.
    final navOpacity = (1 - collapsed / 0.35).clamp(0.0, 1.0);
    final dotOpacity = ((collapsed - 0.55) / 0.45).clamp(0.0, 1.0);
    return _LiquidGlass(
      onTap: collapsed > 0.5 ? onReopen : null,
      // Clip so nothing spills outside the pill while it's shrinking.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The pill's Home·Browse row — hugged to the LEFT with a little inset,
            // min-width buttons, kept from overflowing by a FittedBox scaleDown
            // while the pill is mid-shrink.
            if (navOpacity > 0.01)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Opacity(
                    opacity: navOpacity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 2; i++)
                            _NavButton(
                              item: _kNavItems[i],
                              selected: i == index,
                              onTap: () => onChanged(i),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (dotOpacity > 0.01)
              Opacity(
                opacity: dotOpacity,
                child: const Icon(Icons.grid_view_rounded,
                    size: 22, color: AppColors.inkSoft),
              ),
          ],
        ),
      ),
    );
  }
}

/// The RIGHT element: the circular ★ command button. As [t] → 1 (the chat is
/// opening) it WIDENS into a pill and its glyph slides toward the leading edge —
/// the old "opening" motion — but it no longer mounts an in-bar text field (the
/// ★ opens the full-screen chat page instead). The morph just plays behind the
/// rising page during its entrance transition.
class _RightHalf extends StatelessWidget {
  const _RightHalf({
    required this.t,
    required this.onOpenCommand,
  });
  final double t;
  final VoidCallback onOpenCommand;

  @override
  Widget build(BuildContext context) {
    return _LiquidGlass(
      accentFill: 1 - 0.35 * t, // stay mostly accent — it's a button, not a field
      onTap: t < 0.5
          ? () {
              HapticFeedback.mediumImpact();
              onOpenCommand();
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        // As the pill widens, keep the ★ glyph near the leading edge so the
        // motion reads as "the button is stretching open".
        child: Align(
          alignment: Alignment.lerp(
            Alignment.center,
            const Alignment(-0.82, 0),
            t,
          )!,
          child: const Icon(Icons.auto_awesome_rounded,
              size: 25, color: Colors.white),
        ),
      ),
    );
  }
}

/// The shared "liquid glass" surface — a soft, bright frosted pill/circle with a
/// subtle top highlight and a gentle shadow, matching the iOS look. [accentFill]
/// (0→1) tints it from light glass toward a solid accent circle (for the ★).
class _LiquidGlass extends StatelessWidget {
  const _LiquidGlass({
    required this.child,
    this.onTap,
    this.accentFill = 0,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double accentFill;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 60,
      decoration: BoxDecoration(
        // Light frosted glass, blending to a solid accent as accentFill→1.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(Colors.white.withValues(alpha: 0.14),
                const Color(0xFF9B7CFF), accentFill)!,
            Color.lerp(Colors.white.withValues(alpha: 0.06),
                AppColors.accent, accentFill)!,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Color.lerp(Colors.white.withValues(alpha: 0.22),
              Colors.transparent, accentFill)!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(Colors.black.withValues(alpha: 0.28),
                AppColors.accent.withValues(alpha: 0.5), accentFill)!,
            blurRadius: 20,
            spreadRadius: accentFill,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: GlassPanel(
        borderRadius: 30,
        child: onTap == null
            ? content
            : GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: content,
              ),
      ),
    );
  }
}

/// The two nav destinations, shared by [_NavHalf].
const _kNavItems = <({IconData icon, IconData active, String label})>[
  (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
  (
    icon: Icons.grid_view_outlined,
    active: Icons.grid_view_rounded,
    label: 'Browse',
  ),
];

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData active, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The reference look: ONLY the selected item expands into a bright white
    // pill with the icon + label side by side (accent-coloured). Every
    // unselected item is a quiet icon ALONE — no label, no background — so the
    // selection reads as a single sliding pill among plain glyphs.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // vertical 4 so the taller 52px pill clears the 60px bar cleanly
        // (52 + 8 = 60) without the FittedBox having to scale it down.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 52,
          padding:
              EdgeInsets.symmetric(horizontal: selected ? 20 : 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          // AnimatedSize lets the pill grow/shrink smoothly as the label
          // appears/disappears when selection moves between items.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.active : item.icon,
                  size: 24,
                  color: selected ? AppColors.accent : AppColors.inkFaint,
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
