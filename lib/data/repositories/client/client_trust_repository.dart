import '../../../core/network/api_client.dart';

class ClientTrustRepository {
  ClientTrustRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> list() async {
    final json = await _apiClient.getJson(
      '/clients/me/trust',
      surface: ApiSurface.client,
    );
    final list = json as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> get(String id) async {
    final json = await _apiClient.getJson(
      '/clients/me/trust/$id',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> create({
    required String recordType,
    required String title,
    String? issuer,
    String? identifier,
    String? issueDate,
    String? expiryDate,
    String? jurisdiction,
    String? status,
    String? notes,
  }) async {
    final json = await _apiClient.postJson(
      '/clients/me/trust',
      body: {
        'recordType': recordType,
        'title': title,
        if (issuer != null) 'issuer': issuer,
        if (identifier != null) 'identifier': identifier,
        if (issueDate != null) 'issueDate': issueDate,
        if (expiryDate != null) 'expiryDate': expiryDate,
        if (jurisdiction != null) 'jurisdiction': jurisdiction,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      },
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async {
    final json = await _apiClient.patchJson(
      '/clients/me/trust/$id',
      body: body,
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> archive(String id) async {
    await _apiClient.deleteJson(
      '/clients/me/trust/$id',
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
      '/clients/me/trust/$id/attachment',
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
      '/clients/me/trust/$id/attachment',
      surface: ApiSurface.client,
    );
  }
}
