import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _kCurrency = 'profile_currency'; // ISO code (INR/USD/KWD)
  static const _kLeadDays = 'profile_lead_days';
  static const _kNotifReminders = 'profile_notif_reminders';
  static const _kNotifEmail = 'profile_notif_email';
  static const _kNotifWhatsapp = 'profile_notif_whatsapp';
  static const _kCallReminder = 'profile_call_reminder';
  static const _kQuietEnabled = 'profile_quiet_enabled';
  static const _kQuietStart = 'profile_quiet_start_min'; // minutes since midnight
  static const _kQuietEnd = 'profile_quiet_end_min';
  static const _kWeekStartMon = 'profile_week_start_mon';

  // --- state (with sensible defaults) ---
  String _name = '';
  String _currency = 'INR';
  int _leadDays = 30;
  bool _notifReminders = true;
  bool _notifEmail = false;
  bool _notifWhatsapp = true;
  bool _callReminder = false; // opt-in: a phone call one week before
  bool _quietEnabled = false;
  int _quietStartMin = 22 * 60; // 10:00 PM
  int _quietEndMin = 7 * 60; //  7:00 AM
  bool _weekStartMon = true;

  // --- getters ---
  String get name => _name;
  bool get hasName => _name.trim().isNotEmpty;
  String get currency => _currency;
  int get leadDays => _leadDays;
  bool get notifReminders => _notifReminders;
  bool get notifEmail => _notifEmail;
  bool get notifWhatsapp => _notifWhatsapp;
  bool get callReminder => _callReminder;
  bool get quietEnabled => _quietEnabled;
  int get quietStartMin => _quietStartMin;
  int get quietEndMin => _quietEndMin;
  bool get weekStartMon => _weekStartMon;

  /// Load persisted preferences. Call once at startup.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    _name = p.getString(_kName) ?? '';
    _currency = p.getString(_kCurrency) ?? 'INR';
    _leadDays = p.getInt(_kLeadDays) ?? 30;
    _notifReminders = p.getBool(_kNotifReminders) ?? true;
    _notifEmail = p.getBool(_kNotifEmail) ?? false;
    _notifWhatsapp = p.getBool(_kNotifWhatsapp) ?? true;
    _callReminder = p.getBool(_kCallReminder) ?? false;
    _quietEnabled = p.getBool(_kQuietEnabled) ?? false;
    _quietStartMin = p.getInt(_kQuietStart) ?? (22 * 60);
    _quietEndMin = p.getInt(_kQuietEnd) ?? (7 * 60);
    _weekStartMon = p.getBool(_kWeekStartMon) ?? true;
    notifyListeners();
  }

  // --- setters (each persists + notifies) ---
  Future<void> setName(String value) async {
    _name = value.trim();
    await _persist((p) => p.setString(_kName, _name));
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
