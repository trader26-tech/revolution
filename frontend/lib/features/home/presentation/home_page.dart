import 'package:flutter/material.dart';

import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/presentation/onboarding_gate.dart';
import '../../panda/presentation/panda_mascot.dart';
import '../../reminders/data/reminders_repository.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/widgets/add_reminder_sheet.dart';
import '../../reminders/presentation/widgets/reminder_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = RemindersRepository();

  List<Reminder> _reminders = [];
  bool _loading = true;
  Object? _error;
  int _pokes = 0;

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
        _reminders = items;
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

  Future<void> _openAddSheet() async {
    final created = await showAddReminderSheet(context, repository: _repo);
    if (created != null && mounted) {
      setState(() => _reminders = [..._reminders, created]..sort(
          (a, b) => a.remindOn.compareTo(b.remindOn)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder set for “${created.title}” 🐼')),
      );
    }
  }

  // Dev helper: clears the onboarding flag and drops back into the flow from
  // the top, so onboarding can be re-tested without reinstalling the app.
  Future<void> _restartOnboarding() async {
    await const OnboardingStore().reset();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingGate(home: HomePage())),
      (route) => false,
    );
  }

  Future<void> _delete(Reminder r) async {
    setState(() => _reminders = _reminders.where((x) => x.id != r.id).toList());
    try {
      await _repo.delete(r.id);
    } catch (e) {
      if (mounted) {
        setState(() => _reminders = [..._reminders, r]..sort(
            (a, b) => a.remindOn.compareTo(b.remindOn)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t remove it: $e')),
        );
      }
    }
  }

  // Pip's mood is derived from the real list: something needing attention makes
  // Pip alert; an empty or all-clear list keeps Pip happy.
  PandaMood get _mood {
    if (_reminders.isEmpty) return PandaMood.happy;
    final needsAttention =
        _reminders.any((r) => r.isExpired || r.isDueSoon);
    return needsAttention ? PandaMood.excited : PandaMood.happy;
  }

  int get _attentionCount =>
      _reminders.where((r) => r.isExpired || r.isDueSoon).length;

  String get _greeting {
    if (_reminders.isEmpty) return 'Nothing to track yet';
    if (_attentionCount > 0) {
      return _attentionCount == 1
          ? '1 renewal needs your attention'
          : '$_attentionCount renewals need attention';
    }
    return "You're all caught up!";
  }

  String get _sub {
    if (_reminders.isEmpty) {
      return 'Tap ﹢ and Pip will remember your renewal dates for you 🎋';
    }
    if (_attentionCount > 0) return "Let's get them sorted before they lapse.";
    return 'Pip is keeping an eye on ${_reminders.length} '
        '${_reminders.length == 1 ? "renewal" : "renewals"} for you.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = _reminders.isEmpty && !_loading && _error == null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _Header(onAdd: _openAddSheet, onRestartOnboarding: _restartOnboarding),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _buildBody(context, isEmpty),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isEmpty) {
    if (_loading) {
      return ListView(
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return _ErrorState(error: _error!, onRetry: _load);
    }
    if (isEmpty) {
      return _EmptyState(
        mood: _mood,
        greeting: _greeting,
        sub: _sub,
        pokes: _pokes,
        onPokePanda: () => setState(() => _pokes++),
      );
    }
    return _ReminderListView(
      reminders: _reminders,
      mood: _mood,
      greeting: _greeting,
      sub: _sub,
      onPokePanda: () => setState(() => _pokes++),
      onDelete: _delete,
    );
  }
}

/// Full-screen hero shown when the list is empty — Pip front and centre.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.mood,
    required this.greeting,
    required this.sub,
    required this.pokes,
    required this.onPokePanda,
  });

  final PandaMood mood;
  final String greeting;
  final String sub;
  final int pokes;
  final VoidCallback onPokePanda;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: 24),
        PandaMascot(size: 240, mood: mood, onTap: onPokePanda),
        const SizedBox(height: 8),
        Text(
          'Pip',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (pokes > 0) ...[
                const SizedBox(height: 6),
                Text(
                  pokes == 1 ? 'Boop! 🐾' : 'Pip giggled ${pokes}x 🐾',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The populated state — a compact Pip banner above the reminders list.
class _ReminderListView extends StatelessWidget {
  const _ReminderListView({
    required this.reminders,
    required this.mood,
    required this.greeting,
    required this.sub,
    required this.onPokePanda,
    required this.onDelete,
  });

  final List<Reminder> reminders;
  final PandaMood mood;
  final String greeting;
  final String sub;
  final VoidCallback onPokePanda;
  final ValueChanged<Reminder> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        Row(
          children: [
            PandaMascot(size: 88, mood: mood, onTap: onPokePanda),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final r in reminders)
          ReminderCard(reminder: r, onDelete: () => onDelete(r)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off,
            size: 56, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(
          "Couldn't reach the server",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '$error',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd, required this.onRestartOnboarding});
  final VoidCallback onAdd;
  final VoidCallback onRestartOnboarding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Revolution',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
          ),
          Row(
            children: [
              // Dev-only: replay onboarding for testing.
              IconButton(
                onPressed: onRestartOnboarding,
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Restart onboarding',
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                tooltip: 'Add a reminder',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
