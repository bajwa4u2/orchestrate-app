import '../../core/network/api_client.dart';
import '../models/control_overview.dart';
import '../models/deliverability_overview.dart';
import '../models/health_snapshot.dart';
import '../models/resource_item.dart';

class ControlRepository {
  ControlRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<ControlOverview> fetchOverview() async {
    final json = await _apiClient.getJson('/control/overview') as Map<String, dynamic>;
    return ControlOverview.fromJson(json);
  }

  Future<List<ResourceItem>> fetchClients() => _fetchList('/clients', ResourceKind.client);
  Future<List<ResourceItem>> fetchCampaigns() => _fetchList('/campaigns', ResourceKind.campaign);
  Future<List<ResourceItem>> fetchLeads() => _fetchList('/leads', ResourceKind.lead);
  Future<List<ResourceItem>> fetchReplies() => _fetchList('/replies', ResourceKind.reply);
  Future<List<ResourceItem>> fetchMeetings() => _fetchList('/meetings', ResourceKind.meeting);

  Future<HealthSnapshot> fetchHealth() async {
    final json = await _apiClient.getJson('/health') as Map<String, dynamic>;
    return HealthSnapshot.fromJson(json);
  }

  Future<DeliverabilityOverview> fetchDeliverabilityOverview() async {
    final json = await _apiClient.getJson('/deliverability/overview') as Map<String, dynamic>;
    return DeliverabilityOverview.fromJson(json);
  }

  Future<List<ResourceItem>> _fetchList(String path, ResourceKind kind) async {
    final json = await _apiClient.getJson(path) as Map<String, dynamic>;
    final items = (json['items'] as List? ?? const []).cast<Map>().map((raw) => ResourceItem.fromJson(raw.cast<String, dynamic>(), kind)).toList();
    return items;
  }
}
