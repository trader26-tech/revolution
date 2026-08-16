import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../../core/widgets/starfield.dart';
import '../../tasks/domain/task.dart';
import '../domain/subscription_categories.dart';
import 'widgets/local_photo_field.dart';
import 'widgets/orbit_form.dart';

/// The Important-dates / Birthday form — orbit style, matching Subscription/SIP.
/// A round PHOTO of the person (or their first-letter avatar when none), the
/// name, the date of birth (with an optional year → shows their age), a
/// relationship, and a reminder lead time. Repeats yearly.
///
/// Returns a ready-to-save [Task] (category `birthday`), the edited copy in edit
/// mode, or null if cancelled.
class BirthdayFormPage extends StatefulWidget {
  const BirthdayFormPage({super.key, this.editTask, this.onDelete});

  /// When set, opens in EDIT mode pre-filled; Save returns an updated copy.
  final Task? editTask;

  /// Edit mode only — confirm + delete this task (returns true when deleted).
  final Future<bool> Function()? onDelete;

  @override
  State<BirthdayFormPage> createState() => _BirthdayFormPageState();
}

class _BirthdayFormPageState extends State<BirthdayFormPage> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  String? _photo; // local device path
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month,
      DateTime.now().day); // the day/month it recurs
  bool _knowYear = false; // whether the year (age) is known
  String _type = kDefaultImportantDate; // event type (Birthday/Anniversary/…)
  final Set<String> _customTypes = {};
  int _remindDaysBefore = 0;

  bool get _valid => _name.text.trim().isNotEmpty;

  bool get _isBirthday => _type.toLowerCase() == 'birthday';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.editTask;
    if (edit != null) {
      // The event type is stored on subCategory; recover the person/subject
      // name by stripping the type's possessive suffix from the title.
      if (edit.subCategory != null && edit.subCategory!.trim().isNotEmpty) {
        _type = edit.subCategory!.trim();
        if (!kImportantDateTypes
            .any((c) => c.name.toLowerCase() == _type.toLowerCase())) {
          _customTypes.add(_type);
        }
      }
      _name.text = _subjectFrom(edit.title, _type);
      _photo = edit.imagePath;
      if (edit.dueAt != null) {
        _date = DateTime(
            edit.birthYear ?? edit.dueAt!.year, edit.dueAt!.month,
            edit.dueAt!.day);
      }
      _knowYear = edit.birthYear != null;
      if (edit.birthYear != null) {
        _date = DateTime(edit.birthYear!, _date.month, _date.day);
      }
      _remindDaysBefore = edit.remindDaysBefore;
    }
    _name.addListener(() => setState(() {}));
  }

  /// Strip a trailing "’s `noun`" for the current [type] to recover the name.
  String _subjectFrom(String title, String type) {
    final noun = type.toLowerCase() == 'other' ? '' : type.toLowerCase();
    if (noun.isEmpty) return title.trim();
    return title
        .replaceAll(RegExp("[’']s $noun\$"), '')
        .replaceAll(RegExp("[’'] $noun\$"), '')
        .trim();
  }

  /// Field hint + date-picker title per type.
  String get _nameHint => switch (_type.toLowerCase()) {
        'birthday' => 'Whose birthday?',
        'anniversary' => 'Whose anniversary?',
        'wedding' => 'Whose wedding?',
        'memorial' => 'In memory of…',
        _ => 'What is it?',
      };

  String get _dateTitle => _isBirthday ? 'Date of birth' : 'The date';

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  int? get _age {
    if (!_knowYear) return null;
    final now = DateTime.now();
    var age = now.year - _date.year;
    // Their birthday this year:
    final bdayThisYear = DateTime(now.year, _date.month, _date.day);
    if (bdayThisYear.isAfter(now)) age -= 1; // hasn't happened yet
    return age;
  }

  String _dateLabel() {
    final base = '${_date.day} ${_months[_date.month - 1]}';
    return _knowYear ? '$base ${_date.year}' : base;
  }

  Future<void> _pickDate() async {
    final picked = await showOrbitDatePicker(
      context,
      initial: _date,
      firstDate: DateTime(DateTime.now().year - 100),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      title: _dateTitle,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickType() async {
    final picked = await showCategoryPicker(
      context,
      categories: kImportantDateTypes,
      selected: _type,
      custom: _customTypes.toList(),
    );
    if (picked != null && picked.trim().isNotEmpty) {
      setState(() {
        _type = picked.trim();
        final isBuiltIn = kImportantDateTypes
            .any((c) => c.name.toLowerCase() == picked.trim().toLowerCase());
        if (!isBuiltIn) _customTypes.add(picked.trim());
        // Non-birthday types don't carry an age → turn off the year.
        if (!_isBirthday) _knowYear = false;
      });
    }
  }

  Future<void> _handleDelete() async {
    final deleted = await widget.onDelete!();
    if (deleted && mounted) Navigator.of(context).pop();
  }

  void _save() {
    if (!_valid) return;
    HapticFeedback.lightImpact();
    final title = importantDateTitle(_type, _name.text);
    // Recurs yearly on the day/month; the year is stored separately as
    // birthYear (only when known, only meaningful for a birthday).
    final due = DateTime(DateTime.now().year, _date.month, _date.day);
    final keepYear = _isBirthday && _knowYear;
    final edit = widget.editTask;
    if (edit != null) {
      Navigator.of(context).pop(edit.copyWith(
        title: title,
        dueAt: due,
        repeat: RepeatCadence.yearly,
        imagePath: _photo,
        clearImage: _photo == null,
        category: TaskCategory.birthday,
        subCategory: _type,
        birthYear: keepYear ? _date.year : null,
        clearBirthYear: !keepYear,
        remindDaysBefore: _remindDaysBefore,
      ));
      return;
    }
    Navigator.of(context).pop(Task(
      id: 'new',
      title: title,
      dueAt: due,
      repeat: RepeatCadence.yearly,
      imagePath: _photo,
      storedCategory: TaskCategory.birthday,
      subCategory: _type,
      birthYear: keepYear ? _date.year : null,
      remindDaysBefore: _remindDaysBefore,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Starfield(
        intensity: 0.5,
        child: SafeArea(
          child: Column(
            children: [
              OrbitFormHeader(
                title: widget.editTask != null
                    ? 'Edit occasion'
                    : 'Add an occasion',
                canSave: _valid,
                onBack: () => Navigator.of(context).maybePop(),
                onSave: _save,
                onDelete: widget.onDelete == null ? null : _handleDelete,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    // Identity: round photo + name.
                    _IdentityCard(
                      photo: _photo,
                      name: _name,
                      nameFocus: _nameFocus,
                      hint: _nameHint,
                      onPickPhoto: (p) => setState(() => _photo = p),
                    ),
                    // Quiet reassurance, right under the identity block.
                    const OrbitSaveHint(),
                    const SizedBox(height: 18),

                    // Details.
                    OrbitGroupCard(
                      children: [
                        // The event TYPE — the primary dimension.
                        OrbitCategoryRow(
                          value: _type,
                          onTap: _pickType,
                        ),
                        const OrbitRowDivider(),
                        OrbitNavRow(
                          label: _isBirthday ? 'Date of birth' : 'Date',
                          value: _dateLabel(),
                          onTap: _pickDate,
                        ),
                        // Year/age only make sense for a birthday.
                        if (_isBirthday) ...[
                          const OrbitRowDivider(),
                          _ToggleRow(
                            label: 'I know the year',
                            value: _knowYear,
                            onChanged: (v) => setState(() => _knowYear = v),
                          ),
                          if (_knowYear && _age != null) ...[
                            const OrbitRowDivider(),
                            _AgeRow(age: _age!),
                          ],
                        ],
                        const OrbitRowDivider(),
                        _RemindRow(
                          days: _remindDaysBefore,
                          onChanged: (d) =>
                              setState(() => _remindDaysBefore = d),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Icon(Icons.autorenew_rounded,
                              size: 15, color: AppColors.inkFaint),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'We’ll remind you every year — automatically.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round photo picker + name — the birthday's identity card.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.photo,
    required this.name,
    required this.nameFocus,
    required this.hint,
    required this.onPickPhoto,
  });
  final String? photo;
  final TextEditingController name;
  final FocusNode nameFocus;
  final String hint;
  final ValueChanged<String?> onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final letter = name.text.trim().isEmpty
        ? '?'
        : name.text.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Photo → circular; falls back to the stylized first letter.
          GestureDetector(
            onTap: () => _pick(context),
            child: Container(
              width: 66,
              height: 66,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (photo == null || photo!.isEmpty)
                    ? RadialGradient(
                        center: const Alignment(-0.25, -0.35),
                        colors: [
                          AppColors.accent.withValues(alpha: 0.22),
                          AppColors.card,
                        ],
                      )
                    : null,
                border: Border.all(
                  color: (photo != null && photo!.isNotEmpty)
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : AppColors.accent.withValues(alpha: 0.28),
                  width: 1.5,
                ),
              ),
              child: (photo != null && photo!.isNotEmpty)
                  ? Image.file(File(photo!), fit: BoxFit.cover)
                  : ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [AppColors.ink, Color(0xFFB9A8FF)],
                      ).createShader(r),
                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  focusNode: nameFocus,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: AppColors.accent,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: AppColors.inkFaint,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _pick(context),
                  child: Text(
                    (photo != null && photo!.isNotEmpty)
                        ? 'Change photo'
                        : 'Add their photo',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    // Reuse LocalPhotoField's picker by presenting a tiny sheet, or pick inline.
    // Simpler: open a sheet with a LocalPhotoField.
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSheet(path: photo, onChanged: (p) {
        onPickPhoto(p);
        Navigator.of(context).pop();
      }),
    );
  }
}

/// A small sheet wrapping [LocalPhotoField] to pick/remove the photo.
class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.path, required this.onChanged});
  final String? path;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Their photo',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 14),
              LocalPhotoField(
                path: path,
                accent: AppColors.accent,
                circular: true,
                label: 'Choose a photo',
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled toggle row (orbit style).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Text(label, style: orbitLabelStyle),
          const Spacer(),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeTrackColor: AppColors.accent,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Shows the derived age as a read-only accent pill.
class _AgeRow extends StatelessWidget {
  const _AgeRow({required this.age});
  final int age;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Text('Turns this year', style: orbitLabelStyle),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${age + 1}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A reminder lead-time stepper (On the day → N days before).
class _RemindRow extends StatelessWidget {
  const _RemindRow({required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  static const _presets = [0, 1, 3, 7, 14, 30];

  String _label(int d) => switch (d) {
        0 => 'On the day',
        1 => '1 day before',
        _ => '$d days before',
      };

  /// The preset index nearest to [days] — never -1, so both buttons always work
  /// even if the stored value isn't exactly a preset.
  int get _index {
    var best = 0;
    var bestDiff = (days - _presets[0]).abs();
    for (var i = 1; i < _presets.length; i++) {
      final diff = (days - _presets[i]).abs();
      if (diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final i = _index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Text('Remind me', style: orbitLabelStyle),
          const Spacer(),
          // Minus = earlier → MORE days before the date (the natural mental
          // model: "−" moves the reminder back, ahead of the day). Plus =
          // later → fewer days before, toward "On the day".
          _step(Icons.remove_rounded, i < _presets.length - 1, () {
            onChanged(_presets[i + 1]);
          }),
          SizedBox(
            width: 108,
            child: Text(
              _label(_presets[i]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          _step(Icons.add_rounded, i > 0, () {
            onChanged(_presets[i - 1]);
          }),
        ],
      ),
    );
  }

  Widget _step(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? AppColors.accent : AppColors.inkFaint),
      ),
    );
  }
}
