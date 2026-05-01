import '../../../core/network/api_client.dart';

class ClientWorkflowStateRepository {
  ClientWorkflowStateRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchWorkflowState() async {
    final json = await _apiClient.getJson(
      '/client/workflow-state',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return const <String, dynamic>{};
  }
}
