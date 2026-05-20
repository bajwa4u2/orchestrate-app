import '../../../core/network/api_client.dart';
import '../../../features/client/models/client_experience.dart';

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

  /// Authoritative runtime execution state. Returns a closed-enum
  /// state derived from real runtime signals — queue depth, recent
  /// dispatch activity, recent failures, workload count — not from
  /// optimistic readiness latches. Use to render runtime-truthful
  /// labels instead of bucket-driven over-confident claims.
  Future<Map<String, dynamic>> fetchRuntimeState() async {
    final json = await _apiClient.getJson(
      '/client/runtime-state',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Authoritative opportunity-bucket summary. Each count is read
  /// deterministically from persisted rows. Returns disjoint
  /// qualification buckets (`underQualification` / `qualified` /
  /// `dispatchReady` / `dispatched` / `suppressed`) plus an additive
  /// blocking axis (`blockedByGovernance` / `governanceReviewQueue`)
  /// and a runtime echo for cross-surface consistency.
  Future<Map<String, dynamic>> fetchOpportunitySummary() async {
    final json = await _apiClient.getJson(
      '/client/opportunities/summary',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// The client experience surface — the single client-safe
  /// projection of operational truth. Outcome-oriented business
  /// momentum, truthful confidence signals, growth numbers, and a
  /// client action only when the client genuinely owns the next
  /// step. Runtime / diagnostic semantics never appear here.
  Future<ClientExperience> fetchClientExperience() async {
    final json = await _apiClient.getJson(
      '/client/experience',
      surface: ApiSurface.client,
    );
    return ClientExperience.fromJson(_asMap(json));
  }

  /// Read the operational support timeline: chronological union of
  /// activity events, DNS verification history, recent dispatches,
  /// and open alerts -- all client-scoped, no fabricated events.
  Future<Map<String, dynamic>> fetchSupportTimeline() async {
    final json = await _apiClient.getJson(
      '/client/support/timeline',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Read the runtime-aware support context: subscription state,
  /// mailbox state, sending-domain state, recent governed dispatches,
  /// blockers derived from persisted state. No new business rules —
  /// the backend composes existing reads into one payload so the
  /// support surface never has to ask the client what failed.
  Future<Map<String, dynamic>> fetchSupportContext() async {
    final json = await _apiClient.getJson(
      '/client/support/context',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// List sequences for the requesting client, optionally scoped to
  /// a campaign via `campaignId`.
  Future<List<dynamic>> fetchSequences({String? campaignId}) async {
    final query =
        campaignId == null ? '' : '?campaignId=${Uri.encodeQueryComponent(campaignId)}';
    final json = await _apiClient.getJson(
      '/client/sequences$query',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  /// Fetch one sequence's full step list.
  Future<Map<String, dynamic>> fetchSequence(String sequenceId) async {
    final json = await _apiClient.getJson(
      '/client/sequences/$sequenceId',
      surface: ApiSurface.client,
    );
    return _asMap(json);
  }

  /// Create a SequenceStep. Either `templateKey` (governed) or
  /// `bodyTemplate` (legacy custom) must be set unless `type` is
  /// non-email (WAIT / TASK / NOTE). Backend rejects invalid
  /// templateKey or unbound required variables.
  Future<Map<String, dynamic>> createSequenceStep({
    required String sequenceId,
    int? orderIndex,
    int? waitDays,
    String? type,
    String? status,
    String? subjectTemplate,
    String? bodyTemplate,
    String? templateKey,
    Map<String, dynamic>? templateVariables,
    String? instructionText,
  }) async {
    final json = await _apiClient.postJson(
      '/client/sequences/$sequenceId/steps',
      surface: ApiSurface.client,
      body: {
        if (orderIndex != null) 'orderIndex': orderIndex,
        if (waitDays != null) 'waitDays': waitDays,
        if (type != null) 'type': type,
        if (status != null) 'status': status,
        if (subjectTemplate != null) 'subjectTemplate': subjectTemplate,
        if (bodyTemplate != null) 'bodyTemplate': bodyTemplate,
        if (templateKey != null) 'templateKey': templateKey,
        if (templateVariables != null)
          'templateVariablesJson': templateVariables,
        if (instructionText != null) 'instructionText': instructionText,
      },
    );
    return _asMap(json);
  }

  /// Update a SequenceStep in place. Same body shape as create.
  Future<Map<String, dynamic>> updateSequenceStep({
    required String stepId,
    int? orderIndex,
    int? waitDays,
    String? type,
    String? status,
    String? subjectTemplate,
    String? bodyTemplate,
    String? templateKey,
    Map<String, dynamic>? templateVariables,
    String? instructionText,
  }) async {
    final json = await _apiClient.patchJson(
      '/client/sequence-steps/$stepId',
      surface: ApiSurface.client,
      body: {
        if (orderIndex != null) 'orderIndex': orderIndex,
        if (waitDays != null) 'waitDays': waitDays,
        if (type != null) 'type': type,
        if (status != null) 'status': status,
        if (subjectTemplate != null) 'subjectTemplate': subjectTemplate,
        if (bodyTemplate != null) 'bodyTemplate': bodyTemplate,
        if (templateKey != null) 'templateKey': templateKey,
        if (templateVariables != null)
          'templateVariablesJson': templateVariables,
        if (instructionText != null) 'instructionText': instructionText,
      },
    );
    return _asMap(json);
  }

  /// Soft-delete (archive) a SequenceStep.
  Future<Map<String, dynamic>> archiveSequenceStep(String stepId) async {
    final json = await _apiClient.deleteJson(
      '/client/sequence-steps/$stepId',
      surface: ApiSurface.client,
    );
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
