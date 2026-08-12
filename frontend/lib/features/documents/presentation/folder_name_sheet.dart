import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// A tiny sheet to name (or rename) a folder/document. Returns the trimmed
/// name, or null if dismissed.
Future<String?> showFolderNameSheet(
  BuildContext context, {
  required String title,
  String? initial,
  String cta = 'Create',
  String hint = 'Folder name',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FolderNameSheet(
      title: title,
      initial: initial,
      cta: cta,
      hint: hint,
    ),
  );
}

class _FolderNameSheet extends StatefulWidget {
  const _FolderNameSheet({
    required this.title,
    required this.cta,
    required this.hint,
    this.initial,
  });
  final String title;
  final String cta;
  final String hint;
  final String? initial;

  @override
  State<_FolderNameSheet> createState() => _FolderNameSheetState();
}

class _FolderNameSheetState extends State<_FolderNameSheet> {
  late final _ctrl = TextEditingController(text: widget.initial ?? '');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _valid => _ctrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bg,
                hintText: widget.hint,
                hintStyle: const TextStyle(color: AppColors.inkFaint),
                prefixIcon: const Icon(Icons.folder_outlined,
                    color: AppColors.inkFaint),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _valid ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.cardBorder,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.cta,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
