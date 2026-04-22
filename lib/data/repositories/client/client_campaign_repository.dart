import '../../../core/network/api_client.dart';

class ClientCampaignRepository {
  ClientCampaignRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchCampaignProfile() async {
    final json = await _apiClient.getJson(
      '/client/campaign-profile',
      surface: ApiSurface.client,
    );
    final profile = Map<String, dynamic>.from(json as Map);

    final leadsJson = await _apiClient.getJson(
      '/client/leads',
      surface: ApiSurface.client,
    );
    final leads = (leadsJson as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final blocking = _buildBlockingSummary(leads);
    final metrics = _asMap(profile['metrics']);
    profile['metrics'] = <String, dynamic>{
      ...metrics,
      'blocked': blocking['blocked'],
      'blockedReasons': blocking['reasonCounts'],
    };

    return profile;
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
