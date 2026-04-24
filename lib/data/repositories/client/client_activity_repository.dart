import '../../../core/network/api_client.dart';
import 'client_campaign_repository.dart';
import 'client_contacts_repository.dart';
import 'client_mailbox_repository.dart';

class ClientActivityRepository {
  ClientActivityRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchActivity() async {
    final campaignRepository = ClientCampaignRepository(apiClient: _apiClient);
    final contactsRepository = ClientContactsRepository(apiClient: _apiClient);
    final mailboxRepository = ClientMailboxRepository(apiClient: _apiClient);

    final results = await Future.wait<dynamic>([
      campaignRepository.fetchCampaignProfile(),
      contactsRepository.fetchContactsSafe(),
      mailboxRepository.fetchRepliesSafe(limit: 50),
      mailboxRepository.fetchEmailDispatchesSafe(),
      mailboxRepository.fetchNotificationsSafe(),
    ]);

    final campaign = _asMap(results[0]);
    final contacts = _asList(results[1]);
    final replies = _asList(results[2]);
    final dispatches = _asList(results[3]);
    final notifications = _asList(results[4]);

    final meetings = replies
        .map(_asMap)
        .map((item) => _asMap(item['meeting']))
        .where((item) => item.isNotEmpty)
        .toList();

    return <String, dynamic>{
      'campaign': campaign,
      'activity': <String, dynamic>{
        'leadCount': contacts.length,
        'replies': replies.length,
        'meetings': meetings.length,
      },
      'communications': <String, dynamic>{
        'emailDispatches': dispatches.length,
        'openNotifications': notifications.length,
      },
      'replies': replies,
      'meetings': meetings,
      'dispatches': dispatches,
      'notifications': notifications,
    };
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) =>
      value is List ? value : const <dynamic>[];
}
