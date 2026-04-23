import '../../../core/network/api_client.dart';
import 'client_billing_repository.dart';
import 'client_contacts_repository.dart';
import 'client_home_repository.dart';
import 'client_mailbox_repository.dart';

class ClientWorkspaceRepository {
  ClientWorkspaceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _homeRepository = ClientHomeRepository(apiClient: apiClient),
        _contactsRepository = ClientContactsRepository(apiClient: apiClient),
        _mailboxRepository = ClientMailboxRepository(apiClient: apiClient),
        _billingRepository = ClientBillingRepository(apiClient: apiClient);

  final ApiClient _apiClient;
  final ClientHomeRepository _homeRepository;
  final ClientContactsRepository _contactsRepository;
  final ClientMailboxRepository _mailboxRepository;
  final ClientBillingRepository _billingRepository;

  Future<Map<String, dynamic>> fetchOverview() {
    return _homeRepository.fetchHome();
  }

  Future<List<dynamic>> fetchLeads() async {
    final items = await _contactsRepository.fetchContactsSafe();
    return items;
  }

  Future<List<dynamic>> fetchNotifications() async {
    final items = await _mailboxRepository.fetchNotificationsSafe();
    return items;
  }

  Future<Map<String, dynamic>?> fetchSubscription() {
    return _billingRepository.fetchSubscriptionSafe();
  }

  Future<Map<String, dynamic>> fetchCampaignOverview() async {
    try {
      final json = await _apiClient.getJson('/client/campaign/overview', surface: ApiSurface.client);
      return _asMap(json);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }
}
