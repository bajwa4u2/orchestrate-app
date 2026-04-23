import '../../core/network/api_client.dart';

class OperatorRepository {
  OperatorRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchCommandOverview() async {
    final json = await _apiClient.getJson(
      '/operator/command/overview',
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchCommandWorkspace() async {
    final json = await _apiClient.getJson(
      '/operator/command',
      surface: ApiSurface.operator,
    );
    final workspace = _asMap(json);
    final leads = await fetchLeads();
    workspace['blocking'] = _buildBlockingSummary(leads);
    return workspace;
  }

  Future<Map<String, dynamic>> fetchRevenueOverview({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/billing/overview',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchRecordsOverview({String? clientId}) async {
    final agreements = await fetchAgreements(clientId: clientId);
    final statements = await fetchStatements(clientId: clientId);
    final reminders = await fetchReminders(clientId: clientId);
    final templates = await fetchTemplates(clientId: clientId);

    return <String, dynamic>{
      'summary': 'Formal records, templates, and reminders remain visible from operator control.',
      'agreementsCount': agreements.length,
      'statementsCount': statements.length,
      'remindersCount': reminders.length,
      'templatesCount': templates.length,
    };
  }

  Future<Map<String, dynamic>> fetchAuthContext() async {
    final json = await _apiClient.getJson(
      '/auth/context',
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchDeliverabilityOverview({
    String? clientId,
  }) async {
    final json = await _apiClient.getJson(
      '/deliverability/overview',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<List<dynamic>> fetchClients() => _fetchList(
        '/clients',
        surface: ApiSurface.operator,
      );

  Future<List<dynamic>> fetchCampaigns() => _fetchList(
        '/campaigns',
        surface: ApiSurface.operator,
      );

  Future<List<dynamic>> fetchLeads() => _fetchList(
        '/leads',
        surface: ApiSurface.operator,
      );

  Future<List<dynamic>> fetchReplies({String? clientId}) => _fetchList(
        '/replies',
        query: {
          if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
        },
        surface: ApiSurface.operator,
      );

  Future<List<dynamic>> fetchMeetings({String? clientId}) => _fetchList(
        '/meetings',
        query: {
          if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
        },
        surface: ApiSurface.operator,
      );

  Future<List<dynamic>> fetchInvoices({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/billing/invoices',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreements({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/agreements',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchStatements({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/statements',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchSubscriptions({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/subscriptions',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchTemplates({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/templates',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchEmailDispatches({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/emails/dispatches',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAlerts() async {
    final json = await _apiClient.getJson(
      '/notifications/alerts',
      surface: ApiSurface.operator,
    );
    final map = _asMap(json);
    return (map['items'] as List? ?? const []).cast<dynamic>();
  }

  Future<Map<String, dynamic>> fetchInquiries({int limit = 8}) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries',
      query: {'limit': '$limit'},
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> fetchInquiryById(String inquiryId) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries/$inquiryId',
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<List<Map<String, dynamic>>> fetchInquiryThread(String inquiryId) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries/$inquiryId/thread',
      surface: ApiSurface.operator,
    );

    final map = _asMap(json);
    final items = (map['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return items;
  }

  Future<List<Map<String, dynamic>>> fetchInquiryNotes(String inquiryId) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries/$inquiryId/notes',
      surface: ApiSurface.operator,
    );

    return (json as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> updateInquiryStatus({
    required String inquiryId,
    required String status,
  }) async {
    await _apiClient.patchJson(
      '/operator/inquiries/$inquiryId/status',
      body: {'status': status},
      surface: ApiSurface.operator,
    );
  }

  Future<void> sendInquiryReply({
    required String inquiryId,
    required String content,
  }) async {
    await _apiClient.postJson(
      '/operator/inquiries/$inquiryId/reply',
      body: {'content': content},
      surface: ApiSurface.operator,
    );
  }

  Future<void> addInquiryNote({
    required String inquiryId,
    required String content,
  }) async {
    await _apiClient.postJson(
      '/operator/inquiries/$inquiryId/notes',
      body: {'content': content},
      surface: ApiSurface.operator,
    );
  }

  Future<Map<String, dynamic>> activateCampaign(String campaignId) async {
    final json = await _apiClient.postJson(
      '/campaigns/$campaignId/activate',
      body: const <String, dynamic>{},
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> resolveAlert(String alertId) async {
    final json = await _apiClient.postJson(
      '/notifications/alerts/$alertId/resolve',
      body: const <String, dynamic>{},
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> refreshMailboxHealth(String mailboxId) async {
    final json = await _apiClient.postJson(
      '/deliverability/mailboxes/$mailboxId/refresh-health',
      body: const <String, dynamic>{},
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> runJob({
    required String jobId,
    bool force = false,
  }) async {
    final json = await _apiClient.postJson(
      '/execution/jobs/$jobId/run',
      body: <String, dynamic>{
        if (force) 'force': true,
      },
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> queueLeadFirstSend({
    required String leadId,
    String? scheduledAt,
  }) async {
    final json = await _apiClient.postJson(
      '/execution/leads/$leadId/queue-first-send',
      body: <String, dynamic>{
        if (scheduledAt != null && scheduledAt.trim().isNotEmpty) 'scheduledAt': scheduledAt.trim(),
      },
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> queueLeadFollowUp({
    required String leadId,
    String? scheduledAt,
  }) async {
    final json = await _apiClient.postJson(
      '/execution/leads/$leadId/queue-follow-up',
      body: <String, dynamic>{
        if (scheduledAt != null && scheduledAt.trim().isNotEmpty) 'scheduledAt': scheduledAt.trim(),
      },
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> dispatchDueJobs({
    int limit = 25,
  }) async {
    final json = await _apiClient.postJson(
      '/execution/dispatch-due',
      body: <String, dynamic>{'limit': limit},
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<List<dynamic>> fetchReminders({String? clientId}) async {
    final json = await _apiClient.getJson(
      '/reminders',
      query: {
        if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
      },
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> _fetchList(
    String path, {
    Map<String, String>? query,
    ApiSurface surface = ApiSurface.operator,
  }) async {
    final json = await _apiClient.getJson(path, query: query, surface: surface);
    final map = _asMap(json);
    return (map['items'] as List? ?? const []).cast<dynamic>();
  }

  Map<String, dynamic> _buildBlockingSummary(List<dynamic> leads) {
    var blocked = 0;
    final reasonCounts = <String, int>{};

    for (final item in leads) {
      final lead = _asMap(item);
      final reasons = _extractBlockReasons(lead);
      if (reasons.isEmpty) continue;
      blocked += 1;
      for (final reason in reasons) {
        reasonCounts.update(reason, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final ordered = reasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return <String, dynamic>{
      'blocked': blocked,
      'reasonCounts': <String, dynamic>{
        for (final entry in ordered) entry.key: entry.value,
      },
    };
  }

  List<String> _extractBlockReasons(Map<String, dynamic> lead) {
    final metadata = _asMap(lead['metadataJson']);
    final rootReasons = _asStringList(metadata['blockReasons']);
    if (rootReasons.isNotEmpty) return rootReasons;
    final messageGeneration = _asMap(metadata['messageGeneration']);
    return _asStringList(messageGeneration['reasons']);
  }

  List<String> _asStringList(dynamic value) {
    return (value as List? ?? const [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }
}
