import '../../core/network/api_client.dart';
import '../../core/config/pricing_config.dart';

class PublicRepository {
  PublicRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    final json = await _apiClient.getJson('/public/overview');
    return Map<String, dynamic>.from(json as Map);
  }

  Future<PricingCatalog> fetchPricing() async {
    final json = await _apiClient.getJson('/public/pricing');
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

  Future<Map<String, dynamic>> submitIntake({
    required String message,
    String? name,
    String? email,
    String? company,
    String? sourcePage,
    String? inquiryTypeHint,
    Map<String, dynamic>? context,
  }) async {
    final body = <String, dynamic>{
      'message': message.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
      if (sourcePage != null && sourcePage.trim().isNotEmpty) 'sourcePage': sourcePage.trim(),
      if (inquiryTypeHint != null && inquiryTypeHint.trim().isNotEmpty)
        'inquiryTypeHint': inquiryTypeHint.trim(),
      if (context != null && context.isNotEmpty) 'context': context,
    };

    final json = await _apiClient.postJson('/public/intake', body: body);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> replyToIntakeSession({
    required String sessionId,
    required String message,
  }) async {
    final json = await _apiClient.postJson(
      '/public/intake/$sessionId/reply',
      body: {'message': message.trim()},
    );
    return Map<String, dynamic>.from(json as Map);
  }
}
