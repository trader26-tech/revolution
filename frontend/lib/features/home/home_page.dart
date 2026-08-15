import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../add/presentation/added_success.dart';
import '../add/presentation/open_add_flow.dart';
import '../auth/data/auth_store.dart';
import '../documents/data/documents_store.dart';
import '../documents/presentation/add_document_sheet.dart';
import '../documents/presentation/documents_page.dart';
import '../settings/data/profile_store.dart';
import '../settings/settings_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import '../tasks/presentation/task_details_sheet.dart';
import 'presentation/collection_page.dart';
import 'presentation/upcoming_page.dart';
import 'presentation/widgets/command_box.dart';
import 'presentation/widgets/command_chat.dart';
import 'presentation/widgets/home_dashboard.dart' show showAddBrowseSheet;
import 'presentation/widgets/today_bubbles.dart';

/// The Home screen.
///
/// Fast capture: tap ﹢, the keyboard opens on an inline field, type a name and
/// it's added instantly. Set the date/details later via the row's calendar
/// button or by tapping the task. A glass top bar holds Settings + Add.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    this.isActive = true,
    this.navOpen = false,
    this.onToggleNav,
  });

  final TaskStore store;

  /// True when Home is the visible tab. Each time it flips back to true, the
  /// today conjuring animation re-plays — so returning to Home always greets
  /// you with the bubbling reveal, not a static list.
  final bool isActive;

  /// Whether the nav is currently open — when true, Home hides its bottom input
  /// line so the nav and the input interchange on one line.
  final bool navOpen;

  /// Toggle the nav (from the Menu button in the input line).
  final VoidCallback? onToggleNav;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Bumped every time Home becomes active again — a change to this value tells
  /// TodayBubbles to restart its reveal from empty.
  int _replay = 0;

  /// The AI (Groq) one-liners for today, keyed by task id — fetched from the
  /// backend, which generates them once a day and caches them. Empty until the
  /// fetch returns (and stays empty when there's no Groq key), in which case
  /// TodayBubbles uses its local sentence fallback.
  Map<String, String> _aiLines = {};

  /// The local documents library — loaded lazily so "Add a document" from the
  /// top "+" can add a file, and so tapping through opens the same library.
  final _documents = DocumentsStore();

  // ── The command CHAT, rendered in the feed (not a floating box) ──
  final List<ChatMsg> _chat = [];
  bool _commandBusy = false; // a parse/add is in flight

  /// Drives the shimmer reveal of Revo's most-recent card reply.
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _fetchLines();
    _documents.load();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _documents.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage old) {
    super.didUpdateWidget(old);
    // Became visible again (Browse → Home): replay the conjuring + refresh the
    // AI lines (cheap: the backend serves today's from cache after the first).
    if (widget.isActive && !old.isActive) {
      setState(() => _replay++);
      _fetchLines();
    }
  }

  /// Pull today's AI lines. Best-effort — a failure just leaves the local
  /// fallback sentences in place.
  Future<void> _fetchLines() async {
    try {
      final res = await ApiClient.instance.get('/tasks/lines');
      final lines = (res is Map ? res['lines'] : null);
      if (lines is Map) {
        final next = <String, String>{};
        lines.forEach((k, v) {
          if (v is String && v.trim().isNotEmpty) next['$k'] = v;
        });
        if (mounted) setState(() => _aiLines = next);
      }
    } catch (_) {
      // Non-fatal — keep whatever we have (fallback sentences render fine).
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsPage(store: widget.store)),
    );
  }

  /// The "+" — slide the Browse list up from the bottom ("Add to Revolution").
  /// Pick a category → its tailored add form opens → it's saved. On success,
  /// Revo pops in to celebrate, then we glide into that category's collection.
  ///
  /// To keep it one clean forward motion (no flash of Home in between), we push
  /// the collection page FIRST — hidden behind the opaque success page — so when
  /// the celebration ends and dismisses, the subscriptions/SIP/occasions page is
  /// revealed directly underneath.
  Future<void> _startAdd() async {
    final choice = await showAddBrowseSheet(context);
    if (choice == null || !mounted) return;

    // Document short-circuit — happens BEFORE the category add flow, so the
    // category branch below (and its celebration ordering) is untouched.
    if (choice.isDocument) {
      await _addDocumentFromHome();
      return;
    }

    final category = choice.category!;
    final result = await openCategoryForm(context, widget.store, category);
    if (result == null || !mounted) return;
    final willAdd = result.task != null || result.selfSaved;
    if (!willAdd) return;
    // CRITICAL ordering — the celebration must be the TOPMOST route so it plays
    // the instant the form closes, then reveals the destination underneath when
    // it dismisses. Home, the collection page, and the success page all share
    // ONE navigator, so the LAST push wins the top:
    //   1. push the collection page (instant, no anim) — it sits UNDER,
    //   2. push the success celebration ON TOP (opaque + instant) — so it's
    //      what the user sees immediately, no flash of the collection first,
    //   3. persist (async) behind the cover — its listener rebuild is hidden,
    //   4. await the celebration; when it auto-dismisses it pops back to the
    //      collection page, already in place underneath.
    _openCollection(category, instant: true);
    if (!mounted) return;
    final celebration = showAddedSuccess(context, label: addedLabel(category));
    await persistAddResult(widget.store, result);
    await celebration;
  }

  /// Add a document straight from the top "+" — opens the same add-document
  /// sheet the Documents library uses, adding into the library root. On success
  /// a toast confirms, with a shortcut to open Documents and see it.
  Future<void> _addDocumentFromHome() async {
    final added = await showAddDocumentSheet(context, store: _documents);
    if (added == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added — ${added.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.accent,
          onPressed: () {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DocumentsPage(store: _documents),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Tapping a card opens its RICH edit form (routed by category), where every
  /// detail — including the full highlight text that's clipped on the card — is
  /// shown in full and editable. Non-form categories fall back to the quick
  /// details sheet.
  Future<void> _editTask(Task task) async {
    await openEditForm(
      context,
      widget.store,
      task,
      fallback: () => showTaskDetailsSheet(context, task),
    );
  }

  /// Delete a reminder (from the home line's long-press menu). Removes it on the
  /// server + locally, and offers a quick Undo that re-creates it.
  Future<void> _deleteTask(Task task) async {
    try {
      await widget.store.remove(task);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete — try again.")),
        );
      }
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFFF6B6B), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Deleted — ${task.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accent,
          onPressed: () => widget.store.restore(task),
        ),
      ),
    );
  }

  /// Open the full-screen vertical list of all upcoming reminders (from today
  /// onward, grouped day by day), reached from the "Up next" arrow.
  void _openUpcoming() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UpcomingPage(
        tasks: widget.store.tasks,
        onTap: (t) {
          Navigator.of(context).pop();
          _editTask(t);
        },
      ),
    ));
  }

  /// Open a category's collection page (all Subscriptions, all SIPs…), or the
  /// full "All" collection when [category] is null.
  ///
  /// [instant] skips the slide transition — used by the add flow, where this
  /// page is placed underneath the success celebration and must be settled by
  /// the time the celebration lifts (no visible slide, no flash).
  void _openCollection(TaskCategory? category, {bool instant = false}) {
    final page = CollectionPage(store: widget.store, category: category);
    Navigator.of(context).push(
      instant
          ? PageRouteBuilder(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, _, _) => page,
            )
          : MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The empty state is centred against the WHOLE screen (behind the top
        // bar + nav), so the icon + text block sits optically dead-centre — not
        // pushed up by the top bar's height.
        AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final showEmpty = widget.store.tasks.isEmpty;
            if (!showEmpty) return const SizedBox.shrink();
            return Positioned.fill(
              child: _EmptyContent(onAdd: _startAdd),
            );
          },
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              _TopBar(
                onSettings: _openSettings,
                onAdd: _startAdd,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.store,
                  builder: (context, _) => _buildList(),
                ),
              ),
            ],
          ),
        ),
        // The COMMAND INPUT — pinned to the bottom, always open. Hidden while
        // the nav is open, so the input line and the Home·Browse nav interchange
        // on that one line (the Menu button on the left opens the nav).
        if (!widget.navOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CommandBox(
                busy: _commandBusy,
                onSend: _sendCommand,
                onMenu: () => widget.onToggleNav?.call(),
              ),
            ),
          ),
      ],
    );
  }

  // ── The command chat: parse on Enter, confirm to create ──────────────────

  /// The user pressed Enter — append their message + Revo's thinking, parse it,
  /// then reply with the card (its summary shimmering in).
  Future<void> _sendCommand(String text) async {
    setState(() {
      _chat.add(ChatMsg.user(text));
      _chat.add(ChatMsg.thinking());
      _commandBusy = true;
    });

    CommandDraft? draft;
    try {
      final res = await ApiClient.instance.post('/tasks/parse', {'text': text});
      if (res is Map && res['ok'] == true && res['draft'] is Map) {
        draft =
            CommandDraft.fromJson((res['draft'] as Map).cast<String, dynamic>());
      }
    } catch (_) {
      // fall through to raw fallback
    }
    draft ??= CommandDraft.raw(text);

    if (!mounted) return;
    setState(() {
      _chat.removeWhere((m) => m.kind == ChatKind.thinking);
      // Route by intent: add → a create card; complete/delete/update → resolve
      // the target reminder and show an action card (or a picker if ambiguous).
      if (draft!.intent == CommandIntent.add) {
        _chat.add(ChatMsg.card(draft));
      } else {
        final matches = _matchTasks(draft.target ?? draft.title);
        if (matches.isEmpty) {
          _chat.add(ChatMsg.done(
              'Couldn\'t find a reminder matching “${draft.target ?? draft.title}”.'));
        } else if (matches.length == 1) {
          _chat.add(ChatMsg.action(draft, matches.first));
        } else {
          _chat.add(ChatMsg.picker(draft, matches.take(5).toList()));
        }
      }
      _commandBusy = false;
    });
    _shimmer.forward(from: 0);
  }

  /// Fuzzy-match the user's tasks against a target phrase — case-insensitive
  /// substring / word overlap, best first. Only active (non-archived) tasks.
  List<Task> _matchTasks(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final qWords = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final scored = <(Task, int)>[];
    for (final t in widget.store.tasks) {
      final title = t.title.toLowerCase();
      var score = 0;
      if (title == q) {
        score = 100;
      } else if (title.contains(q) || q.contains(title)) {
        score = 60;
      } else {
        // Word overlap.
        final tWords = title.split(RegExp(r'\s+')).toSet();
        final overlap = qWords.where(tWords.contains).length;
        if (overlap > 0) score = 20 * overlap;
      }
      if (score > 0) scored.add((t, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  /// Confirm a card/action → run the intended operation, then Revo confirms.
  Future<void> _confirmCommand(ChatMsg msg) async {
    final draft = msg.draft;
    if (draft == null || _commandBusy) return;
    setState(() => _commandBusy = true);
    HapticFeedback.mediumImpact();
    try {
      final String done;
      switch (draft.intent) {
        case CommandIntent.add:
          await widget.store.add(
            draft.title,
            dueAt: draft.dueAt,
            repeat: draft.repeat,
            amount: draft.amount,
            currency: draft.currency ?? 'INR',
            category: draft.category,
            note: draft.note,
            doseTimes: draft.doseTimes,
            courseDays: draft.courseDays,
            repeatDays: draft.repeatDays,
          );
          done = 'Added “${draft.title}”';
        case CommandIntent.complete:
          final t = msg.task!;
          if (!t.done) await widget.store.toggleDone(t);
          done = 'Marked “${t.title}” done';
        case CommandIntent.delete:
          final t = msg.task!;
          await widget.store.remove(t);
          done = 'Deleted “${t.title}”';
        case CommandIntent.update:
          final t = msg.task!;
          await widget.store.update(t.copyWith(
            title: draft.title.isNotEmpty ? draft.title : null,
            amount: draft.amount,
            dueAt: draft.dueAt,
            repeat: draft.repeat != RepeatCadence.none ? draft.repeat : null,
            note: draft.note,
          ));
          done = 'Updated “${t.title}”';
      }
      if (!mounted) return;
      setState(() {
        msg.confirmed = true;
        _chat.add(ChatMsg.done(done));
        _commandBusy = false;
      });
      _fetchLines();
      setState(() => _replay++);
    } catch (_) {
      if (!mounted) return;
      setState(() => _commandBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't do that — try again.")),
      );
    }
  }

  /// The user picked a candidate from an ambiguous match → replace the picker
  /// with a concrete action card for that task.
  void _pickCandidate(ChatMsg picker, Task task) {
    final i = _chat.indexOf(picker);
    if (i == -1) return;
    setState(() => _chat[i] = ChatMsg.action(picker.draft!, task));
    _shimmer.forward(from: 0);
  }

  void _dismissCommand(ChatMsg msg) {
    setState(() => _chat.remove(msg));
  }

  /// The chat messages as feed rows. The LAST message animates its shimmer via
  /// [_shimmer]; every earlier one is fully settled (shimmer = 1). A small top
  /// gap separates the thread from the bubbles above.
  List<Widget> _buildChat() {
    if (_chat.isEmpty) return const [];
    final rows = <Widget>[const SizedBox(height: 8)];
    for (var i = 0; i < _chat.length; i++) {
      final msg = _chat[i];
      final isLast = i == _chat.length - 1;
      final row = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: isLast
            ? AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) => CommandMessage(
                  msg: msg,
                  shimmer: _shimmer.value,
                  busy: _commandBusy,
                  onConfirm: () => _confirmCommand(msg),
                  onDismiss: () => _dismissCommand(msg),
                  onPick: (t) => _pickCandidate(msg, t),
                ),
              )
            : CommandMessage(
                msg: msg,
                shimmer: 1,
                busy: _commandBusy,
                onConfirm: () => _confirmCommand(msg),
                onDismiss: () => _dismissCommand(msg),
                onPick: (t) => _pickCandidate(msg, t),
              ),
      );
      rows.add(row);
    }
    return rows;
  }

  /// Everything due TODAY, still ACTIVE (not done) — the home bubbles. Soonest
  /// first.
  List<Task> _dueToday(List<Task> all) {
    final today = _dayOf(DateTime.now());
    return all
        .where((t) =>
            t.isScheduled && !t.done && _dayOf(t.dueAt!) == today)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  /// Everything due TODAY the user has already marked DONE — shown in the
  /// "Done today" section, each restorable (mark undone).
  List<Task> _doneToday(List<Task> all) {
    final today = _dayOf(DateTime.now());
    return all
        .where((t) => t.isScheduled && t.done && _dayOf(t.dueAt!) == today)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  /// "Good morning, Sanjeev" — the line Revo says atop the bubbles.
  String _greeting(String name) {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : (h < 17 ? 'Good afternoon' : 'Good evening');
    final first = name.trim().isEmpty ? '' : name.trim().split(' ').first;
    return first.isEmpty ? part : '$part, $first';
  }

  Widget _buildList() {
    final allTasks = widget.store.tasks;

    // Truly empty (no tasks at all) → the welcoming empty state is drawn as a
    // full-screen centred layer behind this (see build), so nothing here.
    if (allTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    // The display name: prefer the one captured at onboarding/login
    // (AuthStore), fall back to the Settings profile name.
    final displayName = (AuthStore.instance.name?.trim().isNotEmpty ?? false)
        ? AuthStore.instance.name!.trim()
        : ProfileStore.instance.name;

    // The feed reads top-to-bottom: the GREETING (Revo + "Good morning"), then
    // the DATE this list is for — today — with a compact arrow to open the full
    // upcoming list, then today's tasks as animated BUBBLES. The date header is
    // handed to TodayBubbles as its `header` slot so it renders right BELOW the
    // greeting (and fades in with it), keeping that one animated intro block.
    // Browse lives on the nav bar; "up next" is reached from the header's arrow.
    final rows = <Widget>[
      TodayBubbles(
        replayTick: _replay,
        greeting: _greeting(displayName),
        header: _DateHeader(day: DateTime.now(), onUpcoming: _openUpcoming),
        tasks: _dueToday(allTasks),
        doneTasks: _doneToday(allTasks),
        lineFor: (t) => _aiLines[t.id],
        onOpen: _editTask,
        onToggle: (t) => widget.store.toggleDone(t),
        onDelete: _deleteTask,
      ),
      // The command CHAT — attached to the page, below the bubbles. Revo's most
      // recent card reply shimmers in via _shimmer; older ones stay settled.
      ..._buildChat(),
    ];

    // Cap text scale across the whole home feed so large system fonts can never
    // push the greeting, the fixed-height cards, or the browse rows into overflow.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 120),
        children: rows,
      ),
    );
  }
}

/// The glass top bar: Settings on the left, Filter on the right. (Add lives as
/// the floating button above the keyboard, so it's not here.)
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSettings,
    required this.onAdd,
  });

  final VoidCallback onSettings;

  /// The "+" — add a reminder. Replaces the old filter button in the top-right.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
          const Spacer(),
          // Add button, right corner — accent-filled with a purple glow so it
          // reads as the app's one special action.
          GlassIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Add reminder',
            accent: true,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 44, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              'All clear',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap ﹢ to add your first task.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// The date header that leads the Home feed — it tells the user, up front and
/// unmistakably, WHAT DAY this list of reminders is for. A small accent kicker
/// ("TODAY") sits over the full date ("Thursday, 14 August"); on the right, a
/// labelled arrow button opens the full upcoming list, so looking ahead is the
/// user's choice, not clutter in the feed.
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day, required this.onUpcoming});

  final DateTime day;
  final VoidCallback onUpcoming;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdays[day.weekday - 1];
    final fullDate = '$weekday, ${day.day} ${_months[day.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── The date, two-tier ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fullDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── A compact circular arrow — tap to look ahead. No label; the user
          //    learns what it does by tapping. Minimal, not a wide pill. ──
          _UpcomingButton(onTap: onUpcoming),
        ],
      ),
    );
  }
}

/// A small round glass button — just a forward arrow — that opens the full
/// upcoming list. Deliberately label-free and compact so it reads as a quiet
/// affordance next to the date, not a heavy call-to-action.
class _UpcomingButton extends StatelessWidget {
  const _UpcomingButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassPanel(
        borderRadius: 999,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
