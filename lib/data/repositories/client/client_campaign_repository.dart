import '../../../core/network/api_client.dart';

class ClientCampaignRepository {
  ClientCampaignRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchCampaignProfile() async {
    final json = await _apiClient.getJson(
      '/client/campaign-profile',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> updateCampaignProfile({
    required Map<String, dynamic> profile,
  }) async {
    final json = await _apiClient.patchJson(
      '/client/campaign-profile',
      surface: ApiSurface.client,
      body: profile,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> startCampaign() async {
    final json = await _apiClient.postJson(
      '/client/campaign-profile/start',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }
}
