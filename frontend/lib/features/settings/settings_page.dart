import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The Settings screen — pushed from the Home top bar. Minimal placeholder for
/// the fresh template; real settings rows get added here.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        leading: const BackButton(color: AppColors.ink),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SettingTile(icon: Icons.person_outline, label: 'Profile'),
          _SettingTile(icon: Icons.notifications_none_rounded, label: 'Notifications'),
          _SettingTile(icon: Icons.info_outline_rounded, label: 'About'),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.ink)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        onTap: () {},
      ),
    );
  }
}
