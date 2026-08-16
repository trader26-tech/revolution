import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../documents/data/documents_store.dart';
import '../documents/presentation/documents_page.dart';
import '../home/browse_page.dart';
import '../home/home_page.dart';
import '../home/presentation/command_chat_launcher.dart';
import '../home/presentation/command_chat_page.dart' show CommandChatOverlay;
import '../home/presentation/widgets/command_chat_controller.dart';
import '../reminders/data/reminder_scheduler.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart' show TaskCategory;
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

  /// [_morph] (0→1) drives the ONE bottom bar's morph AND the chat overlay's
  /// entrance, so they move as a single fluid motion: the Home·Browse pill shrinks
  /// to a home dot on the left, the ★ widens into the text field on the right, and
  /// the chat content (Revo + greeting + thread) fades/rises in above the bar.
  late final AnimationController _morph;

  /// Home's state handle (kept for the auth/verify plumbing + any future
  /// shell→Home calls).
  final _homeKey = GlobalKey<HomePageState>();

  // One shared task store so Home and Browse stay in sync.
  final _store = TaskStore();

  /// The Documents library store — OWNED by the shell now that Documents is a
  /// top-level tab (it used to live inside Browse). Held here so its loaded state
  /// and folder tree persist across tab switches, and load once on first build.
  final _documents = DocumentsStore();

  /// The command-chat engine — OWNED here so the conversation persists across
  /// opening/closing the full-screen chat (reopening ★ resumes where you left
  /// off). Created once with the shared store.
  late final CommandChatController _chat;

  /// The ★ field's text controller — OWNED here so the chat overlay's quick-search
  /// palette can read the live query as the user types (the field lives in the
  /// bottom bar; the palette lives in the overlay).
  final _searchController = TextEditingController();

  /// Whether the chat overlay is open — the morph target. Drives the bar morph +
  /// the overlay entrance, and gates system-back handling.
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      // Snappy + smooth: quick to snap open, quicker to close. The keyboard is
      // held back until this finishes (see _RightHalf), so the search UI lands
      // first and the keyboard rises after — never both at once.
      duration: const Duration(milliseconds: 190),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _chat = CommandChatController(_store);
    // Let any page open the chat (optionally pre-scoped to a category) without a
    // reference to this shell — the chat is an overlay, not a pushable route.
    registerCommandChatOpener(_openChat);
    // Restore saved tasks (and their icons) from on-device storage.
    _store.load();
    // Load the Documents library once (shell owns it now that Documents is a tab).
    _documents.load();
    // Check for a newer app version on launch, and prompt (blocking if the
    // build is below the server's min-supported → mandatory update).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
      // Ask for notification permission on first reach into the app — reminders
      // are the whole point, so the OS prompt should appear once at the start,
      // not only if the user digs into Settings.
      _askNotificationPermissionOnce();
    });
  }

  /// The ★ opens the command chat IN PLACE: the one bottom bar morphs (nav pill →
  /// home dot, ★ → text field) and the chat content fades/rises in above it — all
  /// off [_morph], so it's one continuous motion (no route push, no second bar).
  void _openCommand() => _openChat();

  /// Open the chat overlay, seeding the thread. With [seedCategory] it drops
  /// straight into that category's create fields; otherwise the root menu. The
  /// shell seeds here (the overlay no longer self-resets), so a seeded open is
  /// never clobbered.
  void _openChat({TaskCategory? seedCategory}) {
    if (_chatOpen) return;
    if (_tab != 0) _tab = 0; // the chat overlays Home
    if (seedCategory != null) {
      _chat.startCreateForCategory(seedCategory);
    } else {
      _chat.reset();
    }
    setState(() => _chatOpen = true);
    _morph.forward();
  }

  /// Close the chat — the bar morphs back to Home·Browse + ★ and the overlay fades
  /// out. Used by the home dot, a nav-tab tap, and system back.
  void _closeCommand() {
    if (!_chatOpen) return;
    setState(() => _chatOpen = false);
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

  /// First-run notification permission ask. Guarded by a persisted flag so the
  /// system prompt is shown ONCE (on the first real launch into the app); after
  /// that the user manages it in Settings. On Android 13+ this surfaces the OS
  /// permission dialog; below 13 it's a no-op (auto-granted).
  Future<void> _askNotificationPermissionOnce() async {
    const key = 'notif_permission_asked_v1';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    // init() is idempotent; ensurePermissions() no-ops until it's ready.
    await ReminderScheduler.instance.init();
    await ReminderScheduler.instance.ensurePermissions();
  }

  @override
  void dispose() {
    registerCommandChatOpener(null);
    _morph.dispose();
    _chat.dispose();
    _searchController.dispose();
    _store.dispose();
    _documents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      // isActive == "this page is the visible tab" — drives each page's entrance
      // replay. Command mode is an OVERLAY on Home, so Home stays active.
      HomePage(key: _homeKey, store: _store, isActive: _tab == 0),
      BrowsePage(store: _store, isActive: _tab == 1),
      // Documents is now a top-level tab (moved out of Browse). Embedded mode
      // drops its back arrow — a tab has nothing to pop to.
      DocumentsPage(store: _documents, embedded: true),
    ];

    // The overlay must clear the bottom bar: bar height + its bottom padding +
    // safe-area inset.
    final barSpace = 56.0 + 14 + MediaQuery.of(context).padding.bottom;

    return PopScope(
      // While the chat is open, system back closes IT (not the app).
      canPop: !_chatOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _chatOpen) _closeCommand();
      },
      child: Scaffold(
        extendBody: true, // let the background flow under the floating bar
        // The overlay + bar handle the keyboard themselves; don't let the Scaffold
        // resize the whole page under them.
        resizeToAvoidBottomInset: false,
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

                // The chat CONTENT overlay — Revo + greeting + thread, fading and
                // rising in above the pages, BELOW the bar, in sync with the morph.
                Positioned.fill(
                  child: CommandChatOverlay(
                    controller: _chat,
                    morph: _morph,
                    barSpace: barSpace,
                    searchController: _searchController,
                    onNavigated: _closeCommand,
                  ),
                ),

                // The ONE morphing bottom bar: nav+★  ⇄  home-dot + text field.
                // Rides above the keyboard via viewInsets.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: SafeArea(
                      top: false,
                      child: _BottomBar(
                        t: t,
                        tab: _tab,
                        busy: _chat.commandBusy,
                        searchController: _searchController,
                        onTab: (i) {
                          // Tapping a nav tab closes the chat + switches tab.
                          _closeCommand();
                          setState(() => _tab = i);
                        },
                        onOpenCommand: _openCommand,
                        onCloseCommand: _closeCommand,
                        onSend: _chat.sendCommand,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
    required this.busy,
    required this.searchController,
    required this.onTab,
    required this.onOpenCommand,
    required this.onCloseCommand,
    required this.onSend,
  });

  final double t;
  final int tab;
  final bool busy;
  final TextEditingController searchController;
  final ValueChanged<int> onTab;
  final VoidCallback onOpenCommand;
  final VoidCallback onCloseCommand;
  final ValueChanged<String> onSend;

  static const _h = 56.0; // bar height — trimmed so the bar isn't top/bottom-heavy
  static const _gap = 10.0; // gap between the nav pill and the search circle

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final total = c.maxWidth;
          // TWO elements: the NAV PILL (Home · Browse · Docs, in one glass pill)
          // on the left, and a SEPARATE search circle on the right. At rest they
          // sit side by side with just [_gap] between — the nav pill takes all the
          // width left of the circle, so nothing is wasted.
          // As the chat opens (t→1) the search circle grows into the full-width
          // field and the nav pill collapses to a dot.
          final rightW =
              (_h + (total - _gap - _h - _h) * t).clamp(_h, total - _gap - _h);
          final leftW = (total - _gap - rightW).clamp(_h, total);

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
                    busy: busy,
                    controller: searchController,
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
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The tabs — each in an EQUAL Expanded slice so Home · Browse · Docs
            // fill the whole pill evenly (no wasted space, no left-hugging). The
            // selected tab draws its accent pill centred in its slice; each tab
            // fills the pill's full height. Fades out by t=0.35 as it collapses.
            if (navOpacity > 0.01)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Opacity(
                    opacity: navOpacity,
                    child: Row(
                      children: [
                        for (var i = 0; i < _kNavItems.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: _kNavItems[i],
                              selected: i == index,
                              onTap: () => onChanged(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (dotOpacity > 0.01)
              Opacity(
                opacity: dotOpacity,
                // The collapsed nav = a HOME dot: tapping it closes the chat and
                // brings the Home·Browse nav bar back.
                child: const Icon(Icons.home_rounded,
                    size: 24, color: AppColors.inkSoft),
              ),
          ],
        ),
      ),
    );
  }
}

/// The RIGHT element: the ★ button that MORPHS into the command text field as
/// [t] → 1. At t=0 it's a solid accent ★ circle; as it widens it crossfades into
/// a glass field (accent glyph + text field + send button) — the SINGLE field for
/// the chat. Tapping the ★ (t≈0) opens the chat; the field auto-focuses once open.
class _RightHalf extends StatefulWidget {
  const _RightHalf({
    required this.t,
    required this.busy,
    required this.controller,
    required this.onOpenCommand,
    required this.onSend,
  });
  final double t;
  final bool busy;

  /// The search/command field's controller — OWNED by the shell so the chat
  /// overlay can read the live query for its quick-search palette.
  final TextEditingController controller;
  final VoidCallback onOpenCommand;
  final ValueChanged<String> onSend;

  @override
  State<_RightHalf> createState() => _RightHalfState();
}

class _RightHalfState extends State<_RightHalf> {
  final _focus = FocusNode();
  bool _hasText = false;

  TextEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(_RightHalf old) {
    super.didUpdateWidget(old);
    // The ★ is now a SEARCH. Let the open animation FINISH first, THEN raise the
    // keyboard — so the search field visibly lands, and only after that does the
    // keyboard slide up. (Focusing mid-morph made the keyboard shove in while the
    // bar was still morphing, which felt jumpy.) We fire when the morph has all
    // but completed (t≈1), one frame later, so the two motions are sequential.
    final justOpened = widget.t > 0.985 && old.t <= 0.985;
    if (justOpened && !_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.t > 0.985) _focus.requestFocus();
      });
    } else if (widget.t < 0.5 && _focus.hasFocus) {
      // Closing: drop focus EARLY (as soon as the bar starts collapsing) so the
      // keyboard is already gone before the pill narrows — this is what removes
      // the pixel jump / overflow when returning to Home.
      _focus.unfocus();
    }
  }

  void _onText() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    // The controller is owned by the shell — don't dispose it here.
    _controller.removeListener(_onText);
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
    final t = widget.t;
    // ★ glyph fades out fast; the field row fades in once there's room, so its
    // full-width Row never overflows the still-narrow pill mid-morph.
    final starOpacity = (1 - t / 0.4).clamp(0.0, 1.0);
    final fieldOpacity = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    return _LiquidGlass(
      accentFill: 1 - t, // solid accent ★ (t=0) → light glass field (t=1)
      onTap: t < 0.5
          ? () {
              HapticFeedback.mediumImpact();
              widget.onOpenCommand();
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (starOpacity > 0.01)
              Opacity(
                opacity: starOpacity,
                child: const Icon(Icons.search_rounded,
                    size: 25, color: Colors.white),
              ),
            if (fieldOpacity > 0.01)
              Positioned.fill(
                child: Opacity(
                  opacity: fieldOpacity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 20,
                            color: AppColors.accent.withValues(alpha: 0.95)),
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
                              hintText: 'Search anything…',
                              hintStyle: TextStyle(color: AppColors.inkFaint),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        _SendButton(
                          enabled: _hasText && !widget.busy,
                          onTap: _send,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The circular accent send button inside the morphed field — dim + flat when
/// there's nothing to send, bright accent when active.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(6),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 20,
          color: enabled
              ? Colors.white
              : AppColors.inkFaint.withValues(alpha: 0.8),
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
      height: 56,
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
        borderRadius: BorderRadius.circular(28),
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
      borderRadius: BorderRadius.circular(28),
      child: GlassPanel(
        borderRadius: 28,
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
  (
    icon: Icons.folder_outlined,
    active: Icons.folder_rounded,
    label: 'Docs',
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
    // The Orbit look: the SELECTED tab is an ACCENT PILL (violet, matching the
    // search ★) — icon + label side by side, white, with a soft glow. Every
    // unselected tab is a quiet muted glyph + label. The pill hugs its own
    // content and lives inside an evenly-spread row, so it can never push a
    // sibling out — the bar can't overflow.
    // Each tab fills its slot's FULL height (no dead vertical band) and is
    // vertically centred. The SELECTED tab draws an accent pill INSET a few px
    // from the glass edge, hugging its icon + label; unselected tabs are a quiet
    // glyph. Only the selected tab shows a label, so the bar stays clean.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Padding(
          // Small inset so the selected pill sits INSIDE the glass, not touching.
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9B7CFF), AppColors.accent],
                    )
                  : null,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.42),
                        blurRadius: 14,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            // FittedBox keeps the selected pill's icon+label from ever
            // overflowing its equal slice on narrow screens — it scales down to
            // fit instead of spilling.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? item.active : item.icon,
                      size: 22,
                      color: selected ? Colors.white : AppColors.inkFaint,
                    ),
                    if (selected) ...[
                      const SizedBox(width: 7),
                      Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: -0.1,
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
    );
  }
}
