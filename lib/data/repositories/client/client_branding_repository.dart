import '../../../core/network/api_client.dart';

class ClientBrandingRepository {
  ClientBrandingRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchBranding() async {
    final json = await _apiClient.getJson(
      '/clients/me/branding',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> uploadLogo({
    required List<int> fileBytes,
    required String filename,
    required String mimeType,
    required String assetType,
  }) async {
    final json = await _apiClient.postMultipart(
      '/clients/me/branding/logo',
      fileBytes: fileBytes,
      filename: filename,
      fieldName: 'file',
      contentType: mimeType,
      fields: {'assetType': assetType},
      surface: ApiSurface.client,
      timeout: const Duration(seconds: 60),
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> removeLogo({required String assetType}) async {
    final json = await _apiClient.deleteJson(
      '/clients/me/branding/logo',
      body: {'assetType': assetType},
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> updateBrandingConfig({
    String? primaryColor,
    String? accentColor,
  }) async {
    final json = await _apiClient.patchJson(
      '/clients/me/branding',
      body: {
        if (primaryColor != null) 'primaryColor': primaryColor,
        if (accentColor != null) 'accentColor': accentColor,
      },
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }
}
