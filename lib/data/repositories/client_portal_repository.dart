import '../../core/config/pricing_config.dart';
import '../../core/network/api_client.dart';

class ClientPortalRepository {
  ClientPortalRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    final json =
        await _apiClient.getJson('/client/overview', surface: ApiSurface.client);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<dynamic>> fetchInvoices() async {
    final json =
        await _apiClient.getJson('/client/invoices', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreements() async {
    final json = await _apiClient.getJson('/client/agreements',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchStatements() async {
    final json = await _apiClient.getJson('/client/statements',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchReminders() async {
    final json = await _apiClient.getJson('/client/reminders',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchNotifications() async {
    final json = await _apiClient.getJson('/client/notifications',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchEmailDispatches() async {
    final json = await _apiClient.getJson('/client/email-dispatches',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
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

  Future<Map<String, dynamic>> createSubscription(String plan, String tier) async {
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

  Future<Map<String, dynamic>> fetchClientProfile() async {
    final json = await _apiClient.getJson('/clients/me/profile', surface: ApiSurface.client);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> updateClientProfile({
    required String displayName,
    required String legalName,
    String? websiteUrl,
    String? bookingUrl,
    String? primaryTimezone,
    String? currencyCode,
    String? brandName,
    String? logoUrl,
    String? primaryColor,
    String? accentColor,
    String? welcomeHeadline,
  }) async {
    final json = await _apiClient.postJson(
      '/clients/me/profile',
      surface: ApiSurface.client,
      body: {
        'displayName': displayName,
        'legalName': legalName,
        if (websiteUrl != null && websiteUrl.trim().isNotEmpty) 'websiteUrl': websiteUrl.trim(),
        if (bookingUrl != null && bookingUrl.trim().isNotEmpty) 'bookingUrl': bookingUrl.trim(),
        if (primaryTimezone != null && primaryTimezone.trim().isNotEmpty) 'primaryTimezone': primaryTimezone.trim(),
        if (currencyCode != null && currencyCode.trim().isNotEmpty) 'currencyCode': currencyCode.trim().toUpperCase(),
        if (brandName != null && brandName.trim().isNotEmpty) 'brandName': brandName.trim(),
        if (logoUrl != null && logoUrl.trim().isNotEmpty) 'logoUrl': logoUrl.trim(),
        if (primaryColor != null && primaryColor.trim().isNotEmpty) 'primaryColor': primaryColor.trim(),
        if (accentColor != null && accentColor.trim().isNotEmpty) 'accentColor': accentColor.trim(),
        if (welcomeHeadline != null && welcomeHeadline.trim().isNotEmpty) 'welcomeHeadline': welcomeHeadline.trim(),
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }


  Future<Map<String, dynamic>?> deactivateClientAccount({
    String? reason,
    String? confirmationText,
  }) async {
    final json = await _apiClient.postJson(
      '/clients/me/deactivate',
      surface: ApiSurface.client,
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (confirmationText != null && confirmationText.trim().isNotEmpty)
          'confirmationText': confirmationText.trim(),
      },
    );

    if (json == null) return null;
    return Map<String, dynamic>.from(json as Map);
  }

}
