import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../config/app_config.dart';

enum ApiSurface { public, client, operator }

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, String>? query]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final base = AppConfig.normalizedApiBaseUrl;
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
    ).timeout(AppConfig.apiTimeout);
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
    ).timeout(AppConfig.apiTimeout);
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
    ).timeout(AppConfig.apiTimeout);
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

    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final exception = ApiException.fromResponse(response);
      if (response.statusCode == 401 || response.statusCode == 403) {
        AuthSessionController.instance.handleAuthFailure(
          surface: AuthSessionController.instance.surface,
          message: exception.message,
        );
      }
      throw exception;
    }
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, this.body, {this.requestId});

  final int statusCode;
  final String message;
  final String body;
  final String? requestId;

  factory ApiException.fromResponse(http.Response response) {
    var message = 'Request failed';
    String? requestId;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        requestId = decoded['requestId']?.toString();
        final rawMessage = decoded['message'] ?? decoded['error'];
        if (rawMessage is List) {
          message = rawMessage.map((item) => item.toString()).join('; ');
        } else if (rawMessage != null) {
          message = rawMessage.toString();
        }
      }
    } catch (_) {
      if (response.body.trim().isNotEmpty) {
        message = response.body.trim();
      }
    }
    return ApiException(
      response.statusCode,
      message,
      response.body,
      requestId: requestId,
    );
  }

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
