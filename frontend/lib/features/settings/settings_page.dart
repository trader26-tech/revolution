import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../auth/data/auth_store.dart';
import '../auth/domain/country_code.dart';
import '../details/domain/currency.dart';
import '../options/data/options_store.dart';
import '../options/presentation/option_picker_sheet.dart';
import 'data/profile_store.dart';
import 'presentation/sheets/edit_sheets.dart';
import 'presentation/widgets/settings_widgets.dart';

/// The Settings screen — a single, fully-detailed page.
///
/// Everything lives inline here (no nested Profile/Notifications sub-pages): the
/// profile header, account, preferences, notifications, your lists, data & sync,
/// support, and the sign-out. Each row shows its current value and edits in
/// place via a bottom sheet, so the user can see and change everything at once.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = AuthStore.instance;
  final _profile = ProfileStore.instance;
  final _options = OptionsStore.instance;

  // --- lead-time presets ---
  static const _leadOptions = <ChoiceOption<int>>[
    ChoiceOption(value: 7, label: '1 week before'),
    ChoiceOption(value: 14, label: '2 weeks before'),
    ChoiceOption(value: 30, label: '1 month before'),
    ChoiceOption(value: 60, label: '2 months before'),
    ChoiceOption(value: 90, label: '3 months before'),
  ];

  String _leadLabel(int days) {
    for (final o in _leadOptions) {
      if (o.value == days) return o.label;
    }
    return '$days days before';
  }

  Future<void> _editName() async {
    final name = await showEditNameSheet(context, initial: _profile.name);
    if (name != null) {
      await _profile.setName(name);
      _toast('Name saved');
    }
  }

  Future<void> _editPhone() async {
    final phone = await showEditPhoneSheet(context, initialE164: _auth.phone);
    if (phone == null || phone == _auth.phone) return;
    final confirmed = await _confirm(
      title: 'Change phone number?',
      message:
          'Your account is tied to your number. Switching to $phone will show '
          'the reminders saved under that number.',
      confirmLabel: 'Change',
    );
    if (confirmed != true) return;
    await _auth.login(phone); // re-scopes the API owner id + persists
    _toast('Phone number updated');
  }

  Future<void> _editLeadTime() async {
    final days = await showChoiceSheet<int>(
      context,
      title: 'Default reminder time',
      options: _leadOptions,
      selected: _profile.leadDays,
    );
    if (days != null) {
      await _profile.setLeadDays(days);
      _toast('Default set to ${_leadLabel(days)}');
    }
  }

  Future<void> _editCurrency() async {
    final code = await showChoiceSheet<String>(
      context,
      title: 'Currency',
      options: [
        for (final c in kCurrencies)
          ChoiceOption(
              value: c.code, label: '${c.symbol}  ${c.label}', detail: c.code),
      ],
      selected: _profile.currency,
    );
    if (code != null) {
      await _profile.setCurrency(code);
      _toast('Currency set to $code');
    }
  }

  Future<void> _editQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: _minToTime(_profile.quietStartMin),
      helpText: 'Quiet hours — start',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _minToTime(_profile.quietEndMin),
      helpText: 'Quiet hours — end',
    );
    if (end == null) return;
    await _profile.setQuietHours(
      startMin: start.hour * 60 + start.minute,
      endMin: end.hour * 60 + end.minute,
    );
    _toast('Quiet hours updated');
  }

  Future<void> _manage(OptionKind kind) async {
    // The picker doubles as a manager: it lists everything and lets the user
    // add new entries. Selection is ignored here — we just open it to view/add.
    await showOptionPicker(context, store: _options, kind: kind, current: '');
    setState(() {}); // refresh counts
  }

  Future<void> _signOut() async {
    final confirmed = await _confirm(
      title: 'Sign out?',
      message:
          'Your reminders stay safe on the server under your number. You can '
          'sign back in anytime to see them again.',
      confirmLabel: 'Sign out',
      danger: true,
    );
    if (confirmed != true) return;
    await _auth.logout();
    if (mounted) Navigator.of(context).pop(); // AuthGate shows login
  }

  // --- helpers ---

  TimeOfDay _minToTime(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);

  String _fmtTime(int m) => _minToTime(m).format(context);

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
                ? FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626))
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
            // Rebuild when any of the three sources change.
            animation: Listenable.merge([_auth, _profile, _options]),
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
    final leadLabel = _leadLabel(_profile.leadDays);
    final currency = currencyOf(_profile.currency);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileHeader(
            name: _profile.name,
            phone: _formatPhone(_auth.phone),
            onEditName: _editName,
          ),
          const SizedBox(height: 24),

          // --- ACCOUNT ---
          SettingsSection(
            title: 'Account',
            children: [
              SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Name',
                value: _profile.hasName ? _profile.name : 'Add',
                onTap: _editName,
              ),
              SettingsTile(
                icon: Icons.phone_iphone_rounded,
                title: 'Phone number',
                subtitle: 'Your account identity',
                value: _formatPhone(_auth.phone),
                onTap: _editPhone,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- PREFERENCES ---
          SettingsSection(
            title: 'Preferences',
            footnote:
                'Defaults applied to new reminders. You can still change each '
                'reminder individually.',
            children: [
              SettingsTile(
                icon: Icons.alarm_rounded,
                title: 'Default reminder time',
                subtitle: 'When to remind you before a due date',
                value: leadLabel,
                onTap: _editLeadTime,
              ),
              SettingsTile(
                icon: Icons.payments_outlined,
                title: 'Currency',
                value: '${currency.symbol} ${currency.code}',
                onTap: _editCurrency,
              ),
              SettingsSwitchTile(
                icon: Icons.calendar_view_week_rounded,
                title: 'Start week on Monday',
                subtitle: _profile.weekStartMon ? 'Monday' : 'Sunday',
                value: _profile.weekStartMon,
                onChanged: (v) => _profile.setWeekStartMon(v),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- NOTIFICATIONS ---
          SettingsSection(
            title: 'Notifications',
            children: [
              SettingsSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Reminder alerts',
                subtitle: 'Get notified before things are due',
                value: _profile.notifReminders,
                onChanged: (v) => _profile.setNotifReminders(v),
              ),
              SettingsSwitchTile(
                icon: Icons.chat_outlined,
                title: 'WhatsApp reminders',
                subtitle: 'Send reminders to your number',
                value: _profile.notifWhatsapp,
                onChanged: (v) => _profile.setNotifWhatsapp(v),
              ),
              SettingsSwitchTile(
                icon: Icons.mail_outline_rounded,
                title: 'Email reminders',
                value: _profile.notifEmail,
                onChanged: (v) => _profile.setNotifEmail(v),
              ),
              SettingsSwitchTile(
                icon: Icons.bedtime_outlined,
                title: 'Quiet hours',
                subtitle: _profile.quietEnabled
                    ? '${_fmtTime(_profile.quietStartMin)} – ${_fmtTime(_profile.quietEndMin)}'
                    : 'Pause alerts overnight',
                value: _profile.quietEnabled,
                onChanged: (v) => _profile.setQuietEnabled(v),
              ),
              if (_profile.quietEnabled)
                SettingsTile(
                  icon: Icons.schedule_rounded,
                  title: 'Quiet hours window',
                  value:
                      '${_fmtTime(_profile.quietStartMin)} – ${_fmtTime(_profile.quietEndMin)}',
                  onTap: _editQuietHours,
                ),
            ],
          ),
          const SizedBox(height: 22),

          // --- YOUR LISTS ---
          SettingsSection(
            title: 'Your lists',
            footnote: 'Customise the lists, categories and payment methods you '
                'can tag reminders with.',
            children: [
              SettingsTile(
                icon: Icons.folder_outlined,
                title: 'Lists',
                value: '${_options.optionsFor(OptionKind.list).length}',
                onTap: () => _manage(OptionKind.list),
              ),
              SettingsTile(
                icon: Icons.sell_outlined,
                title: 'Categories',
                value: '${_options.optionsFor(OptionKind.category).length}',
                onTap: () => _manage(OptionKind.category),
              ),
              SettingsTile(
                icon: Icons.credit_card_rounded,
                title: 'Payment methods',
                value:
                    '${_options.optionsFor(OptionKind.paymentMethod).length}',
                onTap: () => _manage(OptionKind.paymentMethod),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- DATA & SYNC ---
          SettingsSection(
            title: 'Data & sync',
            children: [
              const SettingsTile(
                icon: Icons.cloud_done_outlined,
                title: 'Cloud sync',
                subtitle: 'Everything is saved to the cloud under your number',
                trailing: _SyncedBadge(),
                showChevron: false,
              ),
              SettingsTile(
                icon: Icons.devices_rounded,
                title: 'Owner id',
                subtitle: 'Used to scope your data on the server',
                value: _auth.phone ?? '—',
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- SUPPORT & ABOUT ---
          SettingsSection(
            title: 'Support & about',
            children: [
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ',
                onTap: () => _toast('Help is coming soon'),
              ),
              SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Privacy policy',
                onTap: () => _toast('Opening privacy policy…'),
              ),
              SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of service',
                onTap: () => _toast('Opening terms…'),
              ),
              SettingsTile(
                icon: Icons.star_outline_rounded,
                title: 'Rate Revolution',
                onTap: () => _toast('Thanks for the love!'),
              ),
              const SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Version',
                value: '1.0.0',
                showChevron: false,
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
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Made with care · Revolution',
              style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  /// Present an E.164 number a touch more readably: '+91 98765 43210'.
  String _formatPhone(String? e164) {
    if (e164 == null || e164.isEmpty) return '';
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

/// The big profile header: avatar with initials, name, phone.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.phone,
    required this.onEditName,
  });

  final String name;
  final String phone;
  final VoidCallback onEditName;

  String get _initials {
    final n = name.trim();
    if (n.isNotEmpty) {
      final parts = n.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return (parts.first[0] + parts[1][0]).toUpperCase();
      }
      return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
    }
    // Fall back to the last two digits of the phone.
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return '🙂';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.accentDeep],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isNotEmpty ? name : 'Add your name',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: name.trim().isNotEmpty
                        ? AppColors.ink
                        : AppColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phone.isNotEmpty ? phone : 'No number',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditName,
            icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
            tooltip: 'Edit name',
          ),
        ],
      ),
    );
  }
}

class _SyncedBadge extends StatelessWidget {
  const _SyncedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
          SizedBox(width: 5),
          Text(
            'Synced',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}
