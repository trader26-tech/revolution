import 'package:flutter/material.dart';

import '../../domain/family_member.dart';

/// The result of the add/edit sheet — a name + relation to save.
class MemberEditResult {
  const MemberEditResult({required this.name, required this.relation});
  final String name;
  final String relation;
}

/// Opens a clean bottom sheet to add a new member, or edit an existing one.
///
/// Minimal input: a name and a relation chip. Returns null if dismissed.
Future<MemberEditResult?> showEditMemberSheet(
  BuildContext context, {
  FamilyMember? existing,
}) {
  return showModalBottomSheet<MemberEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EditMemberSheet(existing: existing),
  );
}

class _EditMemberSheet extends StatefulWidget {
  const _EditMemberSheet({this.existing});
  final FamilyMember? existing;

  @override
  State<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<_EditMemberSheet> {
  late final TextEditingController _name;
  late String _relation;

  // The head's own record: name editable, relation locked to Self.
  bool get _isSelf => widget.existing?.isSelf ?? false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _relation = widget.existing?.relation ?? 'Spouse';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      MemberEditResult(
        name: _name.text.trim(),
        relation: _isSelf ? 'Self' : _relation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Don't offer "Self" as a pickable relation — it's reserved for the head.
    final relations = kRelations.where((r) => r != 'Self').toList();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.existing == null ? 'Add a family member' : 'Edit member',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Priya',
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (!_isSelf) ...[
              const SizedBox(height: 20),
              Text(
                'Relation',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in relations)
                    ChoiceChip(
                      label: Text(r),
                      selected: _relation == r,
                      onSelected: (_) => setState(() => _relation = r),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(widget.existing == null ? 'Add member' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
