import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// The command INPUT BAR — one line at the bottom of Home: a Menu button on the
/// LEFT (opens the nav; the field hides while the nav is open) and the text
/// field. Enter sends. The chat itself renders in the Home feed
/// (command_chat.dart), not here — this is just the always-there input.
class CommandBox extends StatefulWidget {
  const CommandBox({
    super.key,
    required this.onSend,
    required this.onMenu,
    this.busy = false,
  });

  /// The user pressed Enter / send with non-empty text.
  final ValueChanged<String> onSend;

  /// Tapped the Menu button — opens the nav (the shell hides this field).
  final VoidCallback onMenu;

  /// A parse/add is in flight — show a spinner instead of the send arrow.
  final bool busy;

  @override
  State<CommandBox> createState() => _CommandBoxState();
}

class _CommandBoxState extends State<CommandBox> {
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _focus.hasFocus
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.cardBorder,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Menu on the LEFT — opens the nav; the shell then swaps this
            //    whole bar out for the Home·Browse nav. ──
            _MenuButton(onTap: widget.onMenu),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onTap: () => setState(() {}),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Add a reminder — just type it…',
                  hintStyle: TextStyle(color: AppColors.inkFaint),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                  isDense: true,
                ),
              ),
            ),
            _SendButton(busy: widget.busy, onTap: _send),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

/// The left Menu button — a soft round grid glyph that reveals the nav.
class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 6, 2, 6),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Icon(Icons.grid_view_rounded,
            size: 19, color: AppColors.inkSoft),
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
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, color: AppColors.accent),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(6),
        width: 38,
        height: 38,
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
