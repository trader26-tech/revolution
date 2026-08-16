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
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondary) =>
          CommandChatPage(controller: controller, entrance: animation),
      transitionsBuilder: (context, animation, secondary, child) {
        // The page paints its own aurora + rise off [entrance]; here we only add
        // a soft fade so the push/pop never hard-cuts.
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
                    entrance: Curves.easeOutCubic
                        .transform(widget.entrance.value),
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
              final t = Curves.easeOutCubic.transform(widget.entrance.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 34),
                  child: child,
                ),
              );
            },
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Column(
                  children: [
                    _Header(onClose: () => Navigator.of(context).maybePop()),
                    Expanded(child: _buildList()),
                    _ChatInput(
                      busy: _c.commandBusy,
                      onSend: _c.sendCommand,
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
            animation: _shimmer,
            builder: (context, _) => _HeroGreeting(progress: _shimmer.value),
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

/// The big conjured greeting hero — "What do you want to do today?" revealed the
/// way the front page conjures its lines (MagicText), with a soft Revo eyebrow.
class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The Revo character (the circle-with-triangle mascot) — the same one
          // that used to sit by the home greeting. It now lives here, greeting
          // you when the ★ command chat opens.
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: AnimatedMascot(size: 56, glow: true),
          ),
          MagicText(
            text: 'What do you want\nto do today?',
            progress: progress,
            reading: true,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 30,
              height: 1.14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The top bar: just a back button that closes the chat. (No glyph — the Revo
/// mascot lives with the greeting hero below.)
class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 2),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onClose,
            size: 42,
          ),
        ],
      ),
    );
  }
}

/// The pinned bottom input — mirrors the shell's command field (accent glyph,
/// a borderless field, a circular accent send button), inside a glass pill.
class _ChatInput extends StatefulWidget {
  const _ChatInput({required this.busy, required this.onSend});
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// Whether the field has non-blank text — drives the send button's active
  /// state (there's nothing to send until you type something).
  bool _hasText = false;

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
      child: GlassPanel(
        borderRadius: 26,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          child: Row(
            children: [
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
              // Active only when there's something to send AND we're not busy.
              _SendButton(
                enabled: _hasText && !widget.busy,
                onTap: _send,
              ),
            ],
          ),
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
