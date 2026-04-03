import '../../core/network/api_client.dart';

class ClientPortalRepository {
  ClientPortalRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchOverview() async {
    final json = await _apiClient.getJson('/client/overview', surface: ApiSurface.client);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<dynamic>> fetchInvoices() async {
    final json = await _apiClient.getJson('/client/invoices', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreements() async {
    final json = await _apiClient.getJson('/client/agreements', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchStatements() async {
    final json = await _apiClient.getJson('/client/statements', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchReminders() async {
    final json = await _apiClient.getJson('/client/reminders', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchNotifications() async {
    final json = await _apiClient.getJson('/client/notifications', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchEmailDispatches() async {
    final json = await _apiClient.getJson('/client/email-dispatches', surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }
}
