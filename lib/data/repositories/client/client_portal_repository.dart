import '../../../core/network/api_client.dart';

class ClientPortalRepository {
  ClientPortalRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOutreach() async {
    final json = await _apiClient.getJson('/client/outreach',
        surface: ApiSurface.client);
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchReplies() async {
    final json =
        await _apiClient.getJson('/client/replies', surface: ApiSurface.client);
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchMeetings() async {
    final json = await _apiClient.getJson('/client/meetings',
        surface: ApiSurface.client);
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchRecords() async {
    final json =
        await _apiClient.getJson('/client/records', surface: ApiSurface.client);
    return _asMap(json);
  }

  Future<List<dynamic>> fetchNotifications() async {
    final json = await _apiClient.getJson('/client/notifications',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<Map<String, dynamic>> fetchRepresentationAuth() async {
    final json = await _apiClient.getJson('/clients/me/representation-auth',
        surface: ApiSurface.client);
    return _asMap(json);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return const <String, dynamic>{};
  }
}
