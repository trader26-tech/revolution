import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';
import '../data/documents_store.dart';
import '../domain/document.dart';

/// Add a document: pick a file, name it, choose a folder, upload. Returns the
/// created [Document], or null if dismissed.
Future<Document?> showAddDocumentSheet(
  BuildContext context, {
  required DocumentsStore store,
}) {
  return showModalBottomSheet<Document>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddDocumentSheet(store: store),
  );
}

class _AddDocumentSheet extends StatefulWidget {
  const _AddDocumentSheet({required this.store});
  final DocumentsStore store;

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  final _nameCtrl = TextEditingController();
  TaskCategory _folder = TaskCategory.other;

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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExts,
      // Keep the on-device path (we copy it locally). withData is the fallback
      // for platforms/pickers that only return bytes.
      withData: true,
    );
    final picked = result?.files.firstOrNull;
    if (picked == null) return;
    setState(() {
      _file = picked;
      _error = null;
      // Seed the name from the filename (without extension) if empty.
      if (_nameCtrl.text.trim().isEmpty) {
        final base = picked.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        _nameCtrl.text = base;
      }
    });
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
      // Store LOCALLY — copy the on-device file when we have a path, else write
      // the picked bytes. Never leaves the phone.
      final doc = file.path != null
          ? await widget.store.addFromPath(
              name: _nameCtrl.text.trim(),
              folder: _folder,
              sourcePath: file.path!,
              originalName: file.name,
            )
          : await widget.store.addFromBytes(
              name: _nameCtrl.text.trim(),
              folder: _folder,
              bytes: file.bytes ?? const <int>[],
              originalName: file.name,
            );
      if (mounted) Navigator.of(context).pop(doc);
    } catch (e) {
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

              // File picker tile.
              _FileTile(file: _file, onTap: _pickFile),
              const SizedBox(height: 18),

              // Name.
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

              // Folder.
              const _Label('FOLDER'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in TaskCategory.values)
                    _FolderChip(
                      category: c,
                      selected: _folder == c,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _folder = c);
                      },
                    ),
                ],
              ),

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

              const SizedBox(height: 18),
              // Reassurance — the whole point of this being local.
              const _PrivacyNote(),

              const SizedBox(height: 16),
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

class _FolderChip extends StatelessWidget {
  const _FolderChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final TaskCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = category.color;
    return Material(
      color: selected ? c.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? c : AppColors.cardBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 16, color: selected ? c : AppColors.inkSoft),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
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

/// A calm reassurance line: this stays on the phone, never uploaded.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF34D399);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: green.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 18, color: green),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: 'Saved on your phone. ',
                    style: TextStyle(color: AppColors.ink),
                  ),
                  TextSpan(
                    text: 'Kept privately on this device — never uploaded.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
