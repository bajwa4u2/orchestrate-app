import '../../../core/network/api_client.dart';

class ClientCampaignRepository {
  ClientCampaignRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchCampaignProfile() async {
    final overview = await _safeGetMap('/client/campaign/overview');
    final profileJson = await _apiClient.getJson(
      '/client/campaign-profile',
      surface: ApiSurface.client,
    );
    final profile = Map<String, dynamic>.from(profileJson as Map);

    final operationalView = await _safeGetMap('/client/campaign-profile/operational-view');
    final leadsJson = await _safeGetList('/client/leads');
    final leads = leadsJson
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final blocking = _buildBlockingSummary(leads);
    final metrics = _asMap(profile['metrics']);
    final overviewExecution = _asMap(overview['execution']);
    final overviewMailbox = _asMap(overview['mailbox']);
    final overviewImports = _asMap(overview['imports']);
    final overviewPermissions = _asMap(overview['permissions']);

    return <String, dynamic>{
      ...profile,
      if (overview.isNotEmpty) ...overview,
      if (operationalView.isNotEmpty) 'operationalView': operationalView,
      'metrics': <String, dynamic>{
        ...metrics,
        if (overviewExecution.isNotEmpty) ...overviewExecution,
        'blocked': blocking['blocked'],
        'blockedReasons': blocking['reasonCounts'],
      },
      if (profile['execution'] == null && overviewExecution.isNotEmpty) 'execution': overviewExecution,
      if (profile['mailbox'] == null && overviewMailbox.isNotEmpty) 'mailbox': overviewMailbox,
      if (profile['imports'] == null && overviewImports.isNotEmpty) 'imports': overviewImports,
      if (profile['permissions'] == null && overviewPermissions.isNotEmpty) 'permissions': overviewPermissions,
    };
  }

  Future<Map<String, dynamic>> updateCampaignProfile({
    required Map<String, dynamic> profile,
  }) async {
    final json = await _apiClient.patchJson(
      '/client/campaign-profile',
      surface: ApiSurface.client,
      body: profile,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> startCampaign() async {
    final json = await _apiClient.postJson(
      '/client/campaign-profile/start',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> restartCampaign() async {
    final json = await _apiClient.postJson(
      '/client/campaign-profile/restart',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> acceptRepresentationAuth() async {
    final json = await _apiClient.postJson(
      '/clients/me/representation-auth/accept',
      body: const <String, dynamic>{},
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> _safeGetMap(String path) async {
    try {
      final json = await _apiClient.getJson(path, surface: ApiSurface.client);
      if (json is Map) {
        return Map<String, dynamic>.from(json);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<List<dynamic>> _safeGetList(String path) async {
    try {
      final json = await _apiClient.getJson(path, surface: ApiSurface.client);
      return (json as List? ?? const []).cast<dynamic>();
    } catch (_) {
      return const <dynamic>[];
    }
  }

  Map<String, dynamic> _buildBlockingSummary(List<Map<String, dynamic>> leads) {
    var blocked = 0;
    final reasonCounts = <String, int>{};

    for (final lead in leads) {
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
