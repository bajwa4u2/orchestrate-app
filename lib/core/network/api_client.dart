import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

enum ApiSurface { public, client, operator }

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/v1',
  );

  Uri _uri(String path, [Map<String, String>? query]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse('$base/$cleanPath').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    ApiSurface surface = ApiSurface.public,
  }) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: await _headers(surface),
    );
    return _decode(response);
  }

  Future<dynamic> postJson(
    String path, {
    required Map<String, dynamic> body,
    ApiSurface surface = ApiSurface.public,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: await _headers(surface),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> patchJson(
    String path, {
    required Map<String, dynamic> body,
    ApiSurface surface = ApiSurface.public,
  }) async {
    final response = await _httpClient.patch(
      _uri(path),
      headers: await _headers(surface),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, String>> _headers(ApiSurface surface) async {
    final session = AuthSessionController.instance;

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final token = session.token.trim();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final email = session.email.trim();
    if (email.isNotEmpty) {
      headers['X-User-Email'] = email;
    }

    final organizationId = session.organizationId.trim();
    if (organizationId.isNotEmpty) {
      headers['X-Organization-Id'] = organizationId;
    }

    final memberRole = session.memberRole.trim();
    if (memberRole.isNotEmpty) {
      headers['X-Member-Role'] = memberRole;
    }

    if (surface == ApiSurface.client) {
      final clientId = session.clientId.trim();
      if (clientId.isNotEmpty) {
        headers['X-Client-Id'] = clientId;
      }
    }

    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}
