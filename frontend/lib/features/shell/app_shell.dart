import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../home/browse_page.dart';
import '../home/home_page.dart';
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

  /// COMMAND MODE — the bottom bar morphs between two states:
  ///   false → [Home·Browse nav | left] + [circular ★ button | right]
  ///   true  → [small dot-button | left] + [command text field | right]
  /// [_morph] (0→1) drives the whole transition + the space-colour aurora wash.
  bool _commandMode = false;
  late final AnimationController _morph;

  /// Drives the command chat (parse + reply) — lives on Home; the shell owns the
  /// input and forwards typed commands here.
  final _homeKey = GlobalKey<HomePageState>();

  // One shared task store so Home and Browse stay in sync.
  final _store = TaskStore();

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Restore saved tasks (and their icons) from on-device storage.
    _store.load();
    // Check for a newer app version on launch, and prompt (blocking if the
    // build is below the server's min-supported → mandatory update).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  void _openCommand() {
    setState(() => _commandMode = true);
    _morph.forward();
    // The ★ opens the natural-language command chat, ready to type — no menu.
    // (The chat already does full CRUD + queries: "change netflix to 799",
    // "what subscriptions this week", "delete gym".)
  }

  void _closeCommand() {
    setState(() => _commandMode = false);
    _morph.reverse();
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
          final t = Curves.easeOutCubic.transform(_morph.value);
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
                    commandBusy:
                        _homeKey.currentState?.hasChat ?? false,
                    onTab: (i) => setState(() {
                      _tab = i;
                      // Switching tab exits command mode back to the nav.
                      if (_commandMode) _closeCommand();
                    }),
                    onOpenCommand: _openCommand,
                    onCloseCommand: _closeCommand,
                    onSend: (text) => _homeKey.currentState?.sendCommand(text),
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

/// The morphing bottom bar. [t] (0→1) crossfades/slides between:
///   t=0 → the Home·Browse nav (left) + the circular ★ command button (right)
///   t=1 → a small dot-button (left, reopens the nav) + the command text field
/// The two halves swap width as [t] moves, so it reads as one fluid morph.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.t,
    required this.tab,
    required this.commandBusy,
    required this.onTab,
    required this.onOpenCommand,
    required this.onCloseCommand,
    required this.onSend,
  });

  final double t;
  final int tab;
  final bool commandBusy;
  final ValueChanged<int> onTab;
  final VoidCallback onOpenCommand;
  final VoidCallback onCloseCommand;
  final ValueChanged<String> onSend;

  static const _h = 60.0; // bar height
  static const _gap = 12.0; // gap between the two elements
  // Resting width of the nav pill so it HUGS the Home·Browse buttons instead of
  // stretching across the bar. Sized for the widest resting state (Home selected
  // → "Home" pill + a plain Browse icon) plus the pill's own side padding.
  static const _navNatural = 184.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final total = c.maxWidth;
          // NAV STATE (t=0): the left pill HUGS its Home·Browse buttons (natural
          // width, pinned left) with the ★ circle right beside it — the whole bar
          // stays compact on the left, not stretched across the full width.
          // COMMAND STATE (t=1): the field expands to fill, the nav shrinks to a
          // dot. We interpolate the LEFT width from its compact natural size to a
          // small dot, and derive the right as the exact remainder so nothing
          // overflows at any t.
          //
          // `_navNatural` is the pill's resting content width (2 buttons + its own
          // side padding). At t=0 the left pill is exactly that; as t→1 it
          // collapses to a dot (_h) and the right half takes everything else.
          final leftW = (_navNatural + (_h - _navNatural) * t)
              .clamp(_h, total - _gap - _h);
          final rightW = total - _gap - leftW; // exact remainder

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
                const SizedBox(width: _gap),
                SizedBox(
                  width: rightW,
                  child: _RightHalf(
                    t: t,
                    busy: commandBusy,
                    onOpenCommand: onOpenCommand,
                    onSend: onSend,
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

/// The RIGHT element: the circular ★ command button that expands into the
/// command field as [t] → 1. Crossfades the ★ glyph ⇄ the field contents inside
/// one growing liquid-glass container.
class _RightHalf extends StatelessWidget {
  const _RightHalf({
    required this.t,
    required this.busy,
    required this.onOpenCommand,
    required this.onSend,
  });
  final double t;
  final bool busy;
  final VoidCallback onOpenCommand;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    // ★ fades out fast; the field only mounts once there's room (t>0.55), so its
    // full-width Row never overflows the still-narrow container.
    final starOpacity = (1 - t / 0.35).clamp(0.0, 1.0);
    final fieldOpacity = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    return _LiquidGlass(
      accentFill: 1 - t, // 1 = solid accent circle, 0 = light glass field
      onTap: t < 0.5
          ? () {
              HapticFeedback.mediumImpact();
              onOpenCommand();
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (starOpacity > 0.01)
              Opacity(
                opacity: starOpacity,
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 25, color: Colors.white),
              ),
            if (fieldOpacity > 0.01)
              Positioned.fill(
                child: Opacity(
                  opacity: fieldOpacity,
                  child: _CommandField(busy: busy, onSend: onSend),
                ),
              ),
          ],
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

/// The command text field shown in command mode — sends on Enter.
class _CommandField extends StatefulWidget {
  const _CommandField({required this.busy, required this.onSend});
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  State<_CommandField> createState() => _CommandFieldState();
}

class _CommandFieldState extends State<_CommandField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Focus the field as it opens so the keyboard rises with the morph.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    // No own background — it sits INSIDE the shared liquid-glass surface.
    return Row(
      children: [
        const SizedBox(width: 16),
        Icon(Icons.auto_awesome_rounded,
            size: 20, color: AppColors.accent.withValues(alpha: 0.95)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onSubmitted: (_) => _send(),
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              hintText: 'Ask or add anything…',
              hintStyle: TextStyle(color: AppColors.inkFaint),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        _SendButton(busy: widget.busy, onTap: _send),
        const SizedBox(width: 6),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(7),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_upward_rounded,
            size: 20, color: Colors.white),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 44,
          padding:
              EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
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
                  size: 22,
                  color: selected ? AppColors.accent : AppColors.inkFaint,
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
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
