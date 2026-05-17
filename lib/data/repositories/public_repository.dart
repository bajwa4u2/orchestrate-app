import '../../core/network/api_client.dart';
import '../../core/config/pricing_config.dart';

class PublicRepository {
  PublicRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    final json = await _apiClient.getJson('/public/overview');
    return Map<String, dynamic>.from(json as Map);
  }

  /// Public journey catalog list — { key, title, audience, intent,
  /// stageCount } per journey.
  Future<Map<String, dynamic>> fetchJourneys() async {
    final json = await _apiClient.getJson('/public/journeys');
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
  }

  /// One journey's full definition — stages + linked surfaces +
  /// knowledge cross-references.
  Future<Map<String, dynamic>> fetchJourney(String key) async {
    final json = await _apiClient.getJson('/public/journeys/$key');
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
  }

  /// Public support catalog — returns the curated knowledge entries
  /// (key + topic + canonical question + confidence) so the answers
  /// screen can render topic pills + canonical-question chips before
  /// the visitor types anything.
  Future<Map<String, dynamic>> fetchSupportCatalog() async {
    final json = await _apiClient.getJson('/public/support/catalog');
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
  }

  /// Ask a public operational question. The backend deterministically
  /// scores the question against the curated knowledge catalog and
  /// returns up to 4 matched entries or `unanswered: true` plus a
  /// list of suggested topics. NO AI generation — every answer is
  /// sourced verbatim from a catalog entry.
  Future<Map<String, dynamic>> askSupport({
    required String question,
    String? topic,
  }) async {
    final json = await _apiClient.postJson(
      '/public/support/ask',
      body: {
        'question': question.trim(),
        if (topic != null && topic.isNotEmpty) 'topic': topic,
      },
    );
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
  }

  /// Public DNS diagnostic — runs SPF / DKIM / DMARC verification
  /// against the caller-supplied domain WITHOUT signup. Returns the
  /// same DnsRecordCheck[] shape the authenticated verifier uses.
  Future<Map<String, dynamic>> diagnosticsDns(String domain) async {
    final json = await _apiClient.postJson(
      '/public/diagnostics/dns',
      body: {'domain': domain.trim()},
    );
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
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
        if (company != null && company.trim().isNotEmpty)
          'company': company.trim(),
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
  }) async {
    final body = <String, dynamic>{
      'message': message.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      if (sourcePage != null && sourcePage.trim().isNotEmpty)
        'sourcePage': sourcePage.trim(),
      if (inquiryTypeHint != null && inquiryTypeHint.trim().isNotEmpty)
        'inquiryTypeHint': inquiryTypeHint.trim(),
    };

    final json = await _apiClient.postJson('/public/intake', body: body);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> replyToIntakeSession({
    required String sessionId,
    required String message,
    required String sessionToken,
  }) async {
    final json = await _apiClient.postJson(
      '/public/intake/$sessionId/reply',
      body: {
        'message': message.trim(),
        'sessionToken': sessionToken.trim(),
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }
}
