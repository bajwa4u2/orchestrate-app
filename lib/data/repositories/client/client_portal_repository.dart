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

  /// List the governed message-template catalog (client-scoped).
  Future<List<dynamic>> fetchMessageTemplates() async {
    final json = await _apiClient.getJson('/client/message-templates',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  /// Get a single template's full shape (subject + body templates,
  /// required + allowed variables, compliance notes).
  Future<Map<String, dynamic>> fetchMessageTemplate(String key) async {
    final json = await _apiClient.getJson(
      '/client/message-templates/$key',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Render a template preview with caller-supplied variables. On
  /// success the response is `{ ok: true, rendered: {...} }`. On
  /// missing/unknown variables the response is
  /// `{ ok: false, reason: 'MISSING_REQUIRED_VARIABLE' | 'UNKNOWN_VARIABLE', ... }`.
  Future<Map<String, dynamic>> previewMessageTemplate(
    String key,
    Map<String, dynamic> variables,
  ) async {
    final json = await _apiClient.postJson(
      '/client/message-templates/$key/preview',
      surface: ApiSurface.client,
      body: {'variables': variables},
    );
    return _asMap(json);
  }

  /// List recent governed dispatches (last 25 outreach messages).
  /// Each entry carries a `governance` block when present.
  Future<List<dynamic>> fetchRecentMessages() async {
    final json = await _apiClient.getJson(
      '/client/messages/recent',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  /// Full provenance trace for a single outreach message.
  Future<Map<String, dynamic>> fetchMessageTrace(String messageId) async {
    final json = await _apiClient.getJson(
      '/client/messages/$messageId/trace',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Read the governed outbound signature for the current client.
  /// Backend returns `{ signature: { ... } | null, preview: '<plaintext>' }`.
  Future<Map<String, dynamic>> fetchSignature() async {
    final json = await _apiClient.getJson('/client/signature',
        surface: ApiSurface.client);
    return _asMap(json);
  }

  /// Persist the governed outbound signature. Each field is optional;
  /// passing all nulls clears the signature. The backend sanitizes
  /// every field (CR/LF/NUL stripped, length capped) before storage.
  Future<Map<String, dynamic>> updateSignature({
    String? displayName,
    String? role,
    String? businessName,
    String? phone,
    String? websiteUrl,
    String? schedulingUrl,
    String? complianceFooter,
  }) async {
    final json = await _apiClient.postJson(
      '/client/signature',
      surface: ApiSurface.client,
      body: {
        'displayName': displayName,
        'role': role,
        'businessName': businessName,
        'phone': phone,
        'websiteUrl': websiteUrl,
        'schedulingUrl': schedulingUrl,
        'complianceFooter': complianceFooter,
      },
    );
    return _asMap(json);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return const <String, dynamic>{};
  }
}
