import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../settings/data/profile_store.dart';

/// Holds the signed-in state.
///
/// Identity model (schema v2): the app runs under an app-generated uuid from
/// second zero (see [ApiClient.init]) — every onboarding task is saved against
/// it immediately. Phone login PAIRS that uuid with the verified number via
/// /claim: the server either claims the same uuid or, if the phone already has
/// an account, moves this session's data onto it and returns that account's
/// id. Either way the app keeps using ONE uuid and the home screen is a single
/// indexed fetch — nothing re-keys mid-flight.
///
/// The number is proven by Firebase phone (OTP) verification before [login] is
/// called, so being logged-in is intentionally decoupled from persistence.
class AuthStore extends ChangeNotifier {
  AuthStore({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static final AuthStore instance = AuthStore();

  final ApiClient _api;
  static const _phoneKey = 'auth_phone_e164';
  static const _nameKey = 'auth_display_name';
  static const _claimedKey = 'auth_claimed_v2';

  String? _phone;
  String? _name;

  /// Whether the server-side pairing (/claim) has succeeded for this login.
  /// False after an offline login — [load] retries on the next launch.
  bool _claimed = false;

  /// The signed-in phone in E.164 (e.g. '+919876543210'), or null if logged out.
  String? get phone => _phone;

  /// The user's display name, captured on the onboarding finish screen. Null if
  /// never provided (older sessions, or sign-in that skipped onboarding).
  String? get name => _name;
  bool get isLoggedIn => _phone != null && _phone!.isNotEmpty;

  /// Whether the server pairing (/claim) has completed for this session — i.e.
  /// the app is now using the CANONICAL account uuid. Cloud restore should wait
  /// for this (a restore run before the claim lists the wrong/anonymous account
  /// and comes back empty).
  bool get isClaimed => _claimed;

  /// Restore a saved session. Call at startup (after [ApiClient.init], which
  /// restores the account uuid itself).
  ///
  /// Also RECONCILES with Firebase: verification can complete on Firebase's
  /// side while the app fails to finish persisting (e.g. killed on the
  /// reCAPTCHA return). If there's no saved session but Firebase still holds a
  /// verified phone, we adopt it and finish the login the app never got to.
  /// And if a previous login couldn't reach the server, the pairing is retried
  /// here, best-effort.
  Future<void> load() async {
    String? phone;
    try {
      final prefs = await SharedPreferences.getInstance();
      phone = prefs.getString(_phoneKey);
      _name = prefs.getString(_nameKey);
      _claimed = prefs.getBool(_claimedKey) ?? false;
    } catch (_) {}

    // No app session? Fall back to Firebase's verified user, if any.
    if (phone == null || phone.isEmpty) {
      try {
        final fbPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
        if (fbPhone != null && fbPhone.isNotEmpty) {
          // Adopt it AND persist so future launches are consistent.
          await login(fbPhone);
          return;
        }
      } catch (_) {
        // Firebase not ready / no user — just stay logged out.
      }
    }

    if (phone != null && phone.isNotEmpty) {
      _phone = phone;
      // A previous login that couldn't reach the server left the pairing
      // pending — retry quietly; the account uuid may switch on success.
      if (!_claimed) await _tryClaim();
    }
    notifyListeners();
  }

  /// Log in with a verified phone number.
  ///
  /// [name] is the display name captured on the onboarding finish screen (null
  /// on sign-in paths that don't collect one — the existing value is kept).
  ///
  /// The number is already Firebase-verified by the time we get here, so being
  /// logged-in must NOT hinge on any network call succeeding: the pairing runs
  /// first (so Home's first fetch sees the account's data), but if it fails —
  /// offline, cold backend — we still log in under the anonymous uuid. The
  /// user keeps seeing everything they created; [load] retries the pairing on
  /// the next launch.
  Future<void> login(String phoneE164, {String? name}) async {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) _name = trimmed;

    _phone = phoneE164;
    await _tryClaim();

    notifyListeners(); // flip to logged-in — Home's first load sees the data

    // Persist the session locally (best-effort, after the flip).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_phoneKey, phoneE164);
      if (_name != null && _name!.isNotEmpty) {
        await prefs.setString(_nameKey, _name!);
      }
    } catch (_) {}
  }

  /// Run the server pairing for the current phone. On success the app switches
  /// to the canonical account uuid (may differ from the anonymous one when the
  /// phone already had an account). Never throws.
  Future<void> _tryClaim() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) return;
    try {
      final res = await _api.claim(phone: phone, name: _name);
      final canonical = (res is Map) ? res['user_id'] as String? : null;
      if (canonical != null &&
          canonical.isNotEmpty &&
          canonical != _api.userId) {
        await _api.setUserId(canonical);
      }
      // Hydrate the display name from the account when we don't have one locally
      // (e.g. a returning user on a fresh install). If the server returns the
      // stored name in the claim response, adopt it — so the name that was saved
      // at sign-up comes back instead of showing empty. No-op if the backend
      // doesn't return a name yet.
      if (res is Map && (_name == null || _name!.trim().isEmpty)) {
        final serverName = (res['name'] as String?)?.trim();
        if (serverName != null && serverName.isNotEmpty) {
          _name = serverName;
          // Keep the profile store (the Settings/Home display name) in step.
          unawaited(ProfileStore.instance.setName(serverName));
        }
      }
      _claimed = true;
    } catch (_) {
      _claimed = false; // offline — retried on next launch
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claimedKey, _claimed);
    } catch (_) {}
    // Announce the claim result so listeners keyed on the CANONICAL account
    // (e.g. DocumentsStore's cloud restore) can run now that the real uuid is in
    // place — the claim often lands a beat AFTER login flips isLoggedIn true.
    notifyListeners();
  }

  /// Sign out — forget the number and start a FRESH anonymous session, so the
  /// next person on this device can't see this account's data. The account's
  /// data stays safe on the server under the phone.
  Future<void> logout() async {
    _phone = null;
    _name = null;
    _claimed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_phoneKey);
      await prefs.remove(_nameKey);
      await prefs.remove(_claimedKey);
    } catch (_) {}
    // CRITICAL: sign out of Firebase too. Otherwise Firebase keeps this device's
    // verified phone, and the next [load] (finding no local session) falls back
    // to `FirebaseAuth.currentUser.phoneNumber` and silently logs the user right
    // back in — the "I signed out but I'm still signed in after a restart" bug.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await _api.resetToAnonymous();
    } catch (_) {}
    notifyListeners();
  }
}
