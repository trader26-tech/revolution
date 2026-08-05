import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/data/auth_store.dart';

/// The Settings screen — pushed from the Home top bar.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _signOut(BuildContext context) async {
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
    if (ok == true) {
      await AuthStore.instance.logout();
      // The AuthGate reacts to the store and shows login; pop back to it.
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = AuthStore.instance.phone;
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
        children: [
          if (phone != null) _AccountCard(phone: phone),
          if (phone != null) const SizedBox(height: 16),
          const _SettingTile(icon: Icons.notifications_none_rounded, label: 'Notifications'),
          const _SettingTile(icon: Icons.info_outline_rounded, label: 'About'),
          const SizedBox(height: 16),
          _SettingTile(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            danger: true,
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}

/// A card showing the signed-in phone number.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Signed in as',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                const SizedBox(height: 2),
                Text(phone,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE5484D);
    final color = danger ? red : AppColors.accent;
    final textColor = danger ? red : AppColors.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        trailing: danger
            ? null
            : const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        onTap: onTap ?? () {},
      ),
    );
  }
}
