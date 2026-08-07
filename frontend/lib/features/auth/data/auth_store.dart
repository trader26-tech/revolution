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

  String? _phone;

  /// The signed-in phone in E.164 (e.g. '+919876543210'), or null if logged out.
  String? get phone => _phone;
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
  /// The number is already Firebase-verified by the time we get here, so being
  /// logged-in must NOT hinge on any persistence/network call succeeding. We set
  /// the identity and notify FIRST (so the gate rebuilds into the app), then do
  /// every side effect best-effort — a flaky disk or network write can never
  /// throw out of here or leave the UI stuck between login and app.
  Future<void> login(String phoneE164) async {
    _phone = phoneE164;
    notifyListeners(); // flip to logged-in immediately

    try {
      await _api.setOwnerId(phoneE164);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_phoneKey, phoneE164);
    } catch (_) {}
    // Register the user's phone + default "call me to remind" (on) on the
    // server, so the weekly digest can reach them. Best-effort.
    try {
      await _api.put('/prefs', {'phone': phoneE164, 'call_reminder': true});
    } catch (_) {}
  }

  /// Sign out — forget the number (data stays on the server under that number).
  Future<void> logout() async {
    _phone = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneKey);
    notifyListeners();
  }
}
