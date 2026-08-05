import 'package:flutter/material.dart';

import '../../../core/theme/bamboo_palette.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/presentation/onboarding_gate.dart';
import '../../mascot/presentation/bobo_mascot.dart';
import '../../reminders/data/reminders_repository.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/widgets/add_reminder_sheet.dart';
import '../../reminders/presentation/widgets/reminder_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.ownerId, this.onSignOut});

  /// The signed-in user's id — scopes all reminders to this account.
  final String ownerId;

  /// Signs the user out and returns to the phone-login screen.
  final VoidCallback? onSignOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _repo = RemindersRepository(ownerId: widget.ownerId);

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
      // Bobo celebrates a job done.
      _celebrate('Bobo’s got “${created.title}” 🎉');
    }
  }

  /// A brief celebration: Bobo appears celebrating, then fades. Used whenever
  /// the user completes something (adds a reminder). No zoom/pop — a plain fade.
  void _celebrate(String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'done',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, _, _) {
        return Center(
          child: FadeTransition(
            opacity: anim,
            child: _CelebrationCard(message: message),
          ),
        );
      },
    );
    // Auto-dismiss so it never blocks the user.
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  // Dev helper: clears the onboarding flag and drops back into the flow from
  // the top, so onboarding can be re-tested without reinstalling the app.
  Future<void> _restartOnboarding() async {
    await const OnboardingStore().reset();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OnboardingGate(
          home: HomePage(ownerId: widget.ownerId, onSignOut: widget.onSignOut),
        ),
      ),
      (route) => false,
    );
  }

  // Dev helper: opens a gallery of every Bobo mood so each PNG can be checked
  // at a glance, without having to trigger its real app condition.
  void _openMascotGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _MascotGalleryScreen()),
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in any time with your phone number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onSignOut?.call();
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

  int get _overdueCount => _reminders.where((r) => r.isExpired).length;
  int get _dueSoonCount =>
      _reminders.where((r) => r.isDueSoon && !r.isExpired).length;

  // Bobo's mood IS the app's status at a glance:
  //   • something overdue/forgotten → sad
  //   • a deadline very close        → scared (sweating)
  //   • calm, nothing pressing       → sleepy (relaxed)
  //   • empty / fresh start          → happy
  BoboMood get _mood {
    if (_reminders.isEmpty) return BoboMood.happy;
    if (_overdueCount > 0) return BoboMood.sad;
    if (_dueSoonCount > 0) return BoboMood.scared;
    return BoboMood.sleepy;
  }

  String get _greeting {
    if (_reminders.isEmpty) return 'Nothing to track yet';
    if (_overdueCount > 0) {
      return _overdueCount == 1
          ? 'You forgot 1 renewal'
          : 'You forgot $_overdueCount renewals';
    }
    if (_dueSoonCount > 0) {
      return _dueSoonCount == 1
          ? '1 deadline is closing in'
          : '$_dueSoonCount deadlines are closing in';
    }
    return "All calm — you're covered";
  }

  String get _sub {
    if (_reminders.isEmpty) {
      return 'Tap ﹢ and Bobo will remember your renewal dates for you 🦴';
    }
    if (_overdueCount > 0) return "Let's sort these before they cost you.";
    if (_dueSoonCount > 0) return 'Bobo is watching the clock on these.';
    return 'Bobo is keeping an eye on ${_reminders.length} '
        '${_reminders.length == 1 ? "renewal" : "renewals"} for you.';
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _reminders.isEmpty && !_loading && _error == null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Bamboo.mist, Bamboo.cream, Bamboo.creamHi],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _Header(
                onAdd: _openAddSheet,
                onRestartOnboarding: _restartOnboarding,
                onOpenMascotGallery: _openMascotGallery,
                onSignOut: widget.onSignOut == null ? null : _confirmSignOut,
              ),
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
        onPokeBobo: () => setState(() => _pokes++),
      );
    }
    return _ReminderListView(
      reminders: _reminders,
      mood: _mood,
      greeting: _greeting,
      sub: _sub,
      onPokeBobo: () => setState(() => _pokes++),
      onDelete: _delete,
    );
  }
}

/// Full-screen hero shown when the list is empty — Bobo front and centre.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.mood,
    required this.greeting,
    required this.sub,
    required this.pokes,
    required this.onPokeBobo,
  });

  final BoboMood mood;
  final String greeting;
  final String sub;
  final int pokes;
  final VoidCallback onPokeBobo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Centre the whole hero in the available space and scroll only if a very
    // short screen can't fit it — so Bobo and the text never overlap.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BoboMascot(size: 160, mood: mood, onTap: onPokeBobo),
                  const SizedBox(height: 24),
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                  if (pokes > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      pokes == 1 ? 'Boop! 🐾' : 'Bobo giggled ${pokes}x 🐾',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The populated state — a compact Bobo banner above the reminders list.
class _ReminderListView extends StatelessWidget {
  const _ReminderListView({
    required this.reminders,
    required this.mood,
    required this.greeting,
    required this.sub,
    required this.onPokeBobo,
    required this.onDelete,
  });

  final List<Reminder> reminders;
  final BoboMood mood;
  final String greeting;
  final String sub;
  final VoidCallback onPokeBobo;
  final ValueChanged<Reminder> onDelete;

  // Bobo's hero size is CONSTANT across devices so the layout never balloons on
  // a tall screen. The PNG already carries its own transparent padding, so we
  // crop that empty margin here to kill the wasted space above/below.
  static const double _heroSize = 200;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        // Crop the PNG's built-in transparent margin so Bobo reads bigger in a
        // smaller footprint — no dead space around him.
        Center(
          child: ClipRect(
            child: Align(
              alignment: Alignment.center,
              heightFactor: 0.80, // trim ~10% top + ~10% bottom padding
              child: BoboMascot(size: _heroSize, mood: mood, onTap: onPokeBobo),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          greeting,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 20),
        for (final r in reminders)
          ReminderCard(reminder: r, onDelete: () => onDelete(r)),
      ],
    );
  }
}

/// A small floating card with a celebrating Bobo, shown briefly on success.
/// Dev-only gallery: a big Bobo you can flip through every mood with, plus a
/// grid to jump straight to any one. Lets each PNG be verified without having
/// to reproduce its real trigger (overdue reminder, etc.).
class _MascotGalleryScreen extends StatefulWidget {
  const _MascotGalleryScreen();

  @override
  State<_MascotGalleryScreen> createState() => _MascotGalleryScreenState();
}

class _MascotGalleryScreenState extends State<_MascotGalleryScreen> {
  int _index = 0;

  static const _labels = {
    BoboMood.happy: 'happy',
    BoboMood.sleepy: 'sleepy (relaxed)',
    BoboMood.scared: 'scared (deadline close)',
    BoboMood.sad: 'sad (forgotten)',
    BoboMood.writing: 'writing (adding)',
    BoboMood.celebrating: 'celebrating (done)',
    BoboMood.waving: 'waving (welcome)',
    BoboMood.excited: 'excited',
  };

  List<BoboMood> get _moods => _labels.keys.toList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mood = _moods[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('Bobo moods')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: BoboMascot(
                  key: ValueKey(mood), // rebuild so the PNG re-resolves
                  size: 260,
                  mood: mood,
                ),
              ),
            ),
            Text(
              _labels[mood]!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a chip to preview · missing art shows the drawn Bobo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _moods.length; i++)
                    ChoiceChip(
                      label: Text(_moods[i].name),
                      selected: i == _index,
                      onSelected: (_) => setState(() => _index = i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BoboMascot(size: 150, mood: BoboMood.celebrating),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
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
  const _Header({
    required this.onAdd,
    required this.onRestartOnboarding,
    required this.onOpenMascotGallery,
    this.onSignOut,
  });
  final VoidCallback onAdd;
  final VoidCallback onRestartOnboarding;
  final VoidCallback onOpenMascotGallery;
  final VoidCallback? onSignOut;

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
              if (onSignOut != null)
                IconButton(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                ),
              // Dev-only: preview every Bobo mood/PNG at a glance.
              IconButton(
                onPressed: onOpenMascotGallery,
                icon: const Icon(Icons.pets),
                tooltip: 'Preview Bobo moods',
              ),
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
