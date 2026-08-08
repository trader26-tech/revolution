import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';

/// Holds the signed-in state. The phone number IS the account: on login we set
/// it as the API owner id, so every request is scoped to that number, and we
/// remember it across launches until sign-out.
///
/// The number is proven by Firebase phone (OTP) verification before [login] is
/// called, so being logged-in is intentionally decoupled from persistence — see
/// [login] and the Firebase reconciliation in [load].
class AuthStore extends ChangeNotifier {
  AuthStore({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static final AuthStore instance = AuthStore();

  final ApiClient _api;
  static const _phoneKey = 'auth_phone_e164';
  static const _nameKey = 'auth_display_name';

  String? _phone;
  String? _name;

  /// The signed-in phone in E.164 (e.g. '+919876543210'), or null if logged out.
  String? get phone => _phone;

  /// The user's display name, captured on the onboarding finish screen. Null if
  /// never provided (older sessions, or sign-in that skipped onboarding).
  String? get name => _name;
  bool get isLoggedIn => _phone != null && _phone!.isNotEmpty;

  /// Restore a saved session and re-scope the API to it. Call at startup.
  ///
  /// Also RECONCILES with Firebase: verification can complete on Firebase's side
  /// while the app fails to finish persisting (e.g. killed on the reCAPTCHA
  /// return). Without reconciliation the app would think you're logged out while
  /// Firebase thinks you're in — the mismatch that showed an "internal error" on
  /// reopen. So if there's no saved session but Firebase still holds a verified
  /// phone, we adopt it and finish the login the app never got to.
  Future<void> load() async {
    String? phone;
    try {
      final prefs = await SharedPreferences.getInstance();
      phone = prefs.getString(_phoneKey);
      _name = prefs.getString(_nameKey);
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
      try {
        await _api.setOwnerId(phone);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Log in with a phone number: make it the account identity, persist it.
  ///
  /// [name] is the display name captured on the onboarding finish screen (null
  /// on sign-in paths that don't collect one — the existing value is then kept).
  ///
  /// The number is already Firebase-verified by the time we get here, so being
  /// logged-in must NOT hinge on any persistence/network call succeeding. We set
  /// the identity and notify FIRST (so the gate rebuilds into the app), then do
  /// every side effect best-effort — a flaky disk or network write can never
  /// throw out of here or leave the UI stuck between login and app.
  Future<void> login(String phoneE164, {String? name}) async {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) _name = trimmed;

    // The anonymous id the onboarding data was created under, captured BEFORE we
    // switch identity so we know what to re-key from.
    final anon = _api.ownerId;

    // ── Link the identity BEFORE flipping to the app ──────────────────────────
    // The gate rebuilds into Home the instant [notifyListeners] fires, and Home
    // immediately loads /tasks for the CURRENT owner. So we must switch the owner
    // to the phone AND run the claim (which creates the users record, writes
    // prefs with the name, and re-keys the onboarding tasks onto this account)
    // FIRST — otherwise Home's first load runs under the old id and comes back
    // empty, and the user's selections wouldn't appear until a manual refresh.
    //
    // Verification already proved the number, so none of this may THROW out of
    // login and strand the user: each step is best-effort. If the claim fails
    // (offline), we still log in — a later refresh reconciles.
    // Only re-key from a genuine anonymous session (the per-install "dev-…" id),
    // never from another phone. Captured before switching owner below.
    final anonToClaim =
        (anon != null && anon.startsWith('dev-') && anon != phoneE164)
            ? anon
            : '';
    try {
      await _api.setOwnerId(phoneE164); // scope every request to the account
    } catch (_) {}
    try {
      // Re-key the onboarding tasks (if any) and create/link the account record
      // + prefs. Runs even with no anon session so a plain login still creates
      // the users row.
      await _api.claim(
        anonOwnerId: anonToClaim,
        newOwnerId: phoneE164,
        name: _name,
      );
    } catch (_) {}

    _phone = phoneE164;
    notifyListeners(); // NOW flip to logged-in — Home's first load sees the data

    // Persist the session locally (best-effort, after the flip).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_phoneKey, phoneE164);
      if (_name != null && _name!.isNotEmpty) {
        await prefs.setString(_nameKey, _name!);
      }
    } catch (_) {}
  }

  /// Sign out — forget the number (data stays on the server under that number).
  Future<void> logout() async {
    _phone = null;
    _name = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneKey);
    await prefs.remove(_nameKey);
    notifyListeners();
  }
}
