import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../calendar/calendar_page.dart';
import '../home/home_page.dart';
import '../tasks/data/task_store.dart';

/// The app shell: two tabs (Home, Calendar) behind a floating glass nav.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  // One shared task store so Home and Calendar stay in sync.
  final _store = TaskStore();

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
      bottomNavigationBar: _GlassNav(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
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
