import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../tasks/domain/task.dart';
import '../domain/add_category.dart';
import 'widgets/add_scaffold.dart';
import 'widgets/local_photo_field.dart';

/// The Birthday form — the leanest of all. A birthday only needs WHOSE it is and
/// WHEN. No price, no billing, no documents. It always repeats yearly, so we
/// don't ask that either. Two fields, done.
///
/// Returns a ready-to-save [Task] titled "`name`’s birthday", repeating yearly,
/// or null if cancelled.
class BirthdayFormPage extends StatefulWidget {
  const BirthdayFormPage({super.key});

  @override
  State<BirthdayFormPage> createState() => _BirthdayFormPageState();
}

class _BirthdayFormPageState extends State<BirthdayFormPage> {
  static final _accent = AddCategory.birthday.color;

  final _name = TextEditingController();
  // Default to today's day/month so the wheel opens somewhere sensible; the year
  // doesn't matter for a yearly reminder, but we keep this year for the first
  // occurrence.
  DateTime _date = DateTime.now();

  /// The person's photo (local device path), shown as a round avatar.
  String? _photo;

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Birthday',
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_valid) return;
    final person = _name.text.trim();
    // Possessive that reads naturally: "Aditya’s birthday", "Chris’ birthday".
    final title = person.endsWith('s')
        ? '$person’ birthday'
        : '$person’s birthday';
    Navigator.of(context).pop(
      Task(
        id: 'new',
        title: title,
        dueAt: _date,
        repeat: RepeatCadence.yearly,
        imagePath: _photo,
        storedCategory: TaskCategory.birthday,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AddScaffold(
      title: 'Add a birthday',
      accent: _accent,
      icon: AddCategory.birthday.icon,
      canSave: _valid,
      onSave: _save,
      children: [
        // The person's photo — a round face avatar, shown everywhere later.
        const AddFieldLabel('PHOTO  (optional)'),
        const SizedBox(height: 12),
        LocalPhotoField(
          path: _photo,
          accent: _accent,
          circular: true,
          label: 'Add their photo',
          onChanged: (p) => setState(() => _photo = p),
        ),
        const SizedBox(height: 22),

        const AddFieldLabel('WHOSE BIRTHDAY?'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _name,
          hint: 'Mom, Aditya, my partner…',
          accent: _accent,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 22),
        const AddFieldLabel('THE DATE'),
        const SizedBox(height: 10),
        AddDateField(
          date: _date,
          accent: _accent,
          onTap: _pickDate,
        ),
        const SizedBox(height: 14),
        // A gentle note that it repeats — so it's clear we've got it covered
        // every year without asking.
        Row(
          children: [
            Icon(Icons.autorenew_rounded, size: 16, color: _accent),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'We’ll remind you every year — automatically.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
