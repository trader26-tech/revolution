import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../calendar/calendar_page.dart';
import '../home/home_page.dart';
import '../reminders/data/reminder_scheduler.dart';
import '../tasks/data/task_store.dart';

/// The app shell: two tabs (Home, Calendar) behind a floating glass nav.
///
/// The shell renders IMMEDIATELY — verified or not — so the user sees their
/// (cached) tasks the instant the app opens, instead of a login wall. When
/// [verified] is false, a slim "verify to save & sync" banner sits above the
/// nav; tapping it runs [onVerify] to start the OTP flow.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.verified = true, this.onVerify});

  /// Whether the session is phone-verified. When false, the verify banner shows.
  final bool verified;

  /// Starts the phone-verification flow (opens the OTP sheet). Null hides the
  /// banner regardless of [verified] (e.g. previews).
  final VoidCallback? onVerify;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  // One shared task store so Home and Calendar stay in sync.
  final _store = TaskStore();

  @override
  void initState() {
    super.initState();
    // Restore saved tasks (and their icons) from on-device storage.
    _store.load();
    // The user is past onboarding and inside the app — the right moment to
    // ask for notification permission (Android 13+ / iOS prompt).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReminderScheduler.instance.ensurePermissions();
    });
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(store: _store),
      CalendarPage(store: _store),
    ];

    final showVerify = !widget.verified && widget.onVerify != null;

    return Scaffold(
      extendBody: true, // let the background flow under the floating nav
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: IndexedStack(index: _tab, children: pages),
      ),
      // Nav + (when unverified) the verify banner, stacked so the banner sits
      // just above the floating glass pill.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showVerify) _VerifyBanner(onVerify: widget.onVerify!),
          _GlassNav(
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ],
      ),
    );
  }
}

/// The slim "you're browsing, verify to keep it" prompt shown above the nav
/// until the user verifies their phone. Premium, one tap, non-blocking.
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.onVerify});

  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onVerify,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A few steps to lock this in',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Verify your number to save & sync everywhere',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Verify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A floating frosted-glass pill with exactly two destinations.
class _GlassNav extends StatelessWidget {
  const _GlassNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = <({IconData icon, IconData active, String label})>[
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.calendar_today_outlined,
      active: Icons.calendar_month_rounded,
      label: 'Calendar',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
        child: GlassPanel(
          borderRadius: 999,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _items[i],
                      selected: i == index,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData active, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.active : item.icon,
                size: 24,
                color: selected ? AppColors.accentDeep : AppColors.inkSoft,
              ),
              // Show the label only for the selected tab — keeps the bar clean.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: AppColors.accentDeep,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
