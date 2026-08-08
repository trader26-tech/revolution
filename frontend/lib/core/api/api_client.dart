import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to the Revolution backend (Railway), which is the ONLY store — tasks
/// live in Supabase via the API, never on the device.
///
/// Identity: the SERVER mints the account uuid (the database primary key). On
/// first launch the app calls `POST /users/anonymous`, stores the returned id,
/// and sends it as `X-User-Id` on every request. Phone login later CLAIMS that
/// account (see [claim]) — or, if the phone already has an account, returns
/// that account's id and the app switches to it via [setUserId]. If minting
/// fails at startup (offline / cold backend), every API call lazily retries it
/// first, so the moment the network is back the app has its identity.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://revolution-backend-production.up.railway.app',
  );

  /// v2: the server-minted account uuid (schema v2). The old key held a
  /// 'dev-…' string or a phone number; both are obsolete with the fresh DB.
  static const _userKey = 'user_id_v2';

  /// Every request is bounded by this — a cold/slow backend (Railway can be
  /// slow to wake) must never hang the UI. On timeout the call throws like any
  /// other API error, so callers' best-effort try/catch degrade gracefully.
  static const _timeout = Duration(seconds: 12);

  final http.Client _http = http.Client();
  String? _userId;

  /// The single in-flight mint, so parallel callers never create two accounts.
  Future<String>? _minting;

  /// Load the stored account id. Call once at startup — NEVER blocks on the
  /// network: if there's no id yet, minting starts in the background and every
  /// API call also ensures it before running.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_userKey);
    if (_userId == null || _userId!.isEmpty) {
      unawaited(_mintAnonymous().catchError((_) => ''));
    }
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

  /// Start a brand-new anonymous session (sign-out): forget this account and
  /// mint a fresh server-side one, so the next person on this device can't see
  /// the previous account's data. Minting is lazy-retried if offline.
  Future<void> resetToAnonymous() async {
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    unawaited(_mintAnonymous().catchError((_) => ''));
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

  /// Ask the SERVER to mint a new anonymous account and adopt its id.
  /// Memoised while in flight so concurrent calls share one mint.
  Future<String> _mintAnonymous() {
    return _minting ??= () async {
      try {
        final res = await _http
            .post(
              _uri('/users/anonymous'),
              headers: const {'Content-Type': 'application/json'},
            )
            .timeout(_timeout);
        final body = _decode(res) as Map<String, dynamic>;
        final id = body['user_id'] as String;
        await setUserId(id);
        return id;
      } finally {
        _minting = null; // allow a retry after failure
      }
    }();
  }

  /// Guarantee we have an identity before any scoped request goes out.
  Future<void> _ensureId() async {
    if (_userId != null && _userId!.isNotEmpty) return;
    await _mintAnonymous();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // The canonical header + the legacy name, so either backend build
        // works during the transition.
        'X-User-Id': _userId ?? '',
        'X-Owner-Id': _userId ?? '',
      };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> get(String path) async {
    await _ensureId();
    final res =
        await _http.get(_uri(path), headers: _headers).timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> post(String path, Object body) async {
    await _ensureId();
    final res = await _http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> patch(String path, Object body) async {
    await _ensureId();
    final res = await _http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> put(String path, Object body) async {
    await _ensureId();
    final res = await _http
        .put(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<void> delete(String path) async {
    await _ensureId();
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
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}
