import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../auth/data/auth_store.dart';
import '../auth/domain/country_code.dart';
import '../documents/data/documents_store.dart';
import '../onboarding/data/onboarding_store.dart';
import '../reminders/data/reminder_scheduler.dart';
import '../tasks/data/task_store.dart';
import '../update/data/update_service.dart';
import '../update/presentation/update_prompt.dart';
import 'data/profile_store.dart';
import 'presentation/sheets/edit_sheets.dart';
import 'presentation/widgets/settings_widgets.dart';

/// The Settings screen — deliberately tiny.
///
/// Only the essentials: your name, reminder alerts, an opt-in reminder call a
/// week before, and sign out. No avatar/logo, no version, no clutter.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.store});

  /// The task store — used by the "Reminders" screen to list what's scheduled.
  /// Optional so existing call sites keep compiling; the Reminders row only
  /// appears when it's provided.
  final TaskStore? store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = AuthStore.instance;
  final _profile = ProfileStore.instance;

  String _versionLabel = 'Version …';

  /// True while a test notification is being sent.
  bool _testingNotif = false;

  /// True while a manual reminders/documents sync is running (separate spinners).
  bool _syncingReminders = false;
  bool _syncingDocs = false;

  /// True while an update check is in flight.
  bool _checkingUpdate = false;

  /// Whether the OS currently allows notifications (null until first checked) —
  /// drives the button: "Allow" when off, "Send test" when on.
  bool? _notifAllowed;

  late final _LifecycleHook _lifecycleHook;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() =>
            _versionLabel = 'Version ${info.version} (${info.buildNumber})');
      }
    });
    _refreshNotifStatus();
    // Re-check when returning from system settings.
    _lifecycleHook = _LifecycleHook(_refreshNotifStatus);
    WidgetsBinding.instance.addObserver(_lifecycleHook);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleHook);
    super.dispose();
  }

  Future<void> _refreshNotifStatus() async {
    final allowed = await ReminderScheduler.instance.notificationsAllowed();
    if (mounted) setState(() => _notifAllowed = allowed);
  }

  /// Manual update check. Tells the user when they're already up to date.
  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    final info = await UpdateService.instance.check();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    if (info.available) {
      await showUpdatePrompt(context, info);
    } else {
      _toast("You're on the latest version");
    }
  }

  /// Manually refresh REMINDERS from the account. Reminders are always server-
  /// backed, so this just re-pulls the latest list from the store.
  Future<void> _syncReminders() async {
    if (_syncingReminders) return;
    setState(() => _syncingReminders = true);
    try {
      await widget.store?.load();
      if (mounted) _toast('Reminders up to date');
    } catch (_) {
      if (mounted) _toast("Couldn't sync — try again");
    } finally {
      if (mounted) setState(() => _syncingReminders = false);
    }
  }

  /// Manually push/pull DOCUMENTS now — uploads anything not yet backed up and
  /// pulls anything new. Uses a transient DocumentsStore (not otherwise held
  /// here); its syncWithCloud is a no-op when cloud backup is off.
  Future<void> _syncDocuments() async {
    if (_syncingDocs) return;
    setState(() => _syncingDocs = true);
    final docs = DocumentsStore();
    try {
      await docs.load(); // load() itself kicks a sync when backup is on
      await docs.syncWithCloud();
      if (mounted) _toast('Documents up to date');
    } catch (_) {
      if (mounted) _toast("Couldn't sync — try again");
    } finally {
      docs.dispose();
      if (mounted) setState(() => _syncingDocs = false);
    }
  }

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

  /// Permanently delete this account's data from the DATABASE and return to the
  /// very start (onboarding). Order matters: wipe the server row, sign out,
  /// forget onboarding — then the root gate rebuilds into the fresh intro.
  Future<void> _deleteData() async {
    final confirmed = await _confirm(
      title: 'Delete data & log off?',
      message:
          'This permanently deletes your account and all your reminders from '
          'our servers, and takes you back to the start. This can’t be undone.',
      confirmLabel: 'Delete everything',
      danger: true,
    );
    if (confirmed != true) return;

    // 1. HARD-delete the account + all tasks on the server (real DB wipe).
    await ApiClient.instance.deleteAccount();
    // 2. Forget the signed-in session.
    await _auth.logout();
    // 3. Reset onboarding → the root OnboardingGate rebuilds into the intro.
    await OnboardingStore.instance.reset();
    // 4. Unwind any screens on top so the fresh onboarding shows cleanly.
    if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  /// "8:00 AM" from minutes-since-midnight.
  String _formatMinutes(int minutes) {
    final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return t.format(context);
  }

  Future<void> _pickDefaultReminderTime() async {
    final current = TimeOfDay(
      hour: _profile.defaultReminderMin ~/ 60,
      minute: _profile.defaultReminderMin % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    await _profile.setDefaultReminderTime(picked.hour * 60 + picked.minute);
    if (mounted) _toast('Default reminder time set to ${picked.format(context)}');
  }

  /// Ask the OS for notification permission, then reflect the new state.
  Future<void> _allowNotifications() async {
    final granted = await ReminderScheduler.instance.requestPermission();
    if (!mounted) return;
    setState(() => _notifAllowed = granted);
    _toast(granted
        ? 'Notifications enabled — try a test'
        : 'Still off — enable Remora in system settings');
  }

  /// Fire a notification with TODAY's real digest and tell the user what
  /// happened. If permission got granted during send, reflect it.
  Future<void> _sendTestNotification() async {
    setState(() => _testingNotif = true);
    // Final backstop: the scheduler is already fully time-boxed, but never let
    // the spinner outlive a reasonable wait even if something upstream stalls.
    TestNotifResult result;
    try {
      result = await ReminderScheduler.instance
          .sendTestNotification()
          .timeout(const Duration(seconds: 75),
              onTimeout: () => TestNotifResult.failed);
    } catch (_) {
      result = TestNotifResult.failed;
    }
    if (!mounted) return;
    setState(() => _testingNotif = false);
    switch (result) {
      case TestNotifResult.sent:
        setState(() => _notifAllowed = true);
        _toast('Sent — check your notifications');
      case TestNotifResult.denied:
        setState(() => _notifAllowed = false);
        _toast('Notifications are off — tap “Allow” first');
      case TestNotifResult.unsupported:
        _toast('Notifications aren’t available on this device');
      case TestNotifResult.failed:
        _toast('Couldn’t send — please try again');
    }
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

          // --- CLOUD BACKUP ---
          // A master switch + SEPARATE manual sync for Reminders and Documents.
          // No permanent status text — tap a row's icon to reveal what it is.
          SettingsSection(
            title: 'Cloud backup',
            children: [
              SettingsSwitchTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Back up to the cloud',
                info: 'Keeps your reminders and documents saved to your account '
                    'and synced across your devices.',
                value: _profile.cloudBackup,
                onChanged: (v) => _profile.setCloudBackup(v),
              ),
              if (_profile.cloudBackup) ...[
                SettingsTile(
                  icon: Icons.event_note_rounded,
                  title: 'Sync reminders',
                  info: 'Reminders live in your account and sync across devices. '
                      'Tap to refresh now.',
                  showChevron: false,
                  trailing: _SyncAction(
                    busy: _syncingReminders,
                    onTap: _syncReminders,
                  ),
                ),
                SettingsTile(
                  icon: Icons.folder_outlined,
                  title: 'Sync documents',
                  info: 'Push documents not yet backed up and pull any new ones '
                      'from your account.',
                  showChevron: false,
                  trailing: _SyncAction(
                    busy: _syncingDocs,
                    onTap: _syncDocuments,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),

          // --- REMINDERS ---
          SettingsSection(
            title: 'Reminders',
            children: [
              SettingsSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                info: 'Get notified for each reminder at its time.',
                value: _profile.notifReminders,
                onChanged: (v) => _profile.setNotifReminders(v),
              ),
              if (_profile.notifReminders)
                SettingsTile(
                  icon: Icons.schedule_rounded,
                  title: 'Default reminder time',
                  info: 'Used when a reminder has no time of its own.',
                  value: _formatMinutes(_profile.defaultReminderMin),
                  onTap: _pickDefaultReminderTime,
                ),
              // Notification check — a right-aligned button that ALLOWS
              // notifications when they're off, or fires a test when they're on,
              // so the user can verify delivery.
              SettingsTile(
                icon: _notifAllowed == false
                    ? Icons.notifications_off_outlined
                    : Icons.notification_add_outlined,
                title: _notifAllowed == false
                    ? 'Notifications are off'
                    : 'Test notification',
                info: _notifAllowed == false
                    ? 'Allow notifications to receive your reminders.'
                    : 'Send one to this device right now to check delivery.',
                showChevron: false,
                trailing: _NotifButton(
                  allowed: _notifAllowed,
                  busy: _testingNotif,
                  onAllow: _allowNotifications,
                  onTest: _sendTestNotification,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- ABOUT ---
          SettingsSection(
            title: 'About',
            children: [
              SettingsTile(
                icon: Icons.system_update_rounded,
                title: 'Check for updates',
                info: _versionLabel,
                value: _checkingUpdate ? 'Checking…' : null,
                onTap: _checkingUpdate ? null : _checkForUpdate,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- SIGN OUT / DELETE DATA ---
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                danger: true,
                showChevron: false,
                onTap: _signOut,
              ),
              SettingsTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete data & log off',
                danger: true,
                showChevron: false,
                onTap: _deleteData,
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

/// A small right-aligned button for the notification row: "Allow" when
/// notifications are off, "Send test" when they're on, a spinner while sending.
/// A compact right-pinned "sync now" control for a cloud-backup row: a tappable
/// refresh glyph that becomes a spinner while syncing.
class _SyncAction extends StatelessWidget {
  const _SyncAction({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            strokeWidth: 2.2, color: AppColors.accent),
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.sync_rounded, color: AppColors.accent, size: 20),
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  const _NotifButton({
    required this.allowed,
    required this.busy,
    required this.onAllow,
    required this.onTest,
  });

  final bool? allowed;
  final bool busy;
  final VoidCallback onAllow;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accent),
      );
    }
    final off = allowed == false;
    return GestureDetector(
      onTap: off ? onAllow : onTest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentDeep],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          off ? 'Allow' : 'Send test',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Re-runs [onResume] each time the app returns to the foreground — used to
/// re-check notification permission after the user visits system settings.
class _LifecycleHook extends WidgetsBindingObserver {
  _LifecycleHook(this.onResume);
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
