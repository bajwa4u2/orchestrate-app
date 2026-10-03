import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
    final sentToken = _token();
    final response = await _httpClient.get(
      _uri(path, query),
      headers: await _headers(surface),
    ).timeout(AppConfig.apiTimeout);
    return _decode(response, sentToken);
  }

  Future<dynamic> postJson(
    String path, {
    required Map<String, dynamic> body,
    ApiSurface surface = ApiSurface.public,
    Duration? timeout,
  }) async {
    final sentToken = _token();
    final response = await _httpClient.post(
      _uri(path),
      headers: await _headers(surface),
      body: jsonEncode(body),
    ).timeout(timeout ?? AppConfig.apiTimeout);
    return _decode(response, sentToken);
  }

  Future<dynamic> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String filename,
    required String fieldName,
    String contentType = 'text/csv',
    Map<String, String>? fields,
    ApiSurface surface = ApiSurface.public,
    Duration? timeout,
  }) async {
    final uri = _uri(path);
    final sentToken = _token();
    final authHeaders = await _headersNoContentType(surface);
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(authHeaders)
      ..files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ));
    if (fields != null) request.fields.addAll(fields);
    final streamed = await request.send().timeout(timeout ?? AppConfig.apiTimeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response, sentToken);
  }

  Future<dynamic> patchJson(
    String path, {
    required Map<String, dynamic> body,
    ApiSurface surface = ApiSurface.public,
  }) async {
    final sentToken = _token();
    final response = await _httpClient.patch(
      _uri(path),
      headers: await _headers(surface),
      body: jsonEncode(body),
    ).timeout(AppConfig.apiTimeout);
    return _decode(response, sentToken);
  }

  Future<dynamic> deleteJson(
    String path, {
    Map<String, dynamic>? body,
    ApiSurface surface = ApiSurface.public,
  }) async {
    final sentToken = _token();
    final response = await _httpClient.delete(
      _uri(path),
      headers: await _headers(surface),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(AppConfig.apiTimeout);
    return _decode(response, sentToken);
  }

  Future<Map<String, String>> _headers(ApiSurface surface) async {
    final base = await _headersNoContentType(surface);
    return {...base, 'Content-Type': 'application/json'};
  }

  Future<Map<String, String>> _headersNoContentType(ApiSurface surface) async {
    final session = AuthSessionController.instance;
    final headers = <String, String>{'Accept': 'application/json'};
    final token = session.token.trim();
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  String _token() => AuthSessionController.instance.token.trim();

  dynamic _decode(http.Response response, String sentToken) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final exception = ApiException.fromResponse(response);
      if (response.statusCode == 401) {
        SessionEndCheck.instance.afterRefusal(sentToken, _httpClient);
      }
      throw exception;
    }
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }
}

/// A 401 IS NOT PROOF THE SESSION ENDED (founder walk, 3 Oct 2026).
///
/// Any 401 used to delete the saved session. But the server also answers 401
/// for "this endpoint is not for you" (an operator-only route, a missing
/// membership), and a request sent before the saved session was read carries
/// no token at all. Either one signed a person out of a valid session on a
/// page reload. Now: a refused request that carried no token, or a token that
/// is no longer the current one, changes nothing; otherwise the session is
/// asked about once, and only a session the server itself refuses is ended.
class SessionEndCheck {
  SessionEndCheck._();
  static final SessionEndCheck instance = SessionEndCheck._();

  Future<void>? _inFlight;

  /// For tests: how the session is asked about.
  Future<int> Function(String token, http.Client client)? probe;

  void afterRefusal(String sentToken, http.Client client) {
    if (sentToken.isEmpty) return;
    final session = AuthSessionController.instance;
    if (session.token.trim() != sentToken) return;
    _inFlight ??= _check(sentToken, client).whenComplete(() => _inFlight = null);
  }

  Future<void> _check(String token, http.Client client) async {
    int status;
    try {
      status = await (probe ?? _askServer)(token, client);
    } catch (_) {
      // No answer is not a refusal: keep the session.
      return;
    }
    final session = AuthSessionController.instance;
    if (status == 401 && session.token.trim() == token) {
      await session.handleAuthFailure(
        surface: session.surface,
        message: 'Your session has ended. Please sign in again to continue.',
      );
    }
  }

  static Future<int> _askServer(String token, http.Client client) async {
    final base = AppConfig.normalizedApiBaseUrl;
    final response = await client.get(
      Uri.parse('$base/auth/me'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(AppConfig.apiTimeout);
    return response.statusCode;
  }
}

class ApiException implements Exception {
  ApiException(
    this.statusCode,
    this.message,
    this.body, {
    this.requestId,
    this.correlationId,
  });

  final int statusCode;
  final String message;
  final String body;
  final String? requestId;
  final String? correlationId;

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
    requestId ??= response.headers['x-request-id'];
    final correlationId = response.headers['x-correlation-id'];
    return ApiException(
      response.statusCode,
      message,
      response.body,
      requestId: requestId,
      correlationId: correlationId,
    );
  }

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;
  String get displayId => correlationId?.isNotEmpty == true
      ? correlationId!
      : requestId?.isNotEmpty == true
          ? requestId!
          : '';
  String get displayMessage =>
      displayId.isEmpty ? message : '$message Reference: $displayId';

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
