import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/auth_store.dart';

/// Holds the user's personal preferences shown on the Settings page.
///
/// The phone number is the account identity and lives in [AuthStore]; this store
/// holds everything *around* it — display name, notification choices, default
/// reminder lead time, currency, and quiet hours — persisted on-device.
///
/// Persistence is isolated in [load]/[_persist] so this can move to a
/// server-backed profile later without changing any UI. Kept as a singleton so
/// any screen can read profile prefs without prop-drilling.
class ProfileStore extends ChangeNotifier {
  ProfileStore({SharedPreferences? prefs}) : _prefs = prefs;

  static final ProfileStore instance = ProfileStore();

  SharedPreferences? _prefs;

  // --- keys ---
  static const _kName = 'profile_name';
  static const _kAvatarPath = 'profile_avatar_path'; // on-device image path
  static const _kCurrency = 'profile_currency'; // ISO code (INR/USD/KWD)
  static const _kLeadDays = 'profile_lead_days';
  static const _kNotifReminders = 'profile_notif_reminders';
  static const _kDigestTime = 'profile_digest_time_min'; // minutes since midnight
  static const _kDefaultReminder = 'profile_default_reminder_min';
  static const _kNotifEmail = 'profile_notif_email';
  static const _kNotifWhatsapp = 'profile_notif_whatsapp';
  static const _kCallReminder = 'profile_call_reminder';
  static const _kQuietEnabled = 'profile_quiet_enabled';
  static const _kQuietStart = 'profile_quiet_start_min'; // minutes since midnight
  static const _kQuietEnd = 'profile_quiet_end_min';
  static const _kWeekStartMon = 'profile_week_start_mon';
  static const _kCloudBackup = 'profile_cloud_backup';

  // --- state (with sensible defaults) ---
  String _name = '';
  String? _avatarPath; // absolute path to the user's photo on this device
  String _currency = 'INR';
  int _leadDays = 30;
  bool _notifReminders = true;
  int _digestTimeMin = 8 * 60; // 8:00 AM — when the one daily summary fires
  // The time a reminder fires when its task has NO specific time set — most
  // reminders are date-only, so this is the default alert time. 8:30 AM local.
  int _defaultReminderMin = 8 * 60 + 30;
  bool _notifEmail = false;
  bool _notifWhatsapp = true;
  bool _callReminder = true; // ON by default: a weekly WhatsApp call reminder
  bool _quietEnabled = false;
  int _quietStartMin = 22 * 60; // 10:00 PM
  int _quietEndMin = 7 * 60; //  7:00 AM
  bool _weekStartMon = true;
  // ON by default: keep everything backed up to the account in the cloud.
  // Reminders are already always server-backed; when the standalone Documents
  // library gains a server endpoint, this flag also drives their upload. When
  // OFF, data stays on this device where it can (documents), and the user has
  // opted out of cloud backup for anything optional.
  bool _cloudBackup = true;

  // --- getters ---
  String get name => _name;
  bool get hasName => _name.trim().isNotEmpty;

  /// The user's photo path on this device (null = none set / file missing).
  String? get avatarPath => _avatarPath;
  bool get hasAvatar => _avatarPath != null;
  String get currency => _currency;
  int get leadDays => _leadDays;
  bool get notifReminders => _notifReminders;
  int get digestTimeMin => _digestTimeMin;
  int get defaultReminderMin => _defaultReminderMin;
  bool get notifEmail => _notifEmail;
  bool get notifWhatsapp => _notifWhatsapp;
  bool get callReminder => _callReminder;
  bool get quietEnabled => _quietEnabled;
  int get quietStartMin => _quietStartMin;
  int get quietEndMin => _quietEndMin;
  bool get weekStartMon => _weekStartMon;
  bool get cloudBackup => _cloudBackup;

  /// Load persisted preferences. Call once at startup.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    _name = p.getString(_kName) ?? '';
    // Avatar: drop the stored path if the file no longer exists on disk.
    final storedAvatar = p.getString(_kAvatarPath);
    _avatarPath = (storedAvatar != null && File(storedAvatar).existsSync())
        ? storedAvatar
        : null;
    _currency = p.getString(_kCurrency) ?? 'INR';
    _leadDays = p.getInt(_kLeadDays) ?? 30;
    _notifReminders = p.getBool(_kNotifReminders) ?? true;
    _digestTimeMin = p.getInt(_kDigestTime) ?? (8 * 60);
    _defaultReminderMin = p.getInt(_kDefaultReminder) ?? (8 * 60 + 30);
    _notifEmail = p.getBool(_kNotifEmail) ?? false;
    _notifWhatsapp = p.getBool(_kNotifWhatsapp) ?? true;
    _callReminder = p.getBool(_kCallReminder) ?? true;
    _quietEnabled = p.getBool(_kQuietEnabled) ?? false;
    _quietStartMin = p.getInt(_kQuietStart) ?? (22 * 60);
    _quietEndMin = p.getInt(_kQuietEnd) ?? (7 * 60);
    _weekStartMon = p.getBool(_kWeekStartMon) ?? true;
    _cloudBackup = p.getBool(_kCloudBackup) ?? true;
    notifyListeners();
  }

  // --- setters (each persists + notifies) ---
  Future<void> setName(String value) async {
    _name = value.trim();
    await _persist((p) => p.setString(_kName, _name));
  }

  /// Set the user's photo from a picked file. The source is COPIED into the app's
  /// documents dir (a stable, private location that survives cache clears — the
  /// same pattern the documents feature uses), then the path is persisted. Pass
  /// null to remove the photo. Fully on-device; nothing is uploaded.
  Future<void> setAvatarFromPath(String? sourcePath) async {
    // Remove.
    if (sourcePath == null) {
      final old = _avatarPath;
      _avatarPath = null;
      await _persist((p) => p.remove(_kAvatarPath));
      _deleteQuietly(old);
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
      // A single stable filename per profile; overwrite on change.
      final dest = '${dir.path}/profile_avatar.$ext';
      final old = _avatarPath;
      await File(sourcePath).copy(dest);
      _avatarPath = dest;
      await _persist((p) => p.setString(_kAvatarPath, dest));
      // Clean up a previous file with a different extension.
      if (old != null && old != dest) _deleteQuietly(old);
    } catch (_) {
      // Non-fatal — leave the existing photo unchanged.
    }
  }

  void _deleteQuietly(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Future<void> setCurrency(String code) async {
    _currency = code;
    await _persist((p) => p.setString(_kCurrency, code));
  }

  Future<void> setLeadDays(int days) async {
    _leadDays = days;
    await _persist((p) => p.setInt(_kLeadDays, days));
  }

  Future<void> setNotifReminders(bool v) async {
    _notifReminders = v;
    await _persist((p) => p.setBool(_kNotifReminders, v));
  }

  /// Turn cloud backup on/off. Reminders are always server-backed regardless;
  /// this flag governs optional backup (documents, once a server endpoint exists)
  /// and records the user's intent so uploads follow it as they come online.
  Future<void> setCloudBackup(bool v) async {
    _cloudBackup = v;
    await _persist((p) => p.setBool(_kCloudBackup, v));
  }

  Future<void> setDigestTime(int minutesSinceMidnight) async {
    _digestTimeMin = minutesSinceMidnight;
    await _persist((p) => p.setInt(_kDigestTime, minutesSinceMidnight));
  }

  Future<void> setDefaultReminderTime(int minutesSinceMidnight) async {
    _defaultReminderMin = minutesSinceMidnight;
    await _persist((p) => p.setInt(_kDefaultReminder, minutesSinceMidnight));
  }

  Future<void> setNotifEmail(bool v) async {
    _notifEmail = v;
    await _persist((p) => p.setBool(_kNotifEmail, v));
  }

  Future<void> setNotifWhatsapp(bool v) async {
    _notifWhatsapp = v;
    await _persist((p) => p.setBool(_kNotifWhatsapp, v));
  }

  Future<void> setCallReminder(bool v) async {
    _callReminder = v;
    await _persist((p) => p.setBool(_kCallReminder, v));
    // Sync to the server so the weekly digest knows who to call.
    await syncCallReminderToServer();
  }

  /// Push the user's phone + call-reminder choice to the server (best-effort),
  /// so the operator's weekly digest can list who to WhatsApp-call. Call this on
  /// login and whenever the toggle changes.
  Future<void> syncCallReminderToServer() async {
    try {
      await ApiClient.instance.put('/prefs', {
        'phone': AuthStore.instance.phone,
        'call_reminder': _callReminder,
      });
    } catch (_) {
      // Non-fatal — retried next time it changes.
    }
  }

  Future<void> setQuietEnabled(bool v) async {
    _quietEnabled = v;
    await _persist((p) => p.setBool(_kQuietEnabled, v));
  }

  Future<void> setQuietHours({required int startMin, required int endMin}) async {
    _quietStartMin = startMin;
    _quietEndMin = endMin;
    await _persist((p) async {
      await p.setInt(_kQuietStart, startMin);
      await p.setInt(_kQuietEnd, endMin);
    });
  }

  Future<void> setWeekStartMon(bool v) async {
    _weekStartMon = v;
    await _persist((p) => p.setBool(_kWeekStartMon, v));
  }

  Future<void> _persist(Future<void> Function(SharedPreferences p) write) async {
    _prefs ??= await SharedPreferences.getInstance();
    await write(_prefs!);
    notifyListeners();
  }
}
