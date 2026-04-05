import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

enum ApiSurface { public, client, operator }

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/v1',
  );

  Uri _uri(String path, [Map<String, String>? query]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final base = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return Uri.parse('$base/$cleanPath').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query, ApiSurface surface = ApiSurface.public}) async {
    final response = await _httpClient.get(_uri(path, query), headers: _headers(surface));
    return _decode(response);
  }

  Future<dynamic> postJson(String path, {required Map<String, dynamic> body, ApiSurface surface = ApiSurface.public}) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(surface),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, String> _headers(ApiSurface surface) {
    final session = AuthSessionController.instance;
    final headers = <String, String>{'content-type': 'application/json'};
    if (session.token.isNotEmpty) {
      headers['authorization'] = 'Bearer ${session.token}';
      headers['x-user-email'] = session.email;
      if (session.organizationId.isNotEmpty) headers['x-organization-id'] = session.organizationId;
      if (surface == ApiSurface.client && session.clientId.isNotEmpty) headers['x-client-id'] = session.clientId;
      if (session.memberRole.isNotEmpty) headers['x-member-role'] = session.memberRole;
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
