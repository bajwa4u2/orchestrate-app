import '../../../core/network/api_client.dart';
import 'client_mailbox_repository.dart';

class ClientOutreachRepository {
  ClientOutreachRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _mailboxRepository = ClientMailboxRepository(apiClient: apiClient);

  final ApiClient _apiClient;
  final ClientMailboxRepository _mailboxRepository;

  Future<List<dynamic>> fetchReplies({int limit = 12}) async {
    return _mailboxRepository.fetchRepliesSafe(limit: limit);
  }

  Future<List<dynamic>> fetchEmailDispatches() async {
    return _mailboxRepository.fetchEmailDispatchesSafe();
  }

  Future<List<dynamic>> fetchNotifications() async {
    return _mailboxRepository.fetchNotificationsSafe();
  }
}
