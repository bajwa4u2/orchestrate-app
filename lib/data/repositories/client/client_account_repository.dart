import '../../../core/network/api_client.dart';

class ClientAccountRepository {
  ClientAccountRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchClientProfile() async {
    final json = await _apiClient.getJson(
      '/clients/me/profile',
      surface: ApiSurface.client,
    );
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
        if (websiteUrl != null && websiteUrl.trim().isNotEmpty)
          'websiteUrl': websiteUrl.trim(),
        if (bookingUrl != null && bookingUrl.trim().isNotEmpty)
          'bookingUrl': bookingUrl.trim(),
        if (primaryTimezone != null && primaryTimezone.trim().isNotEmpty)
          'primaryTimezone': primaryTimezone.trim(),
        if (currencyCode != null && currencyCode.trim().isNotEmpty)
          'currencyCode': currencyCode.trim().toUpperCase(),
        if (brandName != null && brandName.trim().isNotEmpty)
          'brandName': brandName.trim(),
        if (logoUrl != null && logoUrl.trim().isNotEmpty)
          'logoUrl': logoUrl.trim(),
        if (primaryColor != null && primaryColor.trim().isNotEmpty)
          'primaryColor': primaryColor.trim(),
        if (accentColor != null && accentColor.trim().isNotEmpty)
          'accentColor': accentColor.trim(),
        if (welcomeHeadline != null && welcomeHeadline.trim().isNotEmpty)
          'welcomeHeadline': welcomeHeadline.trim(),
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


extension ClientAccountRepositorySafe on ClientAccountRepository {
  Future<Map<String, dynamic>> fetchClientProfileSafe() async {
    try {
      return await fetchClientProfile();
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
}
