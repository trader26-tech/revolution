import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The inline quick-add row: a radio circle, a text field (auto-focused so the
/// keyboard opens immediately), and a calendar button to jump straight to the
/// details. Enter or the calendar button submits.
///
/// [onSubmit] receives the typed name and whether the user asked to open details
/// (true when they tapped the calendar button). Empty submissions are ignored.
class QuickAddRow extends StatefulWidget {
  const QuickAddRow({
    super.key,
    required this.onSubmit,
    required this.onDismiss,
  });

  /// (title, openDetails) → add the task; openDetails asks to show the sheet.
  final void Function(String title, {required bool openDetails}) onSubmit;
  final VoidCallback onDismiss;

  @override
  State<QuickAddRow> createState() => _QuickAddRowState();
}

class _QuickAddRowState extends State<QuickAddRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Open the keyboard as soon as the row appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit({required bool openDetails}) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      widget.onDismiss();
      return;
    }
    widget.onSubmit(text, openDetails: openDetails);
    _controller.clear();
    // Keep focus so the user can rattle off several tasks in a row.
    if (!openDetails) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // No full-width border here — the list draws inset dividers between rows.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked,
              size: 22, color: AppColors.inkFaint),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(openDetails: false),
              // If they tap away with nothing typed, dismiss the row.
              onTapOutside: (_) {
                if (_controller.text.trim().isEmpty) widget.onDismiss();
              },
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Add a task…',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.inkFaint),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _submit(openDetails: true),
            icon: const Icon(Icons.calendar_today_outlined,
                size: 20, color: AppColors.inkSoft),
            tooltip: 'Set date & details',
          ),
        ],
      ),
    );
  }
}
