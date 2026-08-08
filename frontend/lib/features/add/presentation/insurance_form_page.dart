import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import '../domain/add_category.dart';
import 'widgets/add_scaffold.dart';
import 'widgets/repeat_cycle_field.dart';

/// The Insurance form — the mirror of the subscription form, but where a
/// subscription attaches a brand LOGO, an insurance policy attaches a DOCUMENT.
///
/// The user captures the policy details (insurer, type, premium, renewal) and
/// attaches the actual policy PDF/photo. That document becomes the item's icon:
/// tapping it later opens the real policy in the phone's native viewer.
///
/// Save is a two-step the form owns itself (it needs the created task's id to
/// upload the file to): create the task → upload the document → pop. Returns
/// true if something was created, so Home can refresh.
class InsuranceFormPage extends StatefulWidget {
  const InsuranceFormPage({super.key, required this.store});

  final TaskStore store;

  @override
  State<InsuranceFormPage> createState() => _InsuranceFormPageState();
}

class _InsuranceFormPageState extends State<InsuranceFormPage> {
  static final _accent = AddCategory.insurance.color;

  final _name = TextEditingController();
  final _amount = TextEditingController();

  /// The policy kind — drives the default name and a sensible cadence.
  _PolicyType _type = _PolicyType.health;
  RepeatCadence _cycle = RepeatCadence.yearly; // insurance is usually yearly
  DateTime _renewal = DateTime.now().add(const Duration(days: 365));

  // The picked-but-not-yet-uploaded document.
  PlatformFile? _doc;
  bool _saving = false;

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.text = _type.defaultName;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _setType(_PolicyType t) {
    HapticFeedback.selectionClick();
    setState(() {
      // If the name is still the previous type's default (untouched), keep it in
      // sync; if the user typed their own, leave it alone.
      final wasDefault = _name.text.trim() == _type.defaultName;
      _type = t;
      if (wasDefault) _name.text = t.defaultName;
    });
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
      withData: true, // we upload the bytes
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _doc = result.files.first);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewal,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
      helpText: 'Renewal date',
    );
    if (picked != null) setState(() => _renewal = picked);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final amount =
          double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      // 1. Create the task so we have its id.
      final created = await widget.store.add(
        _name.text.trim(),
        dueAt: _renewal,
        repeat: _cycle,
        amount: amount,
        currency: 'INR',
        category: 'insurance',
      );
      // 2. Upload the policy document to that task, if one was picked.
      final doc = _doc;
      if (doc != null && doc.bytes != null) {
        await ApiClient.instance.uploadDocument(
          created.id,
          bytes: doc.bytes!,
          filename: doc.name,
          contentType: _mimeFor(doc.extension),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AddScaffold(
      title: 'Add insurance',
      accent: _accent,
      icon: AddCategory.insurance.icon,
      canSave: _valid && !_saving,
      onSave: _save,
      saveLabel: _saving ? 'Saving…' : 'Add',
      children: [
        // ── The policy document — the hero, the way the logo is for a sub. ──
        const AddFieldLabel('POLICY DOCUMENT'),
        const SizedBox(height: 10),
        _DocumentCard(
          file: _doc,
          accent: _accent,
          onPick: _pickDocument,
          onClear: () => setState(() => _doc = null),
        ),
        const SizedBox(height: 22),

        // ── What kind of insurance ──
        const AddFieldLabel('TYPE'),
        const SizedBox(height: 10),
        _TypeChips(value: _type, accent: _accent, onChanged: _setType),
        const SizedBox(height: 22),

        // ── Name (pre-filled from type) ──
        const AddFieldLabel('NAME'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _name,
          hint: 'Health insurance',
          accent: _accent,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 22),

        // ── Premium ──
        const AddFieldLabel('PREMIUM  (optional)'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _amount,
          hint: '12000',
          accent: _accent,
          prefix: '₹',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(height: 22),

        // ── How often the premium is due ──
        const AddFieldLabel('PREMIUM EVERY'),
        const SizedBox(height: 10),
        RepeatCycleField(
          value: _cycle,
          accent: _accent,
          onChanged: (c) {
            HapticFeedback.selectionClick();
            setState(() => _cycle = c);
          },
        ),
        const SizedBox(height: 22),

        // ── Renewal date ──
        const AddFieldLabel('RENEWAL DATE'),
        const SizedBox(height: 10),
        AddDateField(date: _renewal, accent: _accent, onTap: _pickDate),
      ],
    );
  }
}

/// The big document tile. Empty → a dashed "attach" drop-zone. Filled → the
/// file with its type badge + a way to view (opens in the native viewer) and
/// clear.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.file,
    required this.accent,
    required this.onPick,
    required this.onClear,
  });

  final PlatformFile? file;
  final Color accent;
  final VoidCallback onPick;
  final VoidCallback onClear;

  bool get _isPdf => (file?.extension ?? '').toLowerCase() == 'pdf';

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      // Empty — the attach drop-zone.
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.4),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded, size: 30, color: accent),
              const SizedBox(height: 8),
              const Text(
                'Attach your policy',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'PDF or photo',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Filled — the attached file.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file!.name,
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
                  'Attached · tap the icon on Home to view',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accent.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

/// A wrapped set of policy-type chips (Health / Life / Car / Bike / Term / …).
class _TypeChips extends StatelessWidget {
  const _TypeChips({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final _PolicyType value;
  final Color accent;
  final ValueChanged<_PolicyType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in _PolicyType.values)
          GestureDetector(
            onTap: () => onChanged(t),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: t == value
                    ? accent
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: t == value ? accent : AppColors.cardBorder,
                  width: t == value ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon,
                      size: 16,
                      color: t == value ? Colors.white : AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t == value ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum _PolicyType {
  health,
  life,
  car,
  bike,
  term,
  home,
  other;

  String get label => switch (this) {
        _PolicyType.health => 'Health',
        _PolicyType.life => 'Life',
        _PolicyType.car => 'Car',
        _PolicyType.bike => 'Bike',
        _PolicyType.term => 'Term',
        _PolicyType.home => 'Home',
        _PolicyType.other => 'Other',
      };

  String get defaultName => switch (this) {
        _PolicyType.health => 'Health insurance',
        _PolicyType.life => 'Life insurance',
        _PolicyType.car => 'Car insurance',
        _PolicyType.bike => 'Bike insurance',
        _PolicyType.term => 'Term insurance',
        _PolicyType.home => 'Home insurance',
        _PolicyType.other => 'Insurance',
      };

  IconData get icon => switch (this) {
        _PolicyType.health => Icons.favorite_rounded,
        _PolicyType.life => Icons.shield_rounded,
        _PolicyType.car => Icons.directions_car_filled_rounded,
        _PolicyType.bike => Icons.two_wheeler_rounded,
        _PolicyType.term => Icons.description_rounded,
        _PolicyType.home => Icons.home_rounded,
        _PolicyType.other => Icons.more_horiz_rounded,
      };
}

/// Best-effort MIME for a picked file extension.
String _mimeFor(String? ext) => switch ((ext ?? '').toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };

/// Open a task's document in the phone's native viewer (via a signed URL).
/// Shared so the Home card's icon-tap can reuse it. Returns false if there's no
/// document or it couldn't be opened.
Future<bool> openTaskDocument(String taskId) async {
  final url = await ApiClient.instance.documentUrl(taskId);
  if (url == null) return false;
  final uri = Uri.parse(url);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
