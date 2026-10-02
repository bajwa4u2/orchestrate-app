import '../../core/network/api_client.dart';
import '../../core/commercial/commercial_model.dart';

class PublicRepository {
  PublicRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    final json = await _apiClient.getJson('/public/overview');
    return Map<String, dynamic>.from(json as Map);
  }

  /// Dynamic commercial-journey cards (DB-backed) for the public home.
  /// Returns `{ cards: [...], hidden: [...], source }` where `cards` holds
  /// only the eligible commercial stages / retained assets whose value > 0,
  /// ordered by commercial progression. The card set is registry-driven, so
  /// the homepage evolves automatically as metrics move 0→1 and 1→0.
  Future<Map<String, dynamic>> fetchLifecycle() async {
    final json = await _apiClient.getJson('/public/lifecycle');
    return Map<String, dynamic>.from(json as Map);
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

  /// The commercial model, as the server states it.
  ///
  /// Returned raw rather than parsed into plan objects: there are no plans to
  /// parse. `/public/pricing` used to serve six of them at fixed prices that
  /// nobody had approved, and it now serves the model instead.
  Future<CommercialModel> fetchPricing() async {
    final json = await _apiClient.getJson('/public/pricing');
    return CommercialModel.fromJson(Map<String, dynamic>.from(json as Map));
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
