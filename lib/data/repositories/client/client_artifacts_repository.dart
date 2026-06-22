import '../../../core/network/api_client.dart';

class ClientArtifactsRepository {
  ClientArtifactsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> list({String? artifactType}) async {
    final path = '/clients/me/artifacts${artifactType != null ? '?artifactType=$artifactType' : ''}';
    final json = await _apiClient.getJson(path, surface: ApiSurface.client);
    final list = json as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> get(String id) async {
    final json = await _apiClient.getJson(
      '/clients/me/artifacts/$id',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> generate({
    required String artifactType,
    String? title,
    Map<String, dynamic>? params,
  }) async {
    final json = await _apiClient.postJson(
      '/clients/me/artifacts',
      body: {
        'artifactType': artifactType,
        if (title != null) 'title': title,
        if (params != null) 'params': params,
      },
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> archive(String id) async {
    await _apiClient.deleteJson(
      '/clients/me/artifacts/$id',
      surface: ApiSurface.client,
    );
  }
}
