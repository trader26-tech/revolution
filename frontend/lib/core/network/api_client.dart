import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thin HTTP wrapper around the backend API.
///
/// Kept minimal on purpose — swap in dio/retrofit later if needed.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> get(String path) async {
    final res = await _client.get(_uri(path), headers: _headers);
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _client.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
