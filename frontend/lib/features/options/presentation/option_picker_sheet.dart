import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/options_store.dart';

/// A bottom sheet that lets the user pick one of a [kind]'s options — built-in
/// defaults plus their own saved additions — or add a brand-new one via a
/// "+ Add new…" row. New options are saved through [store] (persisted) and
/// immediately selectable. Returns the chosen value, or null if dismissed.
Future<String?> showOptionPicker(
  BuildContext context, {
  required OptionsStore store,
  required OptionKind kind,
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _OptionPickerSheet(store: store, kind: kind, current: current),
  );
}

class _OptionPickerSheet extends StatefulWidget {
  const _OptionPickerSheet({
    required this.store,
    required this.kind,
    required this.current,
  });

  final OptionsStore store;
  final OptionKind kind;
  final String current;

  @override
  State<_OptionPickerSheet> createState() => _OptionPickerSheetState();
}

class _OptionPickerSheetState extends State<_OptionPickerSheet> {
  @override
  Widget build(BuildContext context) {
    final options = widget.store.optionsFor(widget.kind);
    return SafeArea(
      top: false,
      child: Padding(
        // Lift above the keyboard when the add dialog isn't in use.
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.kind.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        title: Text(o),
                        trailing: o == widget.current
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.accent)
                            : (widget.store.contains(widget.kind, o) &&
                                    !widget.kind.defaults.contains(o)
                                ? _RemoveButton(
                                    onTap: () => _remove(o),
                                  )
                                : null),
                        onTap: () => Navigator.pop(context, o),
                      ),
                    // The "+ Add new…" row.
                    ListTile(
                      leading: const Icon(Icons.add_rounded,
                          color: AppColors.accent),
                      title: Text(
                        'Add new ${widget.kind.title.toLowerCase()}…',
                        style: const TextStyle(
                          color: AppColors.accentDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: _addNew,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(String value) async {
    await widget.store.remove(widget.kind, value);
    if (mounted) setState(() {});
  }

  Future<void> _addNew() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddOptionDialog(kind: widget.kind),
    );
    if (name == null || name.trim().isEmpty) return;
    final saved = await widget.store.add(widget.kind, name);
    if (saved != null && mounted) {
      // Select the freshly-added option and close.
      Navigator.pop(context, saved);
    }
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkFaint),
      tooltip: 'Remove',
      onPressed: onTap,
    );
  }
}

class _AddOptionDialog extends StatefulWidget {
  const _AddOptionDialog({required this.kind});
  final OptionKind kind;

  @override
  State<_AddOptionDialog> createState() => _AddOptionDialogState();
}

class _AddOptionDialogState extends State<_AddOptionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New ${widget.kind.title.toLowerCase()}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: _hint(widget.kind),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }

  String _hint(OptionKind kind) => switch (kind) {
        OptionKind.list => 'e.g. Household',
        OptionKind.category => 'e.g. Subscriptions',
        OptionKind.paymentMethod => 'e.g. Amazon Pay',
      };
}
