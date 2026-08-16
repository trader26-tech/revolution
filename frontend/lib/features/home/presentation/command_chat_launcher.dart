import 'package:flutter/widgets.dart';

import '../../tasks/domain/task.dart';

/// A tiny app-level hook to OPEN the command chat from anywhere — without needing
/// a reference to the shell (which owns the chat overlay + its controller).
///
/// The chat is an in-shell OVERLAY (not a pushable route), so a deep page like a
/// category's collection page can't push it or reach the shell's controller. The
/// shell registers an opener on mount; any page calls [openCommandChatFor].
///
/// Usage:
///   • Shell (once, in initState): registerCommandChatOpener(({seedCategory}) {…});
///   • Any page: openCommandChatFor(context, seedCategory: TaskCategory.subscription);
typedef CommandChatOpener = void Function({TaskCategory? seedCategory});

CommandChatOpener? _opener;

/// Called by the shell to register how the chat opens. Passing null clears it.
void registerCommandChatOpener(CommandChatOpener? fn) => _opener = fn;

/// Open the command chat. When [seedCategory] is given, the chat opens PRE-SCOPED
/// to a create for that category (straight into its field questions); otherwise
/// it opens the normal root menu. No-op if the shell hasn't registered yet.
///
/// [context] is accepted for call-site symmetry / future needs; the current
/// implementation routes through the registered opener.
void openCommandChatFor(BuildContext context, {TaskCategory? seedCategory}) {
  _opener?.call(seedCategory: seedCategory);
}
