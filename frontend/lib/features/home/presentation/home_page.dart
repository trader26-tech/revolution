import 'package:flutter/material.dart';

import 'dart:ui';

import '../../../core/theme/bamboo_palette.dart';
import '../../account/presentation/account_page.dart';
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
  const HomePage({
    super.key,
    required this.controller,
    required this.ownerId,
    this.onSignOut,
  });

  final RemindersController controller;
  final String ownerId;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _HomeView(
        controller: controller,
        ownerId: ownerId,
        onSignOut: onSignOut,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.controller,
    required this.ownerId,
    this.onSignOut,
  });

  final RemindersController controller;
  final String ownerId;
  final VoidCallback? onSignOut;

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      children: [
        _TopBar(
          streak: streak,
          onAdd: () => _openAddSheet(context),
          onOpenAccount: () => _openAccount(context),
        ),
        const SizedBox(height: 16),
        _StatusBlock(streak: streak, reminderCount: reminders.length),
        const SizedBox(height: 20),
        if (isEmpty)
          _EmptyHint(onAdd: () => _openAddSheet(context))
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

  Future<void> _openAccount(BuildContext context) {
    // Account was a nav tab (a bare page with no back button). Now that it's
    // pushed from the avatar, wrap it in a Scaffold with a back-enabled bar so
    // the user can always return home.
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Bamboo.cream,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: Bamboo.ink),
          ),
          body: AccountPage(ownerId: ownerId, onSignOut: onSignOut),
        ),
      ),
    );
  }
}

/// The home top bar, CultFit-style: a circular account avatar on the left, a
/// Bobo + streak pill in the centre, and a frosted-glass "+" on the right.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.streak,
    required this.onAdd,
    required this.onOpenAccount,
  });

  final StreakStatus streak;
  final VoidCallback onAdd;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Row(
        children: [
          _AccountAvatar(onTap: onOpenAccount),
          const SizedBox(width: 12),
          Expanded(child: Center(child: _StreakPill(streak: streak))),
          const SizedBox(width: 12),
          _GlassAddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

/// The account entry — a circular avatar with a soft ring, like the reference.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Bamboo.green.withValues(alpha: 0.14),
          border: Border.all(color: Bamboo.green.withValues(alpha: 0.55), width: 2),
        ),
        child: const Icon(Icons.person_rounded, color: Bamboo.greenDeep, size: 24),
      ),
    );
  }
}

/// The centre streak chip — CultFit-style: a flame + "N day streak" inside a
/// pill, with Bobo zoomed in and peeking off the right edge so he reads clearly
/// instead of being a tiny dot.
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});
  final StreakStatus streak;

  /// Big number + "day streak", like Cult's "0 day streak".
  int get _days => streak.onStreak ? (streak.streakDays < 0 ? 0 : streak.streakDays) : 0;

  @override
  Widget build(BuildContext context) {
    final broken = !streak.onStreak;
    final accent = broken ? const Color(0xFFE07A5F) : Bamboo.greenDeep;
    final glow = broken ? const Color(0xFFE07A5F) : Bamboo.green;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        // The pill. Extra right padding leaves room for Bobo's overhang.
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 52, 8),
          decoration: BoxDecoration(
            color: Bamboo.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 7),
              Text(
                '$_days day streak',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        // Bobo, zoomed in, peeking off the right edge of the pill.
        Positioned(
          right: -22,
          top: -14,
          bottom: -14,
          child: BoboMascot(size: 62, mood: streak.mood),
        ),
      ],
    );
  }
}

/// The frosted-glass "+" — the Orbit-style add button.
class _GlassAddButton extends StatelessWidget {
  const _GlassAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Bamboo.card.withValues(alpha: 0.55),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Bamboo.brown.withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Bamboo.greenDeep, size: 26),
          ),
        ),
      ),
    );
  }
}

/// One clean status line under the top bar — a single calm phrase that says where the
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

/// Shown when there are no reminders — a friendly Bobo and a clear add CTA now
/// that the big hero is gone from the top of the screen.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const BoboMascot(size: 150, mood: BoboMood.happy),
          const SizedBox(height: 20),
          Text(
            'Nothing to track yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Bamboo.ink,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first renewal and Bobo takes it from here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Bamboo.inkSoft,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add reminder'),
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
