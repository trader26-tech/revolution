import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/mascot.dart';
import '../../onboarding/presentation/widgets/magic_text.dart' show MagicText;
import '../../update_flow/presentation/update_flow_sheet.dart';
import 'widgets/command_chat.dart';
import 'widgets/command_chat_controller.dart';
import 'widgets/interactive_flow.dart';

/// Open the full-screen command chat with a Gemini-Live-style entrance: the
/// screen dims to the space gradient, a violet AURORA blooms up from below, and
/// the content rises + fades in. Returns when the page is popped.
Future<void> openCommandChat(
  BuildContext context,
  CommandChatController controller,
) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 560),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondary) {
        // One shared smooth curve drives EVERYTHING the page animates (aurora,
        // Revo, greeting, bottom bar) so the whole open reads as a single fluid
        // motion instead of several independently-eased parts.
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return CommandChatPage(controller: controller, entrance: eased);
      },
      transitionsBuilder: (context, animation, secondary, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(opacity: fade, child: child);
      },
    ),
  );
}

/// The full-screen COMMAND CHAT — the ★ opens this. The entire
/// Create / Read / Update / Delete conversation (and every follow-up) happens
/// here, in place: picking an option continues the thread on THIS screen rather
/// than bouncing back to Home.
///
/// Rooted in a [Scaffold] (Material ancestor) so text never renders with the
/// "missing Material" yellow debug underlines. The [controller] is owned by the
/// shell, so closing + reopening resumes the same conversation. [entrance]
/// (0→1) is the route animation — it drives the aurora bloom + the content rise.
class CommandChatPage extends StatefulWidget {
  const CommandChatPage({
    super.key,
    required this.controller,
    required this.entrance,
  });

  final CommandChatController controller;
  final Animation<double> entrance;

  @override
  State<CommandChatPage> createState() => _CommandChatPageState();
}

class _CommandChatPageState extends State<CommandChatPage>
    with TickerProviderStateMixin {
  /// Drives the per-message conjure (MagicText) reveal of the newest reply.
  late final AnimationController _shimmer;

  /// A slow, endless breath so the aurora keeps living once it's settled — the
  /// "it's alive, listening" feel (like Gemini Live's ambient glow).
  late final AnimationController _breath;

  final _scroll = ScrollController();
  int _lastTick = -1;

  CommandChatController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    // Open with the greeting + CRUD chips if this is a fresh conversation.
    _c.startInteractive();
    _lastTick = _c.revealTick;
    _shimmer.forward(from: 0);
    _c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _shimmer.dispose();
    _breath.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// When the controller bumps [revealTick], a new Revo reply arrived — restart
  /// the conjure shimmer and scroll it into view.
  void _onControllerChanged() {
    if (_c.revealTick != _lastTick) {
      _lastTick = _c.revealTick;
      _shimmer.forward(from: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ── UPDATE SEAM ──────────────────────────────────────────────────────────
  // The Update op opens the self-contained update sheet (category → item →
  // inline edit → Save, writes straight to the store) — a sheet OVER this page,
  // so the conversation stays put. The menu stays in the thread so the user can
  // pick another op afterwards; on close we drop a short confirmation line.
  Future<void> _openUpdateFlow() async {
    await showUpdateFlow(context, _c.store);
    if (mounted) _c.note('Done — your changes are saved.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // The base space gradient — the "cleared screen".
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.bgTop, AppColors.bg],
                ),
              ),
            ),
          ),

          // The Gemini-Live AURORA — blooms up from below on entrance, then keeps
          // a slow breathing glow.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([widget.entrance, _breath]),
                builder: (context, _) => CustomPaint(
                  painter: _AuroraPainter(
                    entrance: widget.entrance.value,
                    breath: _breath.value,
                  ),
                ),
              ),
            ),
          ),

          // The content rises + fades on entrance.
          AnimatedBuilder(
            animation: widget.entrance,
            builder: (context, child) {
              final t = widget.entrance.value;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 28),
                  child: child,
                ),
              );
            },
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Column(
                  children: [
                    // A little top breathing room where the old back header was —
                    // Revo now owns the top-left.
                    const SizedBox(height: 8),
                    Expanded(child: _buildList()),
                    // The morphing bar: ★ expands rightward into the field, a home
                    // dot appears on the left to return home.
                    _MorphBar(
                      entrance: widget.entrance,
                      busy: _c.commandBusy,
                      onSend: _c.sendCommand,
                      onHome: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final msgs = _c.chat;
    // A big conjured HERO greeting sits above the thread — the front-page
    // "MagicText" reveal, at hero scale, so opening the chat feels alive.
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: msgs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return AnimatedBuilder(
            animation: Listenable.merge([_shimmer, widget.entrance]),
            builder: (context, _) => _HeroGreeting(
              progress: _shimmer.value,
              entrance: widget.entrance.value,
            ),
          );
        }
        final i = index - 1;
        final msg = msgs[i];
        final isLast = i == msgs.length - 1;
        final onConfirm = msg.kind == ChatKind.create
            ? () => _confirmCreate(msg)
            : () => _confirmCommand(msg);

        Widget message(double shimmer) => CommandMessage(
              msg: msg,
              shimmer: shimmer,
              busy: _c.commandBusy,
              onConfirm: onConfirm,
              onDismiss: () => _c.dismissCommand(msg),
              onPick: (t) => _c.pickCandidate(msg, t),
              onPickOp: (op) => _onPickOp(msg, op),
              onPickCategory: (cat) => _c.pickCategory(msg, cat),
              onAnswerField: (k, v) => _c.answerField(msg, k, v),
              onEditField: (idx) => _c.editField(msg, idx),
            );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: isLast
              ? AnimatedBuilder(
                  animation: _shimmer,
                  builder: (context, _) => message(_shimmer.value),
                )
              : message(1),
        );
      },
    );
  }

  /// Route a root-menu pick. Update opens the sheet (UPDATE SEAM); everything
  /// else routes through the controller.
  void _onPickOp(ChatMsg menu, FlowOp op) {
    if (op == FlowOp.update) {
      _openUpdateFlow();
    } else {
      _c.pickOp(menu, op);
    }
  }

  Future<void> _confirmCommand(ChatMsg msg) async {
    final err = await _c.confirmCommand(msg);
    if (err != null && mounted) _toast(err);
  }

  Future<void> _confirmCreate(ChatMsg msg) async {
    final err = await _c.confirmCreate(msg);
    if (err != null && mounted) _toast(err);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// The greeting hero, choreographed like Revo waking up and speaking:
///   • entrance 0→~0.55 : Revo is BIG, alone (the greeting hasn't started).
///   • entrance ~0.55→1 : Revo SHRINKS and settles to the top-LEFT, and the
///     greeting conjures in to its RIGHT (MagicText reading-mode = word by word,
///     top-to-bottom / left-to-right), as if Revo is saying it.
/// [progress] drives the greeting's word conjure; [entrance] drives Revo's
/// big→small move + the greeting's hand-off.
class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({required this.progress, required this.entrance});

  /// Per-open shimmer progress (0→1) for the MagicText word reveal.
  final double progress;

  /// Route entrance progress (0→1, already eased) for the Revo move.
  final double entrance;

  static const double _bigSize = 84;
  static const double _smallSize = 44;

  @override
  Widget build(BuildContext context) {
    // Revo starts big, then over the back half of the entrance shrinks and the
    // greeting takes over to its right.
    final move = ((entrance - 0.3) / 0.7).clamp(0.0, 1.0);
    final easedMove = Curves.easeOutCubic.transform(move);
    final revoSize = _bigSize + (_smallSize - _bigSize) * easedMove;

    // The greeting fades/slides in from Revo's side once Revo begins settling.
    final greetIn = ((entrance - 0.45) / 0.55).clamp(0.0, 1.0);
    final easedGreet = Curves.easeOut.transform(greetIn);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 22, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Revo's cell tracks the mascot's CURRENT size (not the big size), so
          // the text stays snug beside it — no dead gap when Revo is small.
          SizedBox(
            width: revoSize,
            height: revoSize,
            child: AnimatedMascot(size: revoSize, glow: true),
          ),
          SizedBox(width: 10 + 4 * easedGreet),
          // The greeting, to Revo's right — appears only as Revo settles, sliding
          // in from its side.
          Expanded(
            child: Opacity(
              opacity: easedGreet,
              child: Transform.translate(
                offset: Offset(-14 * (1 - easedGreet), 0),
                child: MagicText(
                  text: 'What do you\nwant to do today?',
                  progress: progress,
                  reading: true,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 25,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The morphing bottom bar. As the chat opens ([entrance] 0→1):
///   • RIGHT: a small ★ circle (anchored right) WIDENS leftward into the full
///     command field (accent glyph + text field + send button).
///   • LEFT : a small round HOME dot fades in — tapping it closes the chat and
///     brings the nav bar back ([onHome]).
/// So the bar reads as "the ★ opened into a field, with a way home on the left".
class _MorphBar extends StatefulWidget {
  const _MorphBar({
    required this.entrance,
    required this.busy,
    required this.onSend,
    required this.onHome,
  });

  final Animation<double> entrance;
  final bool busy;
  final ValueChanged<String> onSend;
  final VoidCallback onHome;

  @override
  State<_MorphBar> createState() => _MorphBarState();
}

class _MorphBarState extends State<_MorphBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// Whether the field has non-blank text — drives the send button's active
  /// state (there's nothing to send until you type something).
  bool _hasText = false;

  static const _h = 56.0; // bar element height
  static const _gap = 12.0; // gap between the home dot and the field

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        6,
        14,
        14 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedBuilder(
        animation: widget.entrance,
        builder: (context, _) {
          final t = widget.entrance.value.clamp(0.0, 1.0);
          // The home dot's cell grows from 0 → (dot + gap) as we open; the field
          // is Expanded, so the two ALWAYS sum to the available width exactly —
          // no manual clamp that could overflow. The field therefore grows toward
          // the LEFT as the dot pushes in from the left.
          final dotCell = (_h + _gap) * t;
          final dotSize = _h * t;
          // The field's inner text row only mounts once there's room, so it never
          // overflows the still-narrow pill mid-morph.
          final fieldReveal = ((t - 0.5) / 0.5).clamp(0.0, 1.0);

          return SizedBox(
            height: _h,
            child: Row(
              children: [
                // ── LEFT: the home dot (returns to the nav / Home) ──
                SizedBox(
                  width: dotCell,
                  child: dotSize < 1
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Opacity(
                            opacity: t,
                            child: _HomeDot(size: dotSize, onTap: widget.onHome),
                          ),
                        ),
                ),
                // ── RIGHT: the ★-that-became-the-field (fills the remainder) ──
                Expanded(
                  child: _FieldPill(
                    reveal: fieldReveal,
                    starOpacity: (1 - t / 0.4).clamp(0.0, 1.0),
                    controller: _controller,
                    focus: _focus,
                    sendEnabled: _hasText && !widget.busy,
                    onSubmit: _send,
                    onSend: _send,
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

/// The small circular HOME button at the bar's left — brings the nav bar back.
class _HomeDot extends StatelessWidget {
  const _HomeDot({required this.size, required this.onTap});
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: size / 2,
      onTap: onTap,
      shadow: false,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.home_rounded,
            size: size * 0.46, color: AppColors.inkSoft),
      ),
    );
  }
}

/// The right element: the ★ circle that grows into the command field. Crossfades
/// the ★ glyph ([starOpacity]) ⇄ the field row ([reveal]) inside one glass pill.
class _FieldPill extends StatelessWidget {
  const _FieldPill({
    required this.reveal,
    required this.starOpacity,
    required this.controller,
    required this.focus,
    required this.sendEnabled,
    required this.onSubmit,
    required this.onSend,
  });

  final double reveal;
  final double starOpacity;
  final TextEditingController controller;
  final FocusNode focus;
  final bool sendEnabled;
  final VoidCallback onSubmit;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 26,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (starOpacity > 0.01)
              Opacity(
                opacity: starOpacity,
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 24, color: AppColors.accent),
              ),
            if (reveal > 0.01)
              Positioned.fill(
                child: Opacity(
                  opacity: reveal,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 20,
                            color: AppColors.accent.withValues(alpha: 0.95)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focus,
                            onSubmitted: (_) => onSubmit(),
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
                        _SendButton(enabled: sendEnabled, onTap: onSend),
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
          // Dim + flat when there's nothing to send; bright accent when active.
          color: enabled
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.08),
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

/// The living violet AURORA behind the chat — two soft radial blooms (one rising
/// from the bottom, one drifting near the top) that grow in on [entrance] and
/// then keep a slow [breath]. This is the Gemini-Live "listening glow".
class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.entrance, required this.breath});

  /// 0→1 open progress (drives the bloom-in).
  final double entrance;

  /// 0→1 slow breath (drives the settled shimmer).
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    if (entrance <= 0.001) return;
    final w = size.width;
    final h = size.height;

    // Breath eases the glow's strength + radius a little, endlessly.
    final pulse = 0.85 + 0.15 * breath;

    // ── Bottom bloom (rises from below the input) ──
    final bottomCenter = Offset(w * 0.5, h * (1.18 - 0.06 * entrance));
    final bottomRadius = h * (0.55 + 0.20 * entrance) * pulse;
    final bottomAlpha = (0.34 * entrance) * pulse;
    _blob(
      canvas,
      size,
      bottomCenter,
      bottomRadius,
      [
        AppColors.accent.withValues(alpha: bottomAlpha),
        const Color(0xFF3A2A8C).withValues(alpha: bottomAlpha * 0.7),
        Colors.transparent,
      ],
      const [0.0, 0.45, 1.0],
    );

    // ── Top-left drift bloom (subtle, cooler) ──
    final topCenter = Offset(
      w * (0.22 + 0.05 * breath),
      h * (0.18 + 0.03 * (1 - breath)),
    );
    final topRadius = w * (0.75 + 0.10 * entrance) * pulse;
    final topAlpha = (0.16 * entrance) * pulse;
    _blob(
      canvas,
      size,
      topCenter,
      topRadius,
      [
        const Color(0xFF6C4CF0).withValues(alpha: topAlpha),
        Colors.transparent,
      ],
      const [0.0, 1.0],
    );
  }

  void _blob(Canvas canvas, Size size, Offset center, double radius,
      List<Color> colors, List<double> stops) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(colors: colors, stops: stops).createShader(rect);
    // Paint the radial glow across the whole canvas (transparent beyond it).
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.entrance != entrance || old.breath != breath;
}
