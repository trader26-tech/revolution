import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../onboarding/presentation/widgets/magic_text.dart' show MagicText;
import '../../update_flow/presentation/update_flow_sheet.dart';
import 'widgets/command_chat.dart';
import 'widgets/command_chat_controller.dart';
import 'widgets/interactive_flow.dart';

/// The COMMAND CHAT content, rendered as an in-shell OVERLAY (not a route) so the
/// single bottom bar can morph the ★ into the text field in place beneath it. The
/// entire Create / Read / Update / Delete conversation happens here; picking an
/// option continues the thread in place.
///
/// [morph] (0→1) is the shell's bottom-bar morph controller — the SAME one that
/// widens the ★ into the field — so this overlay's entrance (aurora bloom + Revo
/// + greeting rise) is perfectly in sync with the bar, giving one fluid motion.
/// [barSpace] is the height to leave clear at the bottom for the bar.
///
/// Wrapped by the shell in a [Material] so text never shows the yellow "missing
/// Material" debug underlines.
class CommandChatOverlay extends StatefulWidget {
  const CommandChatOverlay({
    super.key,
    required this.controller,
    required this.morph,
    required this.barSpace,
  });

  final CommandChatController controller;
  final Animation<double> morph;
  final double barSpace;

  @override
  State<CommandChatOverlay> createState() => _CommandChatOverlayState();
}

class _CommandChatOverlayState extends State<CommandChatOverlay>
    with TickerProviderStateMixin {
  /// Drives the per-message conjure (MagicText) reveal of the newest reply.
  late final AnimationController _shimmer;

  /// A slow, endless breath so the aurora keeps living once it's settled — the
  /// "it's alive, listening" feel (like Gemini Live's ambient glow).
  late final AnimationController _breath;

  final _scroll = ScrollController();
  int _lastTick = -1;
  bool _wasOpen = false;

  CommandChatController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      // Long enough for the two-tier greeting to land AND the four CRUD rows to
      // cascade in one after another without feeling rushed.
      duration: const Duration(milliseconds: 1900),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _c.addListener(_onControllerChanged);
    // Watch the morph so we can seed the greeting + replay the conjure each time
    // the overlay opens (it stays mounted in the shell, gated by the morph).
    widget.morph.addListener(_onMorph);
  }

  /// On the rising edge of the morph (chat opening), seed the menu + replay the
  /// shimmer so the greeting conjures fresh each open.
  void _onMorph() {
    final open = widget.morph.value > 0.01;
    if (open && !_wasOpen) {
      _wasOpen = true;
      // Fresh start every open — no stale previous conversation.
      _c.reset();
      _lastTick = _c.revealTick;
      _shimmer.forward(from: 0);
    } else if (!open && _wasOpen) {
      _wasOpen = false;
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    widget.morph.removeListener(_onMorph);
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
    // Confirm, then re-show the CRUD menu so there's always a way to pick another
    // action (never a dead end).
    if (mounted) _c.noteThenMenu('Done — your changes are saved.');
  }

  @override
  Widget build(BuildContext context) {
    // Content-only overlay (the shell owns the bar). Fully ignore pointers when
    // closed so taps pass through to Home; fade + rise in on the morph.
    return AnimatedBuilder(
      animation: widget.morph,
      builder: (context, _) {
        final t = widget.morph.value;
        if (t <= 0.001) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: t < 0.5, // interactive once mostly open
          child: Stack(
            children: [
              // The base space gradient — the "cleared screen", fading in.
              Positioned.fill(
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.bgTop, AppColors.bg],
                      ),
                    ),
                  ),
                ),
              ),

              // The Gemini-Live AURORA — blooms up from below, then breathes.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _breath,
                    builder: (context, _) => CustomPaint(
                      painter: _AuroraPainter(
                        entrance: t,
                        breath: _breath.value,
                      ),
                    ),
                  ),
                ),
              ),

              // The content (Revo + greeting + thread) rises + fades in, leaving
              // room at the bottom for the shell's morphing bar.
              Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 28),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: widget.barSpace),
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) => Column(
                          children: [
                            const SizedBox(height: 12),
                            Expanded(child: _buildList()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList() {
    final msgs = _c.chat;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      itemCount: msgs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return AnimatedBuilder(
            animation: Listenable.merge([_shimmer, widget.morph, _c]),
            builder: (context, _) {
              final (lead, hero) = _c.header;
              return _HeroGreeting(
                lead: lead,
                hero: hero,
                progress: _shimmer.value,
                entrance: widget.morph.value,
              );
            },
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
  const _HeroGreeting({
    required this.lead,
    required this.hero,
    required this.progress,
    required this.entrance,
  });

  /// The quiet lead line (tier 1) and the big gradient hero word (tier 2) — both
  /// change per step (see CommandChatController.header), so the header is never a
  /// constant greeting.
  final String lead;
  final String hero;

  /// Per-open shimmer progress (0→1) for the MagicText word reveal.
  final double progress;

  /// Entrance progress (0→1, already eased) for a gentle slide-in.
  final double entrance;

  @override
  Widget build(BuildContext context) {
    final slide = Curves.easeOut.transform(entrance.clamp(0.0, 1.0));
    // Two tiers, matching the HOME greeting: a quiet lead line, then a BIG
    // gradient-filled hero line (violet→lavender ShaderMask) with a soft glow —
    // the same premium "name" treatment as "Good evening, Rajeev".
    final tier1 = _seg(progress, 0.0, 0.55);
    final tier2 = _seg(progress, 0.4, 1.0);
    final bloom = tier2 >= 0.999 ? 0.0 : math.sin(tier2.clamp(0.0, 1.0) * math.pi);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 22, 18),
      child: Opacity(
        opacity: slide,
        child: Transform.translate(
          offset: Offset(0, (1 - slide) * 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tier 1 — the quiet lead line. Keyed by text so a new step's line
              // re-conjures instead of morphing letters in place.
              MagicText(
                key: ValueKey('lead-$lead'),
                text: lead,
                progress: tier1,
                reading: true,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              // Tier 2 — the big gradient HERO word, glowing in.
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.45 * bloom),
                      blurRadius: 26 * bloom,
                      spreadRadius: 1 * bloom,
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFEDE7FF), // near-white lavender
                      AppColors.accent, // vivid violet
                    ],
                  ).createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: MagicText(
                    key: ValueKey('hero-$hero'),
                    text: hero,
                    progress: tier2,
                    style: const TextStyle(
                      fontSize: 40,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: Colors.white, // recoloured by the ShaderMask
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Remap [p] onto a sub-window [start,end], clamped 0..1.
  double _seg(double p, double start, double end) =>
      ((p - start) / (end - start)).clamp(0.0, 1.0);
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
