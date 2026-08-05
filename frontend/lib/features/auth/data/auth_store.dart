import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in session, persisted on-device.
///
/// Holds the authenticated user's id (used as `X-Owner-Id` on every request)
/// and their phone number. Presence of a userId == "logged in".
class AuthSession {
  const AuthSession({required this.userId, required this.phone});

  final String userId;
  final String phone;
}

class AuthStore {
  const AuthStore();

  static const _kUserId = 'auth_user_id_v1';
  static const _kPhone = 'auth_phone_v1';

  Future<AuthSession?> current() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kUserId);
    final phone = prefs.getString(_kPhone);
    if (id == null || id.isEmpty) return null;
    return AuthSession(userId: id, phone: phone ?? '');
  }

  Future<void> save(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, session.userId);
    await prefs.setString(_kPhone, session.phone);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kPhone);
  }
}
