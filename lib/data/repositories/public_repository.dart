import '../../core/network/api_client.dart';
import '../../core/config/pricing_config.dart';

class PublicRepository {
  PublicRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    final json = await _apiClient.getJson('/public/overview', surface: ApiSurface.public);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<PricingCatalog> fetchPricing() async {
    final json = await _apiClient.getJson('/public/pricing', surface: ApiSurface.public);
    return PricingConfig.fromApi(Map<String, dynamic>.from(json as Map));
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
      surface: ApiSurface.public,
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

  Future<Map<String, dynamic>> createIntakeSession({
    required String message,
    String? name,
    String? email,
    String? company,
    String? sourcePage,
    String? inquiryTypeHint,
  }) async {
    final json = await _apiClient.postJson(
      '/public/intake',
      surface: ApiSurface.public,
      body: {
        'message': message.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
        if (sourcePage != null && sourcePage.trim().isNotEmpty) 'sourcePage': sourcePage.trim(),
        if (inquiryTypeHint != null && inquiryTypeHint.trim().isNotEmpty)
          'inquiryTypeHint': inquiryTypeHint.trim(),
      },
    );

    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> replyToIntakeSession({
    required String sessionId,
    required String message,
  }) async {
    final json = await _apiClient.postJson(
      '/public/intake/$sessionId/reply',
      surface: ApiSurface.public,
      body: {'message': message.trim()},
    );

    return Map<String, dynamic>.from(json as Map);
  }
}
