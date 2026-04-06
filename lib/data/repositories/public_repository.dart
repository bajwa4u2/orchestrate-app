import '../../core/network/api_client.dart';

class PublicRepository {
  PublicRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> submitContact({
    required String name,
    required String email,
    String? company,
    required String inquiryType,
    required String message,
  }) async {
    final json = await _apiClient.postJson(
      '/public/contact',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'company': (company ?? '').trim(),
        'inquiryType': inquiryType,
        'message': message.trim(),
      },
      surface: ApiSurface.public,
    );

    return Map<String, dynamic>.from(json as Map);
  }
}
