import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to the Revolution backend (Railway), which is the ONLY store — tasks
/// live in Supabase via the API, never on the device.
///
/// Ownership: every request carries an `X-Owner-Id` header. Until phone login is
/// wired in, we use a stable per-install id (created once, kept in prefs) so a
/// user's data is still scoped to them. Swap this for the real user id later.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://revolution-backend-production.up.railway.app',
  );
  static const _ownerKey = 'owner_id_v1';

  final http.Client _http = http.Client();
  String? _ownerId;

  /// Load (or create) the stable owner id. Call once at startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_ownerKey);
    if (id == null || id.isEmpty) {
      // A simple unique-enough id for this install.
      id = 'dev-${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_ownerKey, id);
    }
    _ownerId = id;
  }

  /// The current owner id (the logged-in phone number, once set).
  String? get ownerId => _ownerId;

  /// Whether the current owner id is a per-install ANONYMOUS id (the
  /// "dev-<timestamp>" created before login) rather than a verified phone. Used
  /// to decide whether there's a session to claim on sign-in.
  bool get isAnonymousOwner => (_ownerId ?? '').startsWith('dev-');

  /// Set the owner id to the signed-in identity (the phone number) and persist
  /// it, so every request is scoped to that account.
  Future<void> setOwnerId(String id) async {
    _ownerId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerKey, id);
  }

  /// Re-key the anonymous session's data (tasks + prefs) onto the verified
  /// account. Called right after phone verification, BEFORE [setOwnerId]: the
  /// request goes out under the NEW verified id (header), carrying the old
  /// [anonOwnerId] to move rows from. Best-effort — the caller swallows errors
  /// so a flaky claim never blocks sign-in.
  Future<dynamic> claim({
    required String anonOwnerId,
    required String newOwnerId,
  }) async {
    final res = await _http.post(
      _uri('/claim'),
      headers: {
        'Content-Type': 'application/json',
        'X-Owner-Id': newOwnerId,
      },
      body: jsonEncode({'anon_owner_id': anonOwnerId}),
    );
    return _decode(res);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Owner-Id': _ownerId ?? 'demo-user',
      };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> get(String path) async {
    final res = await _http.get(_uri(path), headers: _headers);
    return _decode(res);
  }

  Future<dynamic> post(String path, Object body) async {
    final res = await _http.post(_uri(path),
        headers: _headers, body: jsonEncode(body));
    return _decode(res);
  }

  Future<dynamic> patch(String path, Object body) async {
    final res = await _http.patch(_uri(path),
        headers: _headers, body: jsonEncode(body));
    return _decode(res);
  }

  Future<dynamic> put(String path, Object body) async {
    final res = await _http.put(_uri(path),
        headers: _headers, body: jsonEncode(body));
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res = await _http.delete(_uri(path), headers: _headers);
    if (res.statusCode >= 300 && res.statusCode != 404) {
      throw ApiException(res.statusCode, res.body);
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}
