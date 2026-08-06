import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../auth/data/auth_store.dart';
import '../auth/domain/country_code.dart';
import 'data/profile_store.dart';
import 'presentation/sheets/edit_sheets.dart';
import 'presentation/widgets/settings_widgets.dart';

/// The Settings screen — deliberately tiny.
///
/// Only the essentials: your name, reminder alerts, an opt-in reminder call a
/// week before, and sign out. No avatar/logo, no version, no clutter.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = AuthStore.instance;
  final _profile = ProfileStore.instance;

  Future<void> _editName() async {
    final name = await showEditNameSheet(context, initial: _profile.name);
    if (name != null) {
      await _profile.setName(name);
      _toast('Name saved');
    }
  }

  Future<void> _signOut() async {
    final confirmed = await _confirm(
      title: 'Sign out?',
      message:
          'Your reminders stay safe under your number. You can sign back in '
          'anytime to see them again.',
      confirmLabel: 'Sign out',
      danger: true,
    );
    if (confirmed != true) return;
    await _auth.logout();
    if (mounted) Navigator.of(context).pop(); // AuthGate shows login
  }

  void _toast(String message) => AppToast.show(context, message: message);

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(message,
            style: const TextStyle(height: 1.4, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626))
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_auth, _profile]),
            builder: (context, _) => CustomScrollView(
              slivers: [
                const SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: BackButton(color: AppColors.ink),
                  title: Text(
                    'Settings',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  centerTitle: false,
                ),
                SliverToBoxAdapter(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- YOU ---
          SettingsSection(
            title: 'You',
            children: [
              SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Name',
                value: _profile.hasName ? _profile.name : 'Add your name',
                onTap: _editName,
              ),
              SettingsTile(
                icon: Icons.phone_iphone_rounded,
                title: 'Phone number',
                value: _formatPhone(_auth.phone),
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- REMINDERS ---
          SettingsSection(
            title: 'Reminders',
            children: [
              SettingsSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Reminder alerts',
                subtitle: 'Get notified before things are due',
                value: _profile.notifReminders,
                onChanged: (v) => _profile.setNotifReminders(v),
              ),
              SettingsSwitchTile(
                icon: Icons.call_outlined,
                title: 'Call me to remind',
                subtitle: "We'll call you one week before",
                value: _profile.callReminder,
                onChanged: (v) => _profile.setCallReminder(v),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- SIGN OUT ---
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                danger: true,
                showChevron: false,
                onTap: _signOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Present an E.164 number a touch more readably: '+91 98765 43210'.
  String _formatPhone(String? e164) {
    if (e164 == null || e164.isEmpty) return '—';
    final split = splitE164(e164);
    final n = split.national;
    if (n.length >= 10) {
      final head = n.substring(0, n.length - 5);
      final tail = n.substring(n.length - 5);
      return '${split.country.dial} $head $tail';
    }
    return '${split.country.dial} $n';
  }
}
