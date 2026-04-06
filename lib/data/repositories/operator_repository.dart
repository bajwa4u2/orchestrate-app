import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';

class OperatorRepository {
  OperatorRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchCommandOverview() async {
    if (AppConfig.hasOperatorAccess) {
      final json = await _apiClient.getJson('/operator/command/overview', surface: ApiSurface.operator);
      return Map<String, dynamic>.from(json as Map);
    }
    final json = await _apiClient.getJson('/control/overview');
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchRevenueOverview() async {
    final json = await _apiClient.getJson('/operator/revenue/overview', surface: ApiSurface.operator);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchRecordsOverview() async {
    final json = await _apiClient.getJson('/operator/records/overview', surface: ApiSurface.operator);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchPublicInquiries({int limit = 8}) async {
    final json = await _apiClient.getJson(
      '/operator/inquiries',
      query: {'limit': '$limit'},
      surface: ApiSurface.operator,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchAuthContext() async {
    final json = await _apiClient.getJson('/auth/context', surface: ApiSurface.operator);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> fetchDeliverabilityOverview() async {
    final query = {
      if (AppConfig.operatorOrganizationId.isNotEmpty) 'organizationId': AppConfig.operatorOrganizationId,
    };
    final json = await _apiClient.getJson('/deliverability/overview', query: query);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<List<dynamic>> fetchClients() => _fetchList(
        '/clients',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty) 'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchCampaigns() => _fetchList(
        '/campaigns',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty) 'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchLeads() => _fetchList(
        '/leads',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty) 'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchReplies() => _fetchList(
        '/replies',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty) 'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchMeetings() => _fetchList(
        '/meetings',
        query: {
          if (AppConfig.operatorOrganizationId.isNotEmpty) 'organizationId': AppConfig.operatorOrganizationId,
        },
      );

  Future<List<dynamic>> fetchInvoices() async {
    final json = await _apiClient.getJson('/billing/invoices', surface: ApiSurface.operator);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreements() async {
    final json = await _apiClient.getJson('/agreements', surface: ApiSurface.operator);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchStatements() async {
    final json = await _apiClient.getJson('/statements', surface: ApiSurface.operator);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchSubscriptions() async {
    final json = await _apiClient.getJson('/subscriptions', surface: ApiSurface.operator);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchTemplates() async {
    final json = await _apiClient.getJson('/templates', surface: ApiSurface.operator);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchEmailDispatches() async {
    final json = await _apiClient.getJson('/emails/dispatches', surface: ApiSurface.operator);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAlerts() async {
    final json = await _apiClient.getJson('/notifications/alerts', surface: ApiSurface.operator);
    final map = Map<String, dynamic>.from(json as Map);
    return (map['items'] as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchReminders() async {
    final json = await _apiClient.getJson('/reminders', surface: ApiSurface.operator);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> _fetchList(String path, {Map<String, String>? query}) async {
    final json = await _apiClient.getJson(path, query: query);
    final map = Map<String, dynamic>.from(json as Map);
    return (map['items'] as List? ?? const []).cast<dynamic>();
  }
}
