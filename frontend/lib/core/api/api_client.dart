import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to the Revolution backend (Railway), which is the ONLY store — tasks
/// live in Supabase via the API, never on the device.
///
/// Identity: the app GENERATES a uuid locally on first launch (works offline —
/// onboarding never waits on the network) and sends it as `X-User-Id` on every
/// request. The server materialises the anonymous account the first time it
/// sees the id. Phone login later CLAIMS that same uuid (see [claim]) — or, if
/// the phone already has an account, returns that account's id and the app
/// switches to it via [setUserId].
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://revolution-backend-production.up.railway.app',
  );

  /// v2: an app-generated uuid (schema v2). The old key held a 'dev-…' string
  /// or a phone number; both are obsolete with the fresh database.
  static const _userKey = 'user_id_v2';

  /// Every request is bounded by this — a cold/slow backend (Railway can be slow
  /// to wake) must never hang the UI. On timeout the call throws like any other
  /// API error, so callers' best-effort try/catch (login's claim/prefs, task
  /// commits) degrade gracefully instead of freezing.
  static const _timeout = Duration(seconds: 12);

  final http.Client _http = http.Client();
  String? _userId;

  /// Load (or generate) the account uuid. Call once at startup. Also nudges the
  /// server to materialise the row — fire-and-forget, because task writes
  /// self-heal (the backend upserts the user on first write anyway).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_userKey);
    if (id == null || id.isEmpty) {
      id = _uuidV4();
      await prefs.setString(_userKey, id);
    }
    _userId = id;
    unawaited(post('/users/ensure', const {}).catchError((_) => null));
  }

  /// The current account uuid (anonymous at first, canonical after login).
  String? get userId => _userId;

  /// Switch to a (possibly different) account uuid and persist it — called
  /// with the id [claim] returns.
  Future<void> setUserId(String id) async {
    _userId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, id);
  }

  /// Start a brand-new anonymous session (sign-out): generate a fresh uuid so
  /// the next user of this device can't see the previous account's data.
  Future<void> resetToAnonymous() async {
    await setUserId(_uuidV4());
    unawaited(post('/users/ensure', const {}).catchError((_) => null));
  }

  /// The pairing: attach this (anonymous) session to a verified phone. Runs
  /// UNDER the current anonymous id; the server either claims it in place or
  /// merges it into the phone's existing account. Returns the response map —
  /// the caller must [setUserId] to its `user_id`.
  Future<dynamic> claim({required String phone, String? name}) {
    return post('/claim', {
      'phone': phone,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // The canonical header + the legacy name, so either backend build works
        // during the transition.
        'X-User-Id': _userId ?? '',
        'X-Owner-Id': _userId ?? '',
      };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> get(String path) async {
    final res = await _http.get(_uri(path), headers: _headers).timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> post(String path, Object body) async {
    final res = await _http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> patch(String path, Object body) async {
    final res = await _http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> put(String path, Object body) async {
    final res = await _http
        .put(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res =
        await _http.delete(_uri(path), headers: _headers).timeout(_timeout);
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

  /// RFC-4122 v4 uuid from a cryptographic RNG — no package needed.
  static String _uuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}
