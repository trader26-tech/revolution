import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';

/// Holds the signed-in state. The phone number IS the account: on login we set
/// it as the API owner id, so every request is scoped to that number, and we
/// remember it across launches until sign-out.
///
/// There's no real verification yet (no OTP/backend auth) — logging in simply
/// takes the number at face value and drops the user into the app.
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
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_phoneKey);
    if (saved != null && saved.isNotEmpty) {
      _phone = saved;
      await _api.setOwnerId(saved);
    }
    notifyListeners();
  }

  /// Log in with a phone number: make it the account identity, persist it.
  Future<void> login(String phoneE164) async {
    _phone = phoneE164;
    await _api.setOwnerId(phoneE164);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phoneE164);
    notifyListeners();
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
