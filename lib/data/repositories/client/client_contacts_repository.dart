import '../../../core/network/api_client.dart';

class ClientContactsRepository {
  ClientContactsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    final primary = await _fetchList('/client/leads');
    if (primary.isNotEmpty) return primary;

    final campaignOverview = await _fetchMap('/clients/me/campaign-overview');
    final embedded = _asList(campaignOverview['contacts']);
    if (embedded.isNotEmpty) {
      return embedded.map(_asMap).toList();
    }

    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchContactsSafe() async {
    try {
      return await fetchContacts();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchList(String path) async {
    final json = await _apiClient.getJson(path, surface: ApiSurface.client);
    return _asList(json).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> _fetchMap(String path) async {
    final json = await _apiClient.getJson(path, surface: ApiSurface.client);
    return _asMap(json);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) =>
      value is List ? value : const <dynamic>[];
}
