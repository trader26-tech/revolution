import 'package:flutter/material.dart';

import '../../../core/theme/bamboo_palette.dart';
import '../../mascot/presentation/bobo_mascot.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/domain/streak.dart';
import '../../reminders/presentation/reminders_controller.dart';
import '../../reminders/presentation/widgets/add_reminder_sheet.dart';
import '../../reminders/presentation/widgets/reminder_card.dart';

/// The Home (reminders) tab.
///
/// A big Bobo hero — sized to ~50% of the screen height in a FIXED box so his
/// footprint never changes when the mood image swaps — sits above the status
/// line and the reminders list. Reads the shared [RemindersController], so Bobo
/// and the streak stay in sync with the Calendar tab.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final RemindersController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _HomeView(controller: controller),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.controller});

  final RemindersController controller;

  Future<void> _openAddSheet(BuildContext context) async {
    // The sheet creates the reminder via the repository; we then fold it into
    // the shared controller so Home and Calendar both update.
    final created = await showAddReminderSheet(
      context,
      repository: controller.repository,
    );
    if (created != null) {
      controller.addCreated(created);
      if (context.mounted) {
        _celebrate(context, 'Bobo’s got “${created.title}” 🎉');
      }
    }
  }

  Future<void> _delete(BuildContext context, Reminder r) async {
    try {
      await controller.delete(r);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't remove it: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminders = controller.reminders;
    final streak = controller.streak;
    final isEmpty =
        reminders.isEmpty && !controller.loading && controller.error == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Bamboo.mist, Bamboo.cream, Bamboo.creamHi],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: _buildBody(context, isEmpty, reminders, streak),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isEmpty,
    List<Reminder> reminders,
    StreakStatus streak,
  ) {
    if (controller.loading) {
      return ListView(
        children: const [
          SizedBox(height: 260),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (controller.error != null) {
      return _ErrorState(error: controller.error!, onRetry: controller.load);
    }

    // The hero box is a fixed fraction of screen height — same footprint for
    // every mood. Below it: status text, then either the empty hint or the list.
    final screenH = MediaQuery.of(context).size.height;
    final heroH = screenH * 0.42; // ~50% of the usable area above the nav

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      children: [
        _TopBar(onAdd: () => _openAddSheet(context)),
        _BoboHero(height: heroH, mood: streak.mood),
        const SizedBox(height: 8),
        _StatusBlock(streak: streak, reminderCount: reminders.length),
        const SizedBox(height: 20),
        if (isEmpty)
          const _EmptyHint()
        else
          for (final r in reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReminderCard(
                reminder: r,
                member: controller.memberFor(r),
                onDelete: () => _delete(context, r),
              ),
            ),
      ],
    );
  }
}

/// A tidy top bar: the app name + a clean "add" button. Replaces the floating
/// action button, which collided with the bottom nav.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Revolution',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Bamboo.ink,
                ),
          ),
          Material(
            color: Bamboo.green,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed-height, fixed-width Bobo hero. The box never resizes across moods; the
/// PNG is centred inside with `contain`, so every pose reads at the same size.
class _BoboHero extends StatelessWidget {
  const _BoboHero({required this.height, required this.mood});

  final double height;
  final BoboMood mood;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        // Bobo is sized off the box height so he's a consistent share of it.
        child: BoboMascot(size: height * 0.94, mood: mood),
      ),
    );
  }
}

/// One clean status line under Bobo — a single calm phrase that says where the
/// user stands. No chips, no stacked headings: just one line, so the screen
/// reads quiet and uncluttered.
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.streak, required this.reminderCount});

  final StreakStatus streak;
  final int reminderCount;

  String get _line {
    if (reminderCount == 0) return 'Never miss a renewal again';
    if (streak.overdueCount > 0) {
      return streak.overdueCount == 1
          ? '1 renewal needs you'
          : '${streak.overdueCount} renewals need you';
    }
    if (streak.dueSoonCount > 0) {
      return streak.dueSoonCount == 1
          ? '1 renewal coming up'
          : '${streak.dueSoonCount} renewals coming up';
    }
    return "You're all caught up";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _line,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Bamboo.inkSoft,
            letterSpacing: 0.1,
          ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Bamboo.cardBorder),
      ),
      child: Column(
        children: [
          const Text('🦴', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            'Tap “Add reminder” to get started',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Bamboo.inkSoft,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 180),
        const Center(child: Icon(Icons.cloud_off_rounded, size: 56)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "Couldn't reach the server",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
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

/// A small floating card with a celebrating Bobo, shown briefly on success.
void _celebrate(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'done',
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, _) => Center(
      child: FadeTransition(
        opacity: anim,
        child: _CelebrationCard(message: message),
      ),
    ),
  );
  // Auto-dismiss. Capture the navigator up front so we don't touch a possibly
  // unmounted context after the delay.
  Future<void>.delayed(const Duration(milliseconds: 1600), () {
    if (navigator.canPop()) navigator.pop();
  });
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: Bamboo.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Bamboo.brown.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 12),
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
                    color: Bamboo.ink,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
