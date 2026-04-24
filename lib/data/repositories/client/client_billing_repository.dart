import '../../../core/config/pricing_config.dart';
import '../../../core/network/api_client.dart';

class ClientBillingRepository {
  ClientBillingRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchInvoices() async {
    final json = await _apiClient.getJson('/client/invoices',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreements() async {
    final json = await _apiClient.getJson(
      '/client/agreements',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchStatements() async {
    final json = await _apiClient.getJson(
      '/client/statements',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchReminders() async {
    final json = await _apiClient.getJson(
      '/client/reminders',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreementsSafe() async {
    try {
      return await fetchAgreements();
    } catch (_) {
      return const <dynamic>[];
    }
  }

  Future<Map<String, dynamic>?> fetchSubscriptionSafe() async {
    try {
      return await fetchSubscription();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSubscription() async {
    final json = await _apiClient.getJson(
      '/billing/subscription',
      surface: ApiSurface.client,
    );

    if (json == null) return null;
    return Map<String, dynamic>.from(json as Map);
  }

  Future<PricingCatalog> fetchPricingCatalog() async {
    final json = await _apiClient.getJson('/public/pricing');
    return PricingConfig.fromApi(Map<String, dynamic>.from(json as Map));
  }

  Future<Map<String, dynamic>> createSubscription(
      String plan, String tier) async {
    final normalizedPlan = plan.trim().toLowerCase();
    final normalizedTier = tier.trim().toLowerCase();

    final apiPlan = normalizedPlan == 'revenue' ? 'REVENUE' : 'OPPORTUNITY';
    final apiTier = switch (normalizedTier) {
      'precision' => 'PRECISION',
      'multi' || 'multi-market' || 'multi_market' => 'MULTI',
      _ => 'FOCUSED',
    };

    final json = await _apiClient.postJson(
      '/billing/subscribe',
      body: {
        'plan': apiPlan,
        'tier': apiTier,
      },
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<String> createBillingPortalSession() async {
    final json = await _apiClient.postJson(
      '/billing/portal',
      body: const {},
      surface: ApiSurface.client,
    );

    return (json as Map)['url'] as String;
  }
}
