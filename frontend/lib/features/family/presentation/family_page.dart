import 'package:flutter/material.dart';

import '../data/family_repository.dart';
import '../domain/family_member.dart';
import 'widgets/edit_member_sheet.dart';
import 'widgets/member_avatar.dart';

/// The "Family" settings screen: the head of family manages every member here.
///
/// Everyone the head adds becomes a person their reminders (insurance,
/// passports, EMIs…) can be linked to. The head's own "You" record always
/// appears first and can be renamed but not removed.
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key, required this.ownerId});

  final String ownerId;

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  late final _repo = FamilyRepository(ownerId: widget.ownerId);

  List<FamilyMember> _members = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.list();
      if (!mounted) return;
      setState(() {
        _members = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _addMember() async {
    final result = await showEditMemberSheet(context);
    if (result == null) return;
    try {
      final created = await _repo.create(
        FamilyMemberDraft(name: result.name, relation: result.relation),
      );
      if (mounted) setState(() => _members = [..._members, created]);
    } catch (e) {
      _toast("Couldn't add member: $e");
    }
  }

  Future<void> _editMember(FamilyMember m) async {
    final result = await showEditMemberSheet(context, existing: m);
    if (result == null) return;
    try {
      final updated = await _repo.update(
        m.id,
        name: result.name,
        relation: result.relation,
      );
      if (mounted) {
        setState(() => _members =
            _members.map((x) => x.id == m.id ? updated : x).toList());
      }
    } catch (e) {
      _toast("Couldn't save: $e");
    }
  }

  Future<void> _deleteMember(FamilyMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${m.name}?'),
        content: const Text(
          'Their reminders stay, but will no longer be linked to anyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final previous = _members;
    setState(() => _members = _members.where((x) => x.id != m.id).toList());
    try {
      await _repo.delete(m.id);
    } catch (e) {
      if (mounted) {
        setState(() => _members = previous);
        _toast("Couldn't remove: $e");
      }
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add member'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Center(child: Text('Couldn\'t load your family.\n$_error',
              textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            'Everyone you look after. Link each renewal to the right person.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        for (final m in _members) _MemberTile(
          member: m,
          onEdit: () => _editMember(m),
          onDelete: m.isSelf ? null : () => _deleteMember(m),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onEdit,
    this.onDelete,
  });

  final FamilyMember member;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: MemberAvatar(member: member, size: 46),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(member.isSelf ? 'You (head of family)' : member.relation),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
