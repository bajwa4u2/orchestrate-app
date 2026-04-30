import '../../../core/network/api_client.dart';

class ClientMeetingsRepository {
  ClientMeetingsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchMeetings() async {
    final json = await _apiClient.getJson(
      '/client/meetings',
      surface: ApiSurface.client,
    );
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.map((key, item) => MapEntry('$key', item));
    return const <String, dynamic>{};
  }
}
