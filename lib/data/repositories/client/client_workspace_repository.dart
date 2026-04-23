import '../../../core/network/api_client.dart';

class ClientWorkspaceRepository {
  ClientWorkspaceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    try {
      final json = await _apiClient.getJson(
        '/client/overview',
        surface: ApiSurface.client,
      );
      return Map<String, dynamic>.from(json as Map);
    } catch (_) {
      final profile = await _safeGetMap('/clients/me/profile');
      final campaignOverview = await _safeGetMap('/clients/me/campaign-overview');
      final campaignReadOverview = await _safeGetMap('/client/campaign/overview');
      final notifications = await _safeGetList('/client/notifications');
      final emailDispatches = await _safeGetList('/client/email-dispatches');
      final leads = await _safeGetList('/client/leads');
      final replies = await _safeGetList('/replies');

      final mergedCampaignOverview = campaignOverview.isNotEmpty
          ? campaignOverview
          : campaignReadOverview;
      final mailbox = _asMap(mergedCampaignOverview['mailbox']);
      final imports = _asMap(mergedCampaignOverview['imports']);
      final permissions = _asMap(mergedCampaignOverview['permissions']);
      final campaign = _asMap(mergedCampaignOverview['campaign']);
      final execution = _asMap(mergedCampaignOverview['execution']);

      return <String, dynamic>{
        'client': _mergeMaps(
          _asMap(profile['profile']).isNotEmpty ? _asMap(profile['profile']) : profile,
          <String, dynamic>{
            if (campaign.isNotEmpty) 'campaigns': [campaign],
          },
        ),
        'activity': <String, dynamic>{
          'leadCount': leads.length,
          'contactCount': _countFrom(profile, 'contactCount'),
          'channelCount': _countFrom(profile, 'channelCount'),
          'sendableLeadCount': _countFrom(mergedCampaignOverview, 'sendableLeadCount'),
          'replies': replies.length,
          'meetings': _countFrom(mergedCampaignOverview, 'meetingCount'),
          'meetingCount': _countFrom(mergedCampaignOverview, 'meetingCount'),
          'handoffPending': _countFrom(mergedCampaignOverview, 'handoffPending'),
        },
        'communications': <String, dynamic>{
          'openNotifications': notifications.length,
          'emailDispatches': emailDispatches.length,
        },
        'mailbox': mailbox,
        'imports': imports,
        'execution': execution,
        'permissions': permissions,
      };
    }
  }

  Future<List<dynamic>> fetchLeads() async {
    final json = await _apiClient.getJson(
      '/client/leads',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchNotifications() async {
    final json = await _apiClient.getJson(
      '/client/notifications',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<Map<String, dynamic>?> fetchSubscription() async {
    final json = await _apiClient.getJson(
      '/billing/subscription',
      surface: ApiSurface.client,
    );

    if (json == null) return null;
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> _safeGetMap(String path) async {
    try {
      final json = await _apiClient.getJson(path, surface: ApiSurface.client);
      if (json is Map) {
        return Map<String, dynamic>.from(json);
      }
      return const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<List<dynamic>> _safeGetList(String path) async {
    try {
      final json = await _apiClient.getJson(path, surface: ApiSurface.client);
      return (json as List? ?? const []).cast<dynamic>();
    } catch (_) {
      return const <dynamic>[];
    }
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

int _countFrom(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

Map<String, dynamic> _mergeMaps(Map<String, dynamic> left, Map<String, dynamic> right) {
  return <String, dynamic>{...left, ...right};
}
