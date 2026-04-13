import '../../../core/network/api_client.dart';

class ClientOutreachRepository {
  ClientOutreachRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchReplies({int limit = 12}) async {
    final json = await _apiClient.getJson(
      '/replies?limit=$limit',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchEmailDispatches() async {
    final json = await _apiClient.getJson(
      '/client/email-dispatches',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchNotifications() async {
    final json = await _apiClient.getJson(
      '/client/notifications',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }
}
