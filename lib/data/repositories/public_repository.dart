import '../../core/network/api_client.dart';

class PublicRepository {
  PublicRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchPricing() async {
    final json = await _apiClient.getJson('/public/pricing');
    return Map<String, dynamic>.from(json as Map);
  }

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
        if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
        'inquiryType': inquiryType.trim(),
        'message': message.trim(),
      },
    );

    return Map<String, dynamic>.from(json as Map);
  }
}
