import 'package:orchestrate_app/core/network/api_client.dart';

/// Repository for all ops-console screens. Covers dispatch, transport,
/// campaigns, clients, jobs, and inventory subsystems.
class OpsConsoleRepository {
  OpsConsoleRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // ── Dispatch / Governance ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDispatchReviewQueue({
    int limit = 50,
  }) async {
    final json = await _api.getJson(
      '/operator/governance/review-queue',
      query: {'limit': '$limit'},
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<Map<String, dynamic>> fetchMessageTrace(String messageId) async {
    final json = await _api.getJson(
      '/operator/governance/messages/$messageId',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> retryMessage(
      String messageId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/governance/messages/$messageId/retry',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> clearCampaignFailed(String campaignId) async {
    final json = await _api.postJson(
      '/operator/governance/campaigns/$campaignId/clear-failed-dispatches',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  // ── Transport (mailboxes + domains) ─────────────────────────────

  Future<Map<String, dynamic>> fetchDeliverabilityOverview({
    String? clientId,
  }) async {
    final query = <String, String>{};
    if (clientId != null && clientId.isNotEmpty) query['clientId'] = clientId;
    final json = await _api.getJson(
      '/deliverability/overview',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> refreshMailboxHealth(String mailboxId) async {
    final json = await _api.postJson(
      '/deliverability/mailboxes/$mailboxId/refresh-health',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> prepareMailboxReconnect(
      String mailboxId) async {
    final json = await _api.postJson(
      '/deliverability/mailboxes/$mailboxId/reconnect',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> proofOutbound({
    required String mailboxId,
    required String to,
    String? subject,
  }) async {
    final json = await _api.postJson(
      '/operator/dispatch/proof-outbound',
      body: {
        'mailboxId': mailboxId,
        'to': to,
        if (subject != null) 'subject': subject,
      },
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  // ── Campaigns ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchCampaignLifecycle() async {
    final json = await _api.getJson(
      '/campaigns/lifecycle',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> activateCampaign(String campaignId) async {
    final json = await _api.postJson(
      '/campaigns/$campaignId/activate',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> clearContinuityHold(
      String campaignId) async {
    final json = await _api.postJson(
      '/execution/campaigns/$campaignId/clear-continuity-hold',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> forceDiscoveryNow(
      String campaignId) async {
    final json = await _api.postJson(
      '/signals/discovery/profiles/$campaignId/run-now',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> forceAdaptationRun(
      String campaignId) async {
    final json = await _api.postJson(
      '/adaptation/campaigns/$campaignId/run',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> pauseCampaign(String campaignId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/campaigns/$campaignId/pause',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> resumeCampaign(String campaignId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/campaigns/$campaignId/resume',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchCampaignAudit(String campaignId, {int? limit}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/campaigns/$campaignId/audit',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchImportBatch(String batchId) async {
    final json = await _api.getJson(
      '/operator/imports/$batchId',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> rePromoteImportBatch(String batchId) async {
    final json = await _api.postJson(
      '/operator/imports/$batchId/re-promote',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> reQualifyImportBatch(String batchId) async {
    final json = await _api.postJson(
      '/operator/imports/$batchId/re-qualify',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> sendMailboxReconnectLink(String mailboxId) async {
    final json = await _api.postJson(
      '/operator/mailboxes/$mailboxId/send-reconnect-link',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchMailboxAudit(String mailboxId, {int? limit}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/mailboxes/$mailboxId/audit',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> recheckDomainDns(String domainId) async {
    final json = await _api.postJson(
      '/operator/domains/$domainId/recheck-dns',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchDomainDnsInstructions(String domainId) async {
    final json = await _api.postJson(
      '/operator/domains/$domainId/send-dns-instructions',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchDomainAudit(String domainId, {int? limit}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/domains/$domainId/audit',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> retryJob(String jobId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/jobs/$jobId/retry',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> cancelJob(String jobId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/jobs/$jobId/cancel',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchJobAudit(String jobId, {int? limit}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/jobs/$jobId/audit',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> terminalMessage(String messageId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/governance/messages/$messageId/terminal',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> dismissMessage(String messageId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/governance/messages/$messageId/dismiss',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> escalateMessage(String messageId, {String? reason}) async {
    final json = await _api.postJson(
      '/operator/governance/messages/$messageId/escalate',
      body: {'reason': reason ?? ''},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchMessageAudit(String messageId, {int? limit}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/governance/messages/$messageId/audit',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  // ── Clients ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchReadinessBoard() async {
    final json = await _api.getJson(
      '/operator/readiness/board',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchOutboundReadiness({
    String? clientId,
  }) async {
    final query = <String, String>{};
    if (clientId != null && clientId.isNotEmpty) query['clientId'] = clientId;
    final json = await _api.getJson(
      '/operator/outbound-readiness',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  // ── Jobs ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchExecutionWorkspace({
    int? limit,
  }) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/execution',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> runJobNow(String jobId) async {
    final json = await _api.postJson(
      '/execution/jobs/$jobId/run',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> dispatchDueJobs() async {
    final json = await _api.postJson(
      '/execution/dispatch-due',
      body: {},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  // ── Generic passthrough ──────────────────────────────────────────
  // Used by the work queue screen to dispatch case actions by endpoint.

  Future<Map<String, dynamic>> rawPost(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final json = await _api.postJson(
      path,
      body: body,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> rawGet(String path,
      {Map<String, String>? query}) async {
    final json = await _api.getJson(
      path,
      query: query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchImportBatches({int? limit}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/imports',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchClientAudit(String clientId,
      {int? limit}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.getJson(
      '/operator/clients/$clientId/audit',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  Future<Map<String, dynamic>> fetchWorkQueue({
    int? limit,
    int? offset,
    String? workType,
    String? clientId,
    String? severity,
  }) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = '$limit';
    if (offset != null && offset > 0) query['offset'] = '$offset';
    if (workType != null && workType.isNotEmpty) query['workType'] = workType;
    if (clientId != null && clientId.isNotEmpty) query['clientId'] = clientId;
    if (severity != null && severity.isNotEmpty) query['severity'] = severity;
    final json = await _api.getJson(
      '/operator/work-queue',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(_asMap(json));
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static List _asList(dynamic v) => v is List ? v : [];
  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : {};
}
