import '../../../core/network/api_client.dart';

class ClientMeetingsRepository {
  ClientMeetingsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchMeetings() async {
    final json =
        await _apiClient.getJson('/meetings', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }
}
