import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../update_flow/presentation/update_flow_sheet.dart';
import 'widgets/command_chat.dart';
import 'widgets/command_chat_controller.dart';
import 'widgets/interactive_flow.dart';

/// The full-screen COMMAND CHAT — the ★ opens this. The entire
/// Create / Read / Update / Delete conversation (and every follow-up) happens
/// here, in place: picking an option continues the thread on THIS screen rather
/// than bouncing back to Home.
///
/// Rooted in a [Scaffold] (Material ancestor) so text never renders with the
/// "missing Material" yellow debug underlines. The [controller] is owned by the
/// shell, so closing + reopening resumes the same conversation.
class CommandChatPage extends StatefulWidget {
  const CommandChatPage({super.key, required this.controller});

  final CommandChatController controller;

  @override
  State<CommandChatPage> createState() => _CommandChatPageState();
}

class _CommandChatPageState extends State<CommandChatPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
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
    _scroll.dispose();
    super.dispose();
  }

  /// When the controller bumps [revealTick], a new Revo reply arrived — restart
  /// the shimmer and scroll it into view.
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
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
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
    );
  }

  Widget _buildList() {
    final msgs = _c.chat;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
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

/// The top bar: a back button that closes the chat + a small "Revo" mark.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 6),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onClose,
            size: 42,
          ),
          const SizedBox(width: 12),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9B7CFF), AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            'Revo',
            style: TextStyle(
              color: AppColors.ink.withValues(alpha: 0.92),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
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
              _SendButton(busy: widget.busy, onTap: _send),
            ],
          ),
        ),
      ),
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
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(6),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: busy
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_upward_rounded,
            size: 20, color: Colors.white),
      ),
    );
  }
}
