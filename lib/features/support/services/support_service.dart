import '../../../core/network/api_client.dart';

class SupportService {
  final ApiClient _apiClient;

  SupportService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> createSession({
    required String message,
    required bool publicMode,
    String? name,
    String? email,
    String? sourcePage,
    String? inquiryTypeHint,
  }) async {
    final response = await _apiClient.postJson(
      publicMode ? '/public/intake' : '/client/support/intake',
      surface: publicMode ? ApiSurface.public : ApiSurface.client,
      body: {
        'message': message,
        if (publicMode && name != null && name.trim().isNotEmpty)
          'name': name.trim(),
        if (publicMode && email != null && email.trim().isNotEmpty)
          'email': email.trim(),
        if (sourcePage != null && sourcePage.trim().isNotEmpty)
          'sourcePage': sourcePage.trim(),
        if (inquiryTypeHint != null && inquiryTypeHint.trim().isNotEmpty)
          'inquiryTypeHint': inquiryTypeHint.trim(),
      },
    );
    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> reply({
    required String sessionId,
    required String message,
    required bool publicMode,
    String? sessionToken,
  }) async {
    final response = await _apiClient.postJson(
      publicMode
          ? '/public/intake/$sessionId/reply'
          : '/client/support/intake/$sessionId/reply',
      surface: publicMode ? ApiSurface.public : ApiSurface.client,
      body: {
        'message': message,
        if (publicMode && sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
      },
    );
    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> listClientInquiries() async {
    final response = await _apiClient.getJson(
      '/client/support/inquiries',
      surface: ApiSurface.client,
    );
    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> getClientInquiryThread(String inquiryId) async {
    final response = await _apiClient.getJson(
      '/client/support/inquiries/$inquiryId/thread',
      surface: ApiSurface.client,
    );
    return _mapResponse(response);
  }

  Map<String, dynamic> _mapResponse(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Unexpected support response shape');
  }
}
