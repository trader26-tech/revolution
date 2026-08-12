import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
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

  /// HARD-delete this account and ALL its data on the server (tasks + user row),
  /// then forget the id locally. Backs "Delete data & log off" — a real wipe,
  /// not a soft reset. Best-effort on the network call so the local reset always
  /// proceeds even offline (the row is orphaned server-side and cleaned later).
  Future<void> deleteAccount() async {
    try {
      await _awaitPendingWrites(); // don't race in-flight creates
      await delete('/users/me');
    } catch (_) {
      // Network/again-later — still clear locally below.
    }
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  /// Writes (like the onboarding batch-save) that MUST land before the claim
  /// re-keys rows to the account. Tracked so [claim] can wait for them —
  /// otherwise a save still in flight when login fires would be left behind on
  /// the anonymous account (or lose its follow-up), which is how onboarding
  /// tasks used to arrive broken.
  final Set<Future<void>> _pendingWrites = {};

  /// Register a write the next [claim] must wait for. Self-removes on finish.
  void trackPendingWrite(Future<void> write) {
    _pendingWrites.add(write);
    write.whenComplete(() => _pendingWrites.remove(write));
  }

  Future<void> _awaitPendingWrites() async {
    if (_pendingWrites.isEmpty) return;
    try {
      await Future.wait(List.of(_pendingWrites))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Never block login forever on a stuck write.
    }
  }

  /// The pairing: attach this (anonymous) session to a verified phone. Runs
  /// UNDER the current anonymous id; the server either claims it in place or
  /// merges it into the phone's existing account. Returns the response map —
  /// the caller must [setUserId] to its `user_id`.
  ///
  /// Waits for tracked in-flight writes first, so every onboarding task is on
  /// the anonymous account BEFORE the server moves them over.
  Future<dynamic> claim({required String phone, String? name}) async {
    await _awaitPendingWrites();
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

  /// Upload a document (PDF/photo) for a task — multipart to
  /// POST /tasks/{id}/document. Returns the stored path on success. A longer
  /// timeout than JSON calls since files take a moment.
  Future<String?> uploadDocument(
    String taskId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    await _ensureId();
    final req = http.MultipartRequest('POST', _uri('/tasks/$taskId/document'))
      ..headers['X-User-Id'] = _userId ?? ''
      ..headers['X-Owner-Id'] = _userId ?? ''
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['document_path'] as String?;
    }
    throw ApiException(res.statusCode, res.body);
  }

  /// Fetch a short-lived signed URL to VIEW a task's document, or null if none.
  Future<String?> documentUrl(String taskId) async {
    try {
      final json = await get('/tasks/$taskId/document') as Map<String, dynamic>;
      return json['url'] as String?;
    } catch (_) {
      return null; // no document / not found
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
