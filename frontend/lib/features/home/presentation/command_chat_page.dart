import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/starfield.dart';
import '../../documents/data/documents_store.dart';
import '../../documents/presentation/add_document_sheet.dart';
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

  final _scroll = ScrollController();
  int _lastTick = -1;
  bool _wasOpen = false;

  CommandChatController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      // Two clear beats: the greeting line conjures first (0 → ~0.62), THEN the
      // four CRUD rows cascade in one after another (~0.62 → 1). Long enough that
      // neither feels rushed and they never land at the same time.
      duration: const Duration(milliseconds: 2400),
    );
    _c.addListener(_onControllerChanged);
    // Watch the morph so we can seed the greeting + replay the conjure each time
    // the overlay opens (it stays mounted in the shell, gated by the morph).
    widget.morph.addListener(_onMorph);
  }

  /// On the rising edge of the morph (chat opening), replay the shimmer so the
  /// header + content conjure fresh. The SHELL seeds the thread before forwarding
  /// the morph (reset for a normal open, or a pre-scoped create for a category),
  /// so we must NOT reset here — that would clobber a seeded category.
  void _onMorph() {
    final open = widget.morph.value > 0.01;
    if (open && !_wasOpen) {
      _wasOpen = true;
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

  /// "Document" in the category picker → the add-document sheet (a file upload,
  /// not a chat field-flow). On success, confirm + re-show the menu.
  Future<void> _openDocumentSheet() async {
    final store = DocumentsStore()..load();
    final added = await showAddDocumentSheet(context, store: store);
    if (mounted && added != null) {
      _c.noteThenMenu('Saved your document.');
    }
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

              // The twinkling STARFIELD — the app's signature sky, painted on the
              // space gradient so the chat feels like the same continuous space as
              // onboarding/Home. Fades in with the morph; never eats taps.
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    // Just a few stars — a quiet scatter (6–7), not a dense field.
                    child: const Starfield(starCount: 7, intensity: 0.9),
                  ),
                ),
              ),

              // (No aurora/purple bloom — the space gradient + faint stars are the
              // whole backdrop. A coloured wash read as heavy/playful, not premium.)

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
              // On the MENU step we run TWO strictly-sequential beats on the one
              // shimmer clock: the question conjures + FINISHES over 0→0.5, then
              // the list cascades over 0.5→1. So here the greeting is remapped to
              // complete by the half-way point. On every other step the header
              // conjures across the whole clock as usual (single beat).
              final onMenu =
                  _c.chat.isNotEmpty && _c.chat.last.kind == ChatKind.menu;
              final headerProgress = onMenu
                  ? (_shimmer.value / 0.5).clamp(0.0, 1.0)
                  : _shimmer.value;
              return _HeroGreeting(
                text: _c.header,
                progress: headerProgress,
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
              onDocument: _openDocumentSheet,
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
    required this.text,
    required this.progress,
    required this.entrance,
  });

  /// The whole header line — one uniform sentence that changes per step (see
  /// CommandChatController.header). Rendered as a single gradient line, so it's
  /// consistent: no mixed colours, no one-word-highlighted look.
  final String text;

  /// Per-open shimmer progress (0→1) for the MagicText word reveal.
  final double progress;

  /// Entrance progress (0→1, already eased) for a gentle slide-in.
  final double entrance;

  @override
  Widget build(BuildContext context) {
    final slide = Curves.easeOut.transform(entrance.clamp(0.0, 1.0));
    final bloom = progress >= 0.999
        ? 0.0
        : math.sin(progress.clamp(0.0, 1.0) * math.pi);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 22, 18),
      child: Opacity(
        opacity: slide,
        child: Transform.translate(
          offset: Offset(0, (1 - slide) * 12),
          // ONE uniform header: the full line, one size/weight, one violet→
          // lavender gradient across the whole thing, with a soft glow.
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35 * bloom),
                  blurRadius: 28 * bloom,
                  spreadRadius: 1 * bloom,
                ),
              ],
            ),
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3EFFF), // near-white lavender
                  Color(0xFFB9A5FF), // soft violet
                ],
              ).createShader(rect),
              blendMode: BlendMode.srcIn,
              child: MagicText(
                key: ValueKey('header-$text'),
                text: text,
                progress: progress,
                reading: true,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white, // recoloured by the ShaderMask
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

