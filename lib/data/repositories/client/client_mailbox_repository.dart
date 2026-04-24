import '../../../core/network/api_client.dart';

class ClientMailboxRepository {
  ClientMailboxRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchReplies({int limit = 12}) async {
    final json = await _apiClient.getJson(
      '/replies',
      query: <String, String>{'limit': '$limit'},
      surface: ApiSurface.client,
    );
    return _asList(json).map(_asMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRepliesSafe({int limit = 12}) async {
    try {
      return await fetchReplies(limit: limit);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchEmailDispatches() async {
    final json = await _apiClient.getJson('/client/email-dispatches',
        surface: ApiSurface.client);
    return _asList(json).map(_asMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchEmailDispatchesSafe() async {
    try {
      return await fetchEmailDispatches();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final json = await _apiClient.getJson('/client/notifications',
        surface: ApiSurface.client);
    return _asList(json).map(_asMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchNotificationsSafe() async {
    try {
      return await fetchNotifications();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) =>
      value is List ? value : const <dynamic>[];
}
