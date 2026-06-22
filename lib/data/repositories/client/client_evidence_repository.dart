import '../../../core/network/api_client.dart';

class ClientEvidenceRepository {
  ClientEvidenceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> list({String? recordType, String? allowedUse}) async {
    final params = <String, String>{
      if (recordType != null) 'recordType': recordType,
      if (allowedUse != null) 'allowedUse': allowedUse,
    };
    final path = '/clients/me/evidence${params.isNotEmpty ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}';
    final json = await _apiClient.getJson(path, surface: ApiSurface.client);
    final list = json as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> get(String id) async {
    final json = await _apiClient.getJson(
      '/clients/me/evidence/$id',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> create({
    required String recordType,
    required String title,
    String? summary,
    String? industry,
    String? geography,
    bool? confidential,
    String? allowedUse,
    Map<String, dynamic>? contentJson,
  }) async {
    final json = await _apiClient.postJson(
      '/clients/me/evidence',
      body: {
        'recordType': recordType,
        'title': title,
        if (summary != null) 'summary': summary,
        if (industry != null) 'industry': industry,
        if (geography != null) 'geography': geography,
        if (confidential != null) 'confidential': confidential,
        if (allowedUse != null) 'allowedUse': allowedUse,
        if (contentJson != null) 'contentJson': contentJson,
      },
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async {
    final json = await _apiClient.patchJson(
      '/clients/me/evidence/$id',
      body: body,
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> archive(String id) async {
    await _apiClient.deleteJson(
      '/clients/me/evidence/$id',
      surface: ApiSurface.client,
    );
  }

  Future<Map<String, dynamic>> uploadAttachment(
    String id, {
    required List<int> fileBytes,
    required String filename,
    required String mimeType,
  }) async {
    final json = await _apiClient.postMultipart(
      '/clients/me/evidence/$id/attachment',
      fileBytes: fileBytes,
      filename: filename,
      fieldName: 'file',
      contentType: mimeType,
      surface: ApiSurface.client,
      timeout: const Duration(seconds: 60),
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> removeAttachment(String id) async {
    await _apiClient.deleteJson(
      '/clients/me/evidence/$id/attachment',
      surface: ApiSurface.client,
    );
  }
}
