import '../../../core/network/api_client.dart';

class ClientWorkspaceRepository {
  ClientWorkspaceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    final json =
        await _apiClient.getJson('/client/overview', surface: ApiSurface.client);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<dynamic>> fetchNotifications() async {
    final json = await _apiClient.getJson(
      '/client/notifications',
      surface: ApiSurface.client,
    );
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
}
