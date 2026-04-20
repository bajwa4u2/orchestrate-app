import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';

class OperatorRepository {
  OperatorRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchCommandOverview() async {
    if (AppConfig.hasOperatorAccess) {
      final json = await _apiClient.getJson(
        '/operator/command/overview',
        surface: ApiSurface.operator,
      );
      return Map<String, dynamic>.from(json as Map);
    }
    final json = await _apiClient.getJson('/control/overview');
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchCommandWorkspace() async {
    final json = await _apiClient.getJson(
      '/operator/command',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchRevenueOverview() async {
    final json = await _apiClient.getJson(
      '/operator/revenue/overview',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchRecordsOverview() async {
    final json = await _apiClient.getJson(
      '/operator/records/overview',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchAuthContext() async {
    final json = await _apiClient.getJson(
      '/auth/context',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchDeliverabilityOverview({
    String? clientId,
  }) async {
    final query = <String, String>{
      if (AppConfig.operatorOrganizationId.isNotEmpty)
        'organizationId': AppConfig.operatorOrganizationId,
      if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
    };
    final json = await _apiClient.getJson('/deliverability/overview', query: query);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<dynamic>> fetchClients() => _fetchList(
        '/clients',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty)
            'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchCampaigns() => _fetchList(
        '/campaigns',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty)
            'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchLeads() => _fetchList(
        '/leads',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty)
            'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchReplies({String? clientId}) {
    if (clientId == null || clientId.trim().isEmpty) {
      return Future.value(const <dynamic>[]);
    }

    return _fetchList(
      '/replies',
      query: {
        'clientId': clientId.trim(),
      },
    );
  }

  Future<List<dynamic>> fetchMeetings() => _fetchList(
        '/meetings',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty)
            'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchInvoices() async {
    final json = await _apiClient.getJson(
      '/billing/invoices',
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreements() async {
    final json = await _apiClient.getJson(
      '/agreements',
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchStatements() async {
    final json = await _apiClient.getJson(
      '/statements',
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchSubscriptions() async {
    final json = await _apiClient.getJson(
      '/subscriptions',
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchTemplates() async {
    final json = await _apiClient.getJson(
      '/templates',
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchEmailDispatches() async {
    final json = await _apiClient.getJson(
      '/emails/dispatches',
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAlerts() async {
    final json = await _apiClient.getJson(
      '/notifications/alerts',
      surface: ApiSurface.operator,
    );
    final map = Map<String, dynamic>.from(json as Map);
    return (map['items'] as List? ?? const []).cast<dynamic>();
  }

  Future<Map<String, dynamic>> fetchInquiries({int limit = 8}) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries',
      query: {'limit': '$limit'},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchInquiryById(String inquiryId) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries/$inquiryId',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<Map<String, dynamic>>> fetchInquiryThread(String inquiryId) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries/$inquiryId/thread',
      surface: ApiSurface.operator,
    );

    final map = Map<String, dynamic>.from(json as Map);
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
    await _apiClient.postJson(
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
      '/operator/alerts/$alertId/resolve',
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
        if (scheduledAt != null && scheduledAt.trim().isNotEmpty)
          'scheduledAt': scheduledAt.trim(),
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
        if (scheduledAt != null && scheduledAt.trim().isNotEmpty)
          'scheduledAt': scheduledAt.trim(),
      },
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> dispatchDueJobs({
    int limit = 25,
  }) async {
    final json = await _apiClient.postJson(
      '/operator/dispatch-due',
      body: <String, dynamic>{'limit': limit},
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<List<dynamic>> fetchReminders() async {
    final json = await _apiClient.getJson(
      '/reminders',
      surface: ApiSurface.operator,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> _fetchList(String path, {Map<String, String>? query}) async {
    final json = await _apiClient.getJson(path, query: query);
    final map = Map<String, dynamic>.from(json as Map);
    return (map['items'] as List? ?? const []).cast<dynamic>();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }
}
