import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/documents_store.dart';
import '../domain/document.dart';
import 'folder_picker_sheet.dart';

/// Add a document: pick a file, name it, choose a destination folder, save
/// LOCALLY. Returns the created [DocItem], or null if dismissed.
Future<DocItem?> showAddDocumentSheet(
  BuildContext context, {
  required DocumentsStore store,
  String? folderId,
}) {
  return showModalBottomSheet<DocItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddDocumentSheet(store: store, initialFolderId: folderId),
  );
}

class _AddDocumentSheet extends StatefulWidget {
  const _AddDocumentSheet({required this.store, this.initialFolderId});
  final DocumentsStore store;
  final String? initialFolderId;

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  final _nameCtrl = TextEditingController();
  late String? _folderId = widget.initialFolderId;

  PlatformFile? _file;
  bool _saving = false;
  String? _error;

  static const _allowedExts = ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _file != null && _nameCtrl.text.trim().isNotEmpty && !_saving;

  String get _folderLabel {
    final f = widget.store.folderById(_folderId);
    return f?.displayName ?? 'Documents';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExts,
      withData: true,
    );
    final picked = result?.files.firstOrNull;
    if (picked == null) return;
    setState(() {
      _file = picked;
      _error = null;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = picked.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<void> _pickFolder() async {
    final choice = await showFolderPickerSheet(
      context,
      store: widget.store,
      initialFolderId: _folderId,
    );
    if (choice != null) setState(() => _folderId = choice.folderId);
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null || !_valid) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final doc = file.path != null
          ? await widget.store.addFromPath(
              name: _nameCtrl.text.trim(),
              folderId: _folderId,
              sourcePath: file.path!,
              originalName: file.name,
            )
          : await widget.store.addFromBytes(
              name: _nameCtrl.text.trim(),
              folderId: _folderId,
              bytes: file.bytes ?? const <int>[],
              originalName: file.name,
            );
      if (mounted) Navigator.of(context).pop(doc);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save the file — try picking it again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
              const Text(
                'Add a document',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 20),

              _FileTile(file: _file, onTap: _pickFile),
              const SizedBox(height: 18),

              const _Label('NAME'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
                decoration: _fieldDecoration('e.g. Zerodha statement'),
              ),
              const SizedBox(height: 18),

              // Destination folder — a dropdown-style row that opens the folder
              // picker (browse / create), replacing the old category chips.
              const _Label('FOLDER'),
              const SizedBox(height: 8),
              _FolderSelector(label: _folderLabel, onTap: _pickFolder),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _valid ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.cardBorder,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save to my phone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              // The reassurance reads naturally as a quiet footnote UNDER the
              // action — no coloured box, just a small lock + line.
              const SizedBox(height: 12),
              const _PrivacyNote(),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        filled: true,
        fillColor: AppColors.bg,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.inkFaint),
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
      );
}

/// The pick-a-file tile — shows the chosen file, or a prompt to pick one.
class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onTap});
  final PlatformFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = file;
    final isPdf = (f?.extension ?? '').toLowerCase() == 'pdf';
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: f == null ? AppColors.cardBorder : AppColors.accent,
              width: f == null ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  f == null
                      ? Icons.upload_file_rounded
                      : (isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded),
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f?.name ?? 'Choose a file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f == null ? 'PDF or image · up to 10 MB' : 'Tap to change',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dropdown-style folder selector row.
class _FolderSelector extends StatelessWidget {
  const _FolderSelector({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.inkFaint,
      ),
    );
  }
}

/// A calm reassurance footnote under the action — no coloured box, just a quiet
/// lock + line so it's easy to read without competing with the button.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 14, color: Color(0xFF34D399)),
        const SizedBox(width: 6),
        Text(
          'Added locally',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.inkFaint,
          ),
        ),
      ],
    );
  }
}
