import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/api/api_client.dart';
import '../../../tasks/data/task_store.dart';
import '../../../tasks/domain/task.dart';
import 'command_chat.dart';
import 'interactive_flow.dart';

/// The command-chat ENGINE, lifted out of HomePageState so the full-screen
/// [CommandChatPage] owns the whole Create/Read/Update/Delete conversation in one
/// place (the chat no longer lives in the Home feed).
///
/// A plain [ChangeNotifier]: it holds the message thread + busy flag and mutates
/// the shared [TaskStore]; the view listens and rebuilds. It does NOT own an
/// AnimationController (that needs a vsync) — instead it bumps [revealTick] each
/// time a fresh Revo reply should shimmer in, and the page drives its shimmer
/// controller off that.
///
/// Home-only side effects that used to live alongside these handlers
/// (`_fetchLines()` — the AI one-liner refresh — and `_replay++` — the bubble
/// reveal replay) are intentionally NOT here: they're Home concerns. Home already
/// listens to the store, so tasks added/edited/removed from chat still reflect on
/// its feed; only the instant AI-line refresh is deferred to Home's next fetch.
class CommandChatController extends ChangeNotifier {
  CommandChatController(this.store);

  final TaskStore store;

  /// The conversation thread (persists for the controller's lifetime — the shell
  /// owns it, so closing + reopening the chat resumes where you left off).
  final List<ChatMsg> chat = [];

  /// A parse/add/update is in flight — disables confirm buttons.
  bool commandBusy = false;

  /// Bumped whenever the newest message should shimmer in. The page watches this
  /// and restarts its shimmer AnimationController from 0.
  int revealTick = 0;

  DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  void _reveal() {
    revealTick++;
    notifyListeners();
  }

  // ── Entry points ─────────────────────────────────────────────────────────

  /// Seed the root Create/Read/Update/Delete menu — unless a conversation is
  /// already going (don't stack menus).
  void startInteractive() {
    if (chat.isNotEmpty) return;
    chat.add(ChatMsg.menu());
    _reveal();
  }

  /// Start FRESH — clear any previous conversation and seed the root menu. Called
  /// each time the chat opens, so reopening never shows the old thread.
  void reset() {
    chat
      ..clear()
      ..add(ChatMsg.menu());
    _reveal();
  }

  /// Jump straight into a chosen root op (the ★ launcher chips) — seeds a menu
  /// then immediately resolves it, so we skip the extra menu step.
  void startWithOp(FlowOp op) {
    if (chat.isEmpty) {
      final menu = ChatMsg.menu();
      chat.add(menu);
      pickOp(menu, op);
    }
  }

  /// Clear the whole thread (used by the page's "new chat" affordance, if any).
  void clear() {
    chat.clear();
    notifyListeners();
  }

  /// The CONTEXTUAL header for the current step — a quiet lead line + a big
  /// gradient "hero" word. It changes as you move through the flow, so the top of
  /// the screen always reflects what you're doing (never a constant greeting).
  /// Returns (lead, hero).
  (String, String) get header {
    if (chat.isEmpty) return ('What do you want to do', 'today?');
    final last = chat.last;
    switch (last.kind) {
      case ChatKind.menu:
        return ('What do you want to do', 'today?');
      case ChatKind.create:
        final flow = last.flow!;
        if (flow.done) return ('That\'s', 'added.');
        switch (flow.stage) {
          case CreateStage.pickCategory:
            return ('What are you', 'adding?');
          case CreateStage.fields:
            // Lead with the category, hero with a short cue.
            return ('Setting up your', '${flow.category?.singular ?? 'item'}.');
          case CreateStage.confirm:
            return ('Ready to', 'save?');
        }
      case ChatKind.answer:
        return ('Here\'s what\'s', 'coming up.');
      case ChatKind.proposal:
        return ('Want me to', 'add this?');
      case ChatKind.action:
        return ('Confirm this', 'change?');
      case ChatKind.picker:
        return ('Which one did you', 'mean?');
      case ChatKind.comingSoon:
        return ('${last.op?.label ?? 'That'} is', 'coming soon.');
      case ChatKind.done:
        return ('All', 'done.');
      case ChatKind.thinking:
        return ('One', 'sec…');
      case ChatKind.user:
        return ('On', 'it.');
    }
  }

  /// Append a plain Revo confirmation line to the thread (used by the page after
  /// an out-of-band flow like the Update sheet completes).
  void note(String text) {
    chat.add(ChatMsg.done(text));
    _reveal();
  }

  /// A confirmation line followed by a fresh CRUD menu, so after an action the
  /// user can immediately pick another — never a dead end.
  void noteThenMenu(String text) {
    chat.add(ChatMsg.done(text));
    chat.add(ChatMsg.menu());
    _reveal();
  }

  bool get hasChat => chat.isNotEmpty;

  // ── The natural-language path: parse on send ─────────────────────────────

  /// The user sent a line — append it + a thinking shimmer, parse it, then reply
  /// with the matching card (its summary shimmering in).
  Future<void> sendCommand(String text) async {
    chat.add(ChatMsg.user(text));
    chat.add(ChatMsg.thinking());
    commandBusy = true;
    notifyListeners();

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

    chat.removeWhere((m) => m.kind == ChatKind.thinking);
    // Route by intent.
    switch (draft.intent) {
      case CommandIntent.query:
        final (header, items) = _answerQuery(draft);
        chat.add(ChatMsg.answer(header, items));
      case CommandIntent.add:
        chat.add(ChatMsg.proposal(draft));
      case CommandIntent.complete:
      case CommandIntent.delete:
      case CommandIntent.update:
        final matches = _matchTasks(draft.target ?? draft.title);
        if (matches.isEmpty) {
          chat.add(ChatMsg.done(
              'I couldn\'t find a reminder matching “${draft.target ?? draft.title}”.'));
        } else if (matches.length == 1) {
          chat.add(ChatMsg.action(draft, matches.first));
        } else {
          chat.add(ChatMsg.picker(draft, matches.take(5).toList()));
        }
    }
    commandBusy = false;
    _reveal();
  }

  /// Answer a QUERY: filter the user's reminders by the asked range (+ optional
  /// target), and return a header line + the matching tasks (soonest first).
  (String, List<Task>) _answerQuery(CommandDraft draft) {
    final now = DateTime.now();
    final today = _dayOf(now);
    bool inRange(Task t) {
      final due = t.dueAt;
      switch (draft.range) {
        case CommandRange.today:
          return due != null && _dayOf(due) == today;
        case CommandRange.tomorrow:
          return due != null &&
              _dayOf(due) == today.add(const Duration(days: 1));
        case CommandRange.week:
          if (due == null) return false;
          final d = _dayOf(due);
          return !d.isBefore(today) &&
              d.isBefore(today.add(const Duration(days: 8)));
        case CommandRange.month:
          if (due == null) return false;
          final d = _dayOf(due);
          return !d.isBefore(today) &&
              d.isBefore(today.add(const Duration(days: 31)));
        case CommandRange.overdue:
          return due != null && _dayOf(due).isBefore(today) && !t.done;
        case CommandRange.all:
          return true;
      }
    }

    var items = store.tasks.where((t) => !t.done && inRange(t)).toList();

    final cat = TaskCategory.values.firstWhere(
      (c) => c.name == draft.category,
      orElse: () => TaskCategory.other,
    );
    final catNamed = draft.category != 'other' && draft.category.isNotEmpty;
    if (catNamed) {
      items = items.where((t) => t.category == cat).toList();
    }

    final target = (draft.target ?? '').trim();
    if (!catNamed && target.isNotEmpty) {
      final matched = _matchTasks(target).toSet();
      items = items.where(matched.contains).toList();
    }
    items.sort((a, b) {
      final ad = a.dueAt, bd = b.dueAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });

    final rangeWord = switch (draft.range) {
      CommandRange.today => 'today',
      CommandRange.tomorrow => 'tomorrow',
      CommandRange.week => 'this week',
      CommandRange.month => 'this month',
      CommandRange.overdue => 'overdue',
      CommandRange.all => 'coming up',
    };
    String noun(int n) {
      if (catNamed) {
        return n == 1 ? cat.singular : cat.label.toLowerCase();
      }
      return n == 1 ? 'thing' : 'things';
    }

    final String header;
    if (items.isEmpty) {
      final what = catNamed ? cat.label.toLowerCase() : 'nothing';
      header = catNamed
          ? 'No $what $rangeWord — you\'re all clear.'
          : (draft.range == CommandRange.today
              ? 'Nothing due today — you\'re clear.'
              : 'Nothing $rangeWord — you\'re all clear.');
    } else {
      final n = items.length;
      final total = items
          .where((t) => t.amount != null)
          .fold<double>(0, (s, t) => s + t.amount!);
      final money = total > 0 ? ' · ₹${total.round()}' : '';
      header = 'You have $n ${noun(n)} $rangeWord$money.';
    }
    return (header, items);
  }

  /// Fuzzy-match the user's tasks against a target phrase — case-insensitive
  /// substring / word overlap, best first.
  List<Task> _matchTasks(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final qWords = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final scored = <(Task, int)>[];
    for (final t in store.tasks) {
      final title = t.title.toLowerCase();
      var score = 0;
      if (title == q) {
        score = 100;
      } else if (title.contains(q) || q.contains(title)) {
        score = 60;
      } else {
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
  /// Returns a human error string on failure (the page shows it), else null.
  Future<String?> confirmCommand(ChatMsg msg) async {
    final draft = msg.draft;
    if (draft == null || commandBusy) return null;
    commandBusy = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    try {
      final String done;
      switch (draft.intent) {
        case CommandIntent.query:
          commandBusy = false;
          notifyListeners();
          return null;
        case CommandIntent.add:
          await store.add(
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
          if (!t.done) await store.toggleDone(t);
          done = 'Marked “${t.title}” done';
        case CommandIntent.delete:
          final t = msg.task!;
          await store.remove(t);
          done = 'Deleted “${t.title}”';
        case CommandIntent.update:
          final t = msg.task!;
          await store.update(t.copyWith(
            title: draft.title.isNotEmpty ? draft.title : null,
            amount: draft.amount,
            dueAt: draft.dueAt,
            repeat: draft.repeat != RepeatCadence.none ? draft.repeat : null,
            note: draft.note,
          ));
          done = 'Updated “${t.title}”';
      }
      msg.confirmed = true;
      chat.add(ChatMsg.done(done));
      commandBusy = false;
      _reveal();
      return null;
    } catch (_) {
      commandBusy = false;
      notifyListeners();
      return "Couldn't do that — try again.";
    }
  }

  /// The user picked a candidate from an ambiguous match → replace the picker
  /// with a concrete action card for that task.
  void pickCandidate(ChatMsg picker, Task task) {
    final i = chat.indexOf(picker);
    if (i == -1) return;
    chat[i] = ChatMsg.action(picker.draft!, task);
    _reveal();
  }

  void dismissCommand(ChatMsg msg) {
    chat.remove(msg);
    notifyListeners();
  }

  // ── The deterministic (no-LLM) assistant: menu → create ──────────────────

  /// The user tapped a root option chip. Create opens the interactive create
  /// flow; Read/Update/Delete are handled at the page level (Update opens the
  /// update sheet — see the page's UPDATE SEAM), so here they still fall back to
  /// a short reply line if reached directly.
  void pickOp(ChatMsg menu, FlowOp op) {
    HapticFeedback.selectionClick();
    final i = chat.indexOf(menu);
    if (i == -1) return;
    switch (op) {
      case FlowOp.create:
        // Create replaces the menu with the interactive create flow (which can
        // be cancelled back to the menu via its own cancel).
        chat[i] = ChatMsg.create(CreateFlow());
        _reveal();
      case FlowOp.read:
        // READ actually works: answer "what's coming up" (all upcoming items),
        // then RE-SHOW the menu so the user can pick another action.
        final draft = CommandDraft(
          title: '',
          category: 'other',
          intent: CommandIntent.query,
          range: CommandRange.all,
        );
        final (header, items) = _answerQuery(draft);
        chat[i] = ChatMsg.answer(header, items);
        chat.add(ChatMsg.menu());
        _reveal();
      case FlowOp.update:
      case FlowOp.delete:
        // No dedicated in-chat flow yet. Show the short reply, then RE-SHOW the
        // menu below it so it's never a dead end with no way back to the options.
        chat[i] = ChatMsg.comingSoon(op);
        chat.add(ChatMsg.menu());
        _reveal();
    }
  }

  /// Create flow: category chosen → advance to the first field question.
  void pickCategory(ChatMsg msg, TaskCategory category) {
    final flow = msg.flow;
    if (flow == null) return;
    HapticFeedback.selectionClick();
    flow.category = category;
    flow.stage = CreateStage.fields;
    flow.fieldIndex = 0;
    _reveal();
  }

  /// Create flow: the current field was answered (or skipped) → advance.
  void answerField(ChatMsg msg, String key, Object? value) {
    final flow = msg.flow;
    if (flow == null) return;
    flow.answer(key, value);
    _reveal();
  }

  /// Create flow: a confirm-card row was tapped → re-ask just that field.
  void editField(ChatMsg msg, int index) {
    final flow = msg.flow;
    if (flow == null) return;
    HapticFeedback.selectionClick();
    flow.editField(index);
    _reveal();
  }

  /// Create flow: Confirm → build the task from the collected values and add it.
  /// Returns a human error string on failure, else null.
  Future<String?> confirmCreate(ChatMsg msg) async {
    final flow = msg.flow;
    if (flow == null || flow.done || commandBusy) return null;
    final title = flow.title?.trim();
    if (title == null || title.isEmpty) return null;
    commandBusy = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    try {
      final doseTimes = doseTimesFor(flow.timesPerDay);
      await store.add(
        title,
        category: flow.category!.name,
        amount: flow.amount,
        currency: 'INR',
        dueAt: flow.dueAt,
        repeat: flow.repeat,
        doseTimes: doseTimes,
        courseDays: flow.courseDays,
      );
      flow.done = true;
      commandBusy = false;
      // Re-show the CRUD menu below the confirmed card so the user can add or do
      // something else without leaving the chat.
      chat.add(ChatMsg.menu());
      _reveal();
      return null;
    } catch (_) {
      commandBusy = false;
      notifyListeners();
      return "Couldn't add that — try again.";
    }
  }

  /// Seed evenly-spaced dose times for a medicine taken [n] times a day.
  List<String> doseTimesFor(int? n) {
    if (n == null || n <= 0) return const [];
    if (n == 1) return const ['09:00'];
    const startHour = 8;
    const endHour = 20;
    final span = endHour - startHour;
    return List.generate(n, (i) {
      final h = startHour + (span * i / (n - 1)).round();
      return '${h.toString().padLeft(2, '0')}:00';
    });
  }
}
