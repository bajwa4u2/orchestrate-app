import '../../../core/network/api_client.dart';
import 'client_account_repository.dart';
import 'client_billing_repository.dart';
import 'client_campaign_repository.dart';
import 'client_contacts_repository.dart';
import 'client_mailbox_repository.dart';

class ClientHomeRepository {
  ClientHomeRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchHome() async {
    try {
      final json = await _apiClient.getJson('/client/overview', surface: ApiSurface.client);
      return _asMap(json);
    } catch (_) {
      return _composeFromCoreSources();
    }
  }

  Future<Map<String, dynamic>> _composeFromCoreSources() async {
    final accountRepository = ClientAccountRepository(apiClient: _apiClient);
    final billingRepository = ClientBillingRepository(apiClient: _apiClient);
    final campaignRepository = ClientCampaignRepository(apiClient: _apiClient);
    final contactsRepository = ClientContactsRepository(apiClient: _apiClient);
    final mailboxRepository = ClientMailboxRepository(apiClient: _apiClient);

    final results = await Future.wait<dynamic>([
      accountRepository.fetchClientProfileSafe(),
      billingRepository.fetchSubscriptionSafe(),
      billingRepository.fetchAgreementsSafe(),
      campaignRepository.fetchCampaignProfile(),
      contactsRepository.fetchContactsSafe(),
      mailboxRepository.fetchRepliesSafe(limit: 50),
      mailboxRepository.fetchEmailDispatchesSafe(),
      mailboxRepository.fetchNotificationsSafe(),
    ]);

    final profile = _asMap(results[0]);
    final subscription = _asMap(results[1]);
    final agreements = _asList(results[2]);
    final campaign = _asMap(results[3]);
    final contacts = _asList(results[4]);
    final replies = _asList(results[5]);
    final dispatches = _asList(results[6]);
    final notifications = _asList(results[7]);

    final sendableLeadCount = contacts.where((item) {
      final map = _asMap(item);
      final email = _string(map['email']);
      final status = _string(map['status']).toUpperCase();
      return email.isNotEmpty && status != 'SUPPRESSED';
    }).length;

    final meetingCount = replies.where((item) {
      final map = _asMap(item);
      final meeting = _asMap(map['meeting']);
      return meeting.isNotEmpty;
    }).length;

    return <String, dynamic>{
      'client': profile,
      'billing': <String, dynamic>{
        'subscription': subscription,
        'agreementCount': agreements.length,
      },
      'activity': <String, dynamic>{
        'leadCount': contacts.length,
        'contactCount': contacts.length,
        'sendableLeadCount': sendableLeadCount,
        'replies': replies.length,
        'meetings': meetingCount,
      },
      'communications': <String, dynamic>{
        'openNotifications': notifications.length,
        'emailDispatches': dispatches.length,
      },
      'campaign': campaign,
    };
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  String _string(dynamic value) => value == null ? '' : value.toString().trim();
}
