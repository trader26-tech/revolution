import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The App Lock session model: whether the lock is on, how long a session stays
/// unlocked, and the current unlock deadline.
///
/// The lock is a FIXED countdown from the moment of unlock — not idle-based. On a
/// successful biometric/PIN unlock we stamp [_unlockedUntilMs] = now + duration.
/// While `now < unlockedUntil` the app is open; past it, the gate locks and
/// requires auth again. A [Ticker]-free design: the gate + the on-screen ring
/// each run their own 1s timer off [unlockedUntil], so this store holds only the
/// durable facts and notifies when they change.
///
/// Persisted so the choice survives relaunch. The unlock DEADLINE is intentionally
/// NOT persisted across a full process death — a cold start always re-locks (the
/// safe default); the deadline only governs the live session and background/
/// resume within one process lifetime.
class AppLockStore extends ChangeNotifier {
  AppLockStore({SharedPreferences? prefs}) : _prefs = prefs;

  static final AppLockStore instance = AppLockStore();

  SharedPreferences? _prefs;

  static const _kEnabled = 'app_lock_enabled';
  static const _kMinutes = 'app_lock_minutes';

  /// Duration presets offered in the picker (minutes). Manual entry allows any
  /// value in [_minMinutes].._maxMinutes.
  static const List<int> presets = [1, 5, 10, 30, 60];
  static const int minMinutes = 1;
  static const int maxMinutes = 240;

  // Default ON, 10-minute session.
  bool _enabled = true;
  int _minutes = 10;

  /// Epoch-ms at which the current unlocked session expires. 0 = locked (no live
  /// session). Not persisted — a cold launch starts locked.
  int _unlockedUntilMs = 0;

  bool get enabled => _enabled;
  int get minutes => _minutes;
  Duration get sessionLength => Duration(minutes: _minutes);

  /// The moment the current session locks, or null if not currently unlocked.
  DateTime? get unlockedUntil =>
      _unlockedUntilMs == 0 ? null : DateTime.fromMillisecondsSinceEpoch(_unlockedUntilMs);

  /// Whether the app should be showing the lock screen right now: lock is on AND
  /// there's no live (future) unlock deadline.
  bool isLockedAt(DateTime now) {
    if (!_enabled) return false;
    return now.millisecondsSinceEpoch >= _unlockedUntilMs;
  }

  /// Remaining time in the current session (zero if locked/expired).
  Duration remainingAt(DateTime now) {
    final ms = _unlockedUntilMs - now.millisecondsSinceEpoch;
    return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    _enabled = p.getBool(_kEnabled) ?? true;
    _minutes = (p.getInt(_kMinutes) ?? 10).clamp(minMinutes, maxMinutes);
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    // Turning the lock ON should NOT instantly lock the user out of the screen
    // they're on — start a fresh session so they stay in until it expires.
    // Turning it OFF clears any deadline.
    if (v) {
      _unlockedUntilMs =
          DateTime.now().millisecondsSinceEpoch + sessionLength.inMilliseconds;
    } else {
      _unlockedUntilMs = 0;
    }
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_kEnabled, v);
    notifyListeners();
  }

  /// Change the auto-lock duration. If a session is live, extend/adjust it to the
  /// new length from NOW so the change takes effect immediately (the ring
  /// visibly jumps to the new time).
  Future<void> setMinutes(int m) async {
    _minutes = m.clamp(minMinutes, maxMinutes);
    if (_unlockedUntilMs != 0) {
      _unlockedUntilMs =
          DateTime.now().millisecondsSinceEpoch + sessionLength.inMilliseconds;
    }
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_kMinutes, _minutes);
    notifyListeners();
  }

  /// Begin a fresh unlocked session (called after a successful auth). Stamps the
  /// deadline at now + the chosen duration.
  void startSession() {
    _unlockedUntilMs =
        DateTime.now().millisecondsSinceEpoch + sessionLength.inMilliseconds;
    notifyListeners();
  }

  /// Lock immediately — the "Lock now" action. Clears the deadline so the gate
  /// shows the lock screen at once.
  void lockNow() {
    _unlockedUntilMs = 0;
    notifyListeners();
  }
}
