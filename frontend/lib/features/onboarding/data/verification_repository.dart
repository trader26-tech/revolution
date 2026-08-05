import '../../../core/network/api_client.dart';
import '../domain/phone_verification.dart';

/// Talks to the FastAPI phone-verification endpoints.
///
/// Ownership is carried by the `X-Owner-Id` header, matching the rest of the
/// API. Swap the placeholder id for the real user id once auth lands.
class VerificationRepository {
  VerificationRepository({ApiClient? api, String? ownerId})
      : _api = api ?? ApiClient(),
        _ownerId = ownerId ?? _placeholderOwnerId;

  final ApiClient _api;
  final String _ownerId;

  // TODO(auth): replace with the authenticated user's id.
  static const String _placeholderOwnerId = 'demo-user';

  Map<String, String> get _ownerHeader => {'X-Owner-Id': _ownerId};

  /// Start a verification. `region` interprets numbers typed without a
  /// country code (e.g. 'IN', 'KW').
  Future<VerificationStart> start(String phone, {String region = 'IN'}) async {
    final json = await _api.post(
      '/phone/verify/start',
      body: {'phone': phone, 'region': region},
      headers: _ownerHeader,
    );
    return VerificationStart.fromJson(json as Map<String, dynamic>);
  }

  Future<VerificationState> status(String id) async {
    final json = await _api.get('/phone/verify/$id', headers: _ownerHeader);
    return VerificationState.fromJson(json as Map<String, dynamic>);
  }
}
