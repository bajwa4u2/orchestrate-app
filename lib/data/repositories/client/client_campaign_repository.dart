import '../../../core/network/api_client.dart';

class ClientCampaignRepository {
  ClientCampaignRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchCampaignProfile() async {
    final profile = await _fetchProfile();
    final operational = await _fetchOperationalView();

    final campaign = _asMap(profile['campaign']).isNotEmpty
        ? _asMap(profile['campaign'])
        : _asMap(operational['campaign']);

    final metrics = <String, dynamic>{
      ..._asMap(profile['metrics']),
      ..._asMap(operational['metrics']),
    };

    final merged = <String, dynamic>{
      ...profile,
      if (campaign.isNotEmpty) 'campaign': campaign,
      'metrics': metrics,
      'execution': _firstMap(profile['execution'], operational['execution']),
      'mailbox': _firstMap(profile['mailbox'], operational['mailbox']),
      'imports': _firstMap(profile['imports'], operational['imports']),
      'permissions': _firstMap(profile['permissions'], operational['permissions']),
    };

    final leadsJson = await _fetchListSafe('/client/leads');
    final blocking = _buildBlockingSummary(leadsJson.map(_asMap).toList());
    merged['metrics'] = <String, dynamic>{
      ..._asMap(merged['metrics']),
      'blocked': blocking['blocked'],
      'blockedReasons': blocking['reasonCounts'],
    };

    return merged;
  }

  Future<Map<String, dynamic>> fetchCampaignProfileSafe() async {
    try {
      return await fetchCampaignProfile();
    } catch (_) {
      return const <String, dynamic>{};
    }
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

  Future<Map<String, dynamic>> _fetchProfile() async {
    try {
      final json = await _apiClient.getJson('/clients/me/campaign-overview', surface: ApiSurface.client);
      return _asMap(json);
    } catch (_) {
      final json = await _apiClient.getJson('/client/campaign-profile', surface: ApiSurface.client);
      return _asMap(json);
    }
  }

  Future<Map<String, dynamic>> _fetchOperationalView() async {
    try {
      final json = await _apiClient.getJson('/client/campaign-profile/operational-view', surface: ApiSurface.client);
      return _asMap(json);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<List<dynamic>> _fetchListSafe(String path) async {
    try {
      final json = await _apiClient.getJson(path, surface: ApiSurface.client);
      return json is List ? json : const <dynamic>[];
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

  Map<String, dynamic> _firstMap(dynamic first, dynamic second) {
    final firstMap = _asMap(first);
    if (firstMap.isNotEmpty) return firstMap;
    return _asMap(second);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }
}
