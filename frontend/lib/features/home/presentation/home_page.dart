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
import 'widgets/animated_flame.dart';

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
          reminders: reminders,
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

/// The home top bar: account avatar (left), Bobo in the centre (tap to expand),
/// and a frosted-glass "+" (right). Tapping Bobo opens a pill-shaped panel below
/// with what's pending and the upcoming list — no always-on streak counter.
class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.streak,
    required this.reminders,
    required this.onAdd,
    required this.onOpenAccount,
  });

  final StreakStatus streak;
  final List<Reminder> reminders;
  final VoidCallback onAdd;
  final VoidCallback onOpenAccount;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AccountAvatar(onTap: widget.onOpenAccount),
              Expanded(
                child: Center(
                  child: _BoboTapTarget(
                    mood: widget.streak.mood,
                    expanded: _expanded,
                    onTap: _toggle,
                  ),
                ),
              ),
              _GlassAddButton(onTap: widget.onAdd),
            ],
          ),
          // The expandable status panel — the "pill" that opens on tap.
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _StatusPanel(
                      streak: widget.streak,
                      reminders: widget.reminders,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Bobo in the centre, tappable. A soft chevron hints it opens.
class _BoboTapTarget extends StatelessWidget {
  const _BoboTapTarget({
    required this.mood,
    required this.expanded,
    required this.onTap,
  });

  final BoboMood mood;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BoboMascot(size: 72, mood: mood),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Bamboo.inkSoft,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill-shaped detail panel: a headline of what needs attention, then the
/// upcoming/pending list. Shown when the user taps Bobo.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.streak, required this.reminders});

  final StreakStatus streak;
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    // Pending = overdue first, then due-soon, then the rest — nearest first.
    final overdue = reminders.where((r) => r.isExpired).toList()
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
    final dueSoon = reminders
        .where((r) => r.isDueSoon && !r.isExpired)
        .toList()
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
    final pending = [...overdue, ...dueSoon];

    final broken = !streak.onStreak;
    final accent = broken ? const Color(0xFFC5643F) : Bamboo.greenDeep;

    final String headline;
    final String sub;
    if (reminders.isEmpty) {
      headline = 'Nothing to track yet';
      sub = 'Add a renewal and Bobo takes it from here.';
    } else if (overdue.isNotEmpty) {
      final n = overdue.length;
      headline = '$n thing${n == 1 ? '' : 's'} need${n == 1 ? 's' : ''} you';
      sub = 'Let’s clear ${n == 1 ? 'it' : 'them'} before it costs you.';
    } else if (dueSoon.isNotEmpty) {
      final n = dueSoon.length;
      headline = '$n coming up';
      sub = 'Nothing overdue — you’re ahead of it.';
    } else {
      headline = 'You’re all caught up';
      sub = 'Bobo’s watching ${reminders.length} '
          'renewal${reminders.length == 1 ? '' : 's'} for you.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Bamboo.brown.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedFlame(size: 22, lit: !broken),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Bamboo.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Bamboo.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Bamboo.cardBorder),
            const SizedBox(height: 10),
            for (final r in pending.take(6))
              _PendingRow(reminder: r, accent: accent),
          ],
        ],
      ),
    );
  }
}

/// One line in the pending list: a status dot, the title, and the timing.
class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.reminder, required this.accent});

  final Reminder reminder;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final days = reminder.daysUntilExpiry;
    final overdue = reminder.isExpired;
    final dotColor = overdue ? const Color(0xFFC5643F) : Bamboo.green;
    final timing = overdue
        ? (days == -1 ? 'Overdue by 1 day' : 'Overdue by ${-days} days')
        : (days == 0
            ? 'Due today'
            : days == 1
                ? 'In 1 day'
                : 'In $days days');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reminder.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Bamboo.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            timing,
            style: TextStyle(
              color: overdue ? const Color(0xFFC5643F) : Bamboo.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
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
