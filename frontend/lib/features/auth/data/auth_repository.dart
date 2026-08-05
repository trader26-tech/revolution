import '../../../core/network/api_client.dart';
import 'auth_store.dart';

/// Result of a phone login: the session plus whether the account is brand new.
class LoginResult {
  const LoginResult({required this.session, required this.isNew});

  final AuthSession session;
  final bool isNew;
}

/// Phone-number login against the backend.
///
/// `POST /auth/phone` finds or creates the account for a number and returns its
/// user id. We persist that id and use it as `X-Owner-Id` everywhere, so each
/// phone number is its own account with its own data.
class AuthRepository {
  AuthRepository({ApiClient? api, AuthStore? store})
      : _api = api ?? ApiClient(),
        _store = store ?? const AuthStore();

  final ApiClient _api;
  final AuthStore _store;

  Future<LoginResult> loginWithPhone(String phone) async {
    final json = await _api.post('/auth/phone', body: {'phone': phone});
    final map = json as Map<String, dynamic>;
    final session = AuthSession(
      userId: map['user_id'] as String,
      phone: map['phone'] as String,
    );
    await _store.save(session);
    return LoginResult(
      session: session,
      isNew: map['is_new'] as bool? ?? false,
    );
  }

  Future<AuthSession?> currentSession() => _store.current();

  Future<void> signOut() => _store.clear();
}
