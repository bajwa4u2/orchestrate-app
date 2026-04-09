import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session.dart';

class SupportService {
  final String baseUrl;

  const SupportService({
    required this.baseUrl,
  });

  Future<Map<String, dynamic>> createSession({
    required String message,
    required bool publicMode,
    String? name,
    String? email,
    String? sourcePage,
    String? inquiryTypeHint,
  }) async {
    final endpoint = publicMode ? '$baseUrl/public/intake' : '$baseUrl/client/support/intake';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: _headers(publicMode: publicMode),
      body: jsonEncode({
        'message': message,
        if (publicMode && name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (publicMode && email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (sourcePage != null && sourcePage.trim().isNotEmpty) 'sourcePage': sourcePage.trim(),
        if (inquiryTypeHint != null && inquiryTypeHint.trim().isNotEmpty)
          'inquiryTypeHint': inquiryTypeHint.trim(),
      }),
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> reply({
    required String sessionId,
    required String message,
    required bool publicMode,
  }) async {
    final endpoint = publicMode
        ? '$baseUrl/public/intake/$sessionId/reply'
        : '$baseUrl/client/support/intake/$sessionId/reply';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: _headers(publicMode: publicMode),
      body: jsonEncode({'message': message}),
    );

    return _decode(response);
  }

  Map<String, String> _headers({required bool publicMode}) {
    final headers = <String, String>{'content-type': 'application/json'};
    if (!publicMode) {
      final session = AuthSessionController.instance;
      if (session.token.isNotEmpty) {
        headers['authorization'] = 'Bearer ${session.token}';
        headers['x-user-email'] = session.email;
        if (session.organizationId.isNotEmpty) {
          headers['x-organization-id'] = session.organizationId;
        }
        if (session.clientId.isNotEmpty) {
          headers['x-client-id'] = session.clientId;
        }
        if (session.memberRole.isNotEmpty) {
          headers['x-member-role'] = session.memberRole;
        }
      }
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Support request failed: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected support response shape');
  }
}
