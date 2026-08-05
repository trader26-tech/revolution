import 'package:flutter/material.dart';

import '../../../core/theme/bamboo_palette.dart';
import '../../account/presentation/account_page.dart';
import '../../calendar/presentation/calendar_page.dart';
import '../../home/presentation/home_page.dart';
import '../../reminders/data/reminders_repository.dart';
import '../../reminders/presentation/reminders_controller.dart';

/// The signed-in app shell: three tabs behind a floating bottom nav.
///
///   0 · Home     — Bobo + the reminders list (the reminders page)
///   1 · Calendar — a month view of renewal due-dates + streak
///   2 · Account  — profile / settings (owned by another agent)
///
/// Owns the shared [RemindersController] so Bobo, the streak, and the data
/// stay in sync across Home and Calendar and load only once.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.ownerId, this.onSignOut});

  final String ownerId;
  final VoidCallback? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final RemindersController _controller = RemindersController(
    repository: RemindersRepository(ownerId: widget.ownerId),
  );

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(controller: _controller),
      CalendarPage(controller: _controller),
      AccountPage(
        ownerId: widget.ownerId,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      extendBody: true, // let the cream gradient flow under the floating bar
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _FloatingNav(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// A pill-shaped floating nav with exactly three destinations.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = <({IconData icon, IconData active, String label})>[
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.calendar_today_outlined,
      active: Icons.calendar_month_rounded,
      label: 'Calendar'
    ),
    (
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Account'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Bamboo.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Bamboo.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Bamboo.brown.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 18 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Bamboo.green.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.active : item.icon,
                size: 24,
                color: selected ? Bamboo.greenDeep : Bamboo.inkSoft,
              ),
              // Label only for the selected tab — keeps the bar clean.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: Bamboo.greenDeep,
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
