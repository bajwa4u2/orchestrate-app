import '../../core/network/api_client.dart';

class OperatorRepository {
  OperatorRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchControlOverview() async {
    final json = await _apiClient.getJson(
      '/control/overview',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchCommandOverview() async {
    try {
      final json = await _apiClient.getJson(
        '/operator/command/overview',
        surface: ApiSurface.operator,
      );
      return Map<String, dynamic>.from(json as Map);
    } catch (_) {
      return fetchControlOverview();
    }
  }

  Future<Map<String, dynamic>> fetchCommandWorkspace() async {
    final control = await fetchControlOverview();
    final clients = await fetchClients();
    final campaigns = await fetchCampaigns();
    final leads = await fetchLeads();
    final dispatches = await fetchEmailDispatches();
    final alerts = await fetchAlerts();
    final inquiries = await fetchInquiries(limit: 12);
    final deliverability = await fetchDeliverabilityOverview();

    final mailboxes = (deliverability['mailboxes'] as List? ?? const []).cast<dynamic>();
    final failedJobs = const <dynamic>[];
    final pulseToday = _asMap(control['today']);
    final pulseExecution = _asMap(control['execution']);
    final pulseDeliverability = _buildDeliverabilityPulse(deliverability);
    final pulseTotals = _asMap(control['totals']);

    return <String, dynamic>{
      'title': 'Operator command',
      'subtitle':
          'Control shows live totals, inbound pressure, deliverability posture, and outbound movement from one surface.',
      'pulse': <String, dynamic>{
        'totals': pulseTotals,
        'today': pulseToday,
        'execution': pulseExecution,
        'deliverability': pulseDeliverability,
      },
      'health': <String, dynamic>{
        'summary': <String, dynamic>{
          'open': '${_asMap(control['alerts'])['open'] ?? 0}',
        },
        'alerts': alerts,
        'deliverability': deliverability,
      },
      'execution': <String, dynamic>{
        'emailDispatches': dispatches,
        'failedJobs': failedJobs,
      },
      'outreach': <String, dynamic>{
        'campaigns': campaigns,
      },
      'clients': <String, dynamic>{
        'items': clients,
      },
      'conversations': <String, dynamic>{
        'inquiries': (inquiries['items'] as List? ?? const []).cast<dynamic>(),
      },
      'attention': _buildAttention(
        alerts: alerts,
        inquiries: (inquiries['items'] as List? ?? const []).cast<dynamic>(),
        campaigns: campaigns,
        deliverability: deliverability,
      ),
      'blocking': _buildBlockingSummary(leads),
    };
  }

  Future<Map<String, dynamic>> fetchRevenueOverview() async {
    final billing = await _apiClient.getJson(
      '/billing/overview',
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(billing as Map);
  }

  Future<Map<String, dynamic>> fetchRecordsOverview() async {
    final agreements = await fetchAgreements();
    final statements = await fetchStatements();
    final reminders = await fetchReminders();
    final templates = await fetchTemplates();

    return <String, dynamic>{
      'agreements': agreements,
      'statements': statements,
      'reminders': reminders,
      'templates': templates,
      'totals': <String, dynamic>{
        'agreements': agreements.length,
        'statements': statements.length,
        'reminders': reminders.length,
        'templates': templates.length,
      },
    };
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
      if (clientId != null && clientId.trim().isNotEmpty) 'clientId': clientId.trim(),
    };
    final json = await _apiClient.getJson(
      '/deliverability/overview',
      query: query,
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<dynamic>> fetchClients() => _fetchItems('/clients');

  Future<List<dynamic>> fetchCampaigns() => _fetchItems('/campaigns');

  Future<List<dynamic>> fetchLeads() => _fetchItems('/leads');

  Future<List<dynamic>> fetchReplies({String? clientId}) {
    if (clientId == null || clientId.trim().isEmpty) {
      return Future.value(const <dynamic>[]);
    }

    return _fetchList('/replies', query: {'clientId': clientId.trim()});
  }

  Future<List<dynamic>> fetchMeetings() => _fetchItems('/meetings');

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
      '/execution/dispatch-due',
      body: <String, dynamic>{'limit': limit},
      surface: ApiSurface.operator,
    );
    return _asMap(json);
  }

  Future<Map<String, dynamic>> diagnoseSystem({
    required String issue,
    String? expectedBehavior,
    String? observedBehavior,
    List<String> logs = const <String>[],
  }) async {
    final json = await _apiClient.postJson(
      '/ai/system/diagnose',
      body: <String, dynamic>{
        'scope': 'SYSTEM',
        'issue': issue.trim(),
        if (expectedBehavior != null && expectedBehavior.trim().isNotEmpty)
          'expectedBehavior': expectedBehavior.trim(),
        if (observedBehavior != null && observedBehavior.trim().isNotEmpty)
          'observedBehavior': observedBehavior.trim(),
        if (logs.isNotEmpty)
          'logs': logs
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        'doNotTouch': const <String>['orchestrate_backend'],
      },
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

  Future<List<dynamic>> _fetchItems(String path) async {
    final json = await _apiClient.getJson(path, surface: ApiSurface.operator);
    final map = Map<String, dynamic>.from(json as Map);
    return (map['items'] as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> _fetchList(String path, {Map<String, String>? query}) async {
    final json = await _apiClient.getJson(
      path,
      query: query,
      surface: ApiSurface.operator,
    );
    if (json is List) return json.cast<dynamic>();
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      return (map['items'] as List? ?? const []).cast<dynamic>();
    }
    return const <dynamic>[];
  }

  List<dynamic> _buildAttention({
    required List<dynamic> alerts,
    required List<dynamic> inquiries,
    required List<dynamic> campaigns,
    required Map<String, dynamic> deliverability,
  }) {
    final items = <dynamic>[];
    items.addAll(alerts.take(6));
    items.addAll(inquiries.take(3));

    final degradedMailboxes = (deliverability['mailboxes'] as List? ?? const [])
        .whereType<Map>()
        .where((item) {
          final health = '${item['healthStatus'] ?? item['status'] ?? ''}'.toUpperCase();
          return health == 'DEGRADED' || health == 'CRITICAL';
        })
        .take(3)
        .map((item) => <String, dynamic>{
              'title': item['email'] ?? item['mailboxEmail'] ?? 'Mailbox needs attention',
              'severity': item['healthStatus'] ?? item['status'] ?? 'DEGRADED',
              'status': item['status'] ?? '',
              'source': 'deliverability',
              'createdAt': item['updatedAt'] ?? item['createdAt'],
            });
    items.addAll(degradedMailboxes);

    if (items.length < 6) {
      items.addAll(campaigns.take(6 - items.length).whereType<Map>().map((item) => <String, dynamic>{
            'title': item['name'] ?? 'Campaign',
            'severity': item['status'] ?? 'ACTIVE',
            'status': item['status'] ?? '',
            'source': 'campaign',
            'createdAt': item['createdAt'],
            'campaignId': item['id'],
          }));
    }
    return items;
  }

  Map<String, dynamic> _buildDeliverabilityPulse(Map<String, dynamic> deliverability) {
    final mailboxes = (deliverability['mailboxes'] as List? ?? const []).whereType<Map>().toList();
    final healthy = mailboxes.where((item) {
      final health = '${item['healthStatus'] ?? item['status'] ?? ''}'.toUpperCase();
      return health != 'DEGRADED' && health != 'CRITICAL';
    }).length;
    final degraded = mailboxes.length - healthy;

    return <String, dynamic>{
      'healthyMailboxes': healthy,
      'degradedMailboxes': degraded,
    };
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
