import '../models/control_overview.dart';
import '../models/deliverability_overview.dart';
import '../models/health_snapshot.dart';
import '../models/resource_item.dart';
import 'operator_repository.dart';

class ControlRepository {
  ControlRepository({OperatorRepository? operatorRepository})
      : _operatorRepository = operatorRepository ?? OperatorRepository();

  final OperatorRepository _operatorRepository;

  Future<ControlOverview> fetchOverview() async {
    final json = await _operatorRepository.fetchControlOverview();
    return ControlOverview.fromJson(json);
  }

  Future<List<ResourceItem>> fetchClients() async {
    final items = await _operatorRepository.fetchClients();
    return _mapItems(items, ResourceKind.client);
  }

  Future<List<ResourceItem>> fetchCampaigns() async {
    final items = await _operatorRepository.fetchCampaigns();
    return _mapItems(items, ResourceKind.campaign);
  }

  Future<List<ResourceItem>> fetchLeads() async {
    final items = await _operatorRepository.fetchLeads();
    return _mapItems(items, ResourceKind.lead);
  }

  Future<List<ResourceItem>> fetchReplies() async {
    final clients = await _operatorRepository.fetchClients();
    String? firstClientId;
    for (final item in clients) {
      if (item is! Map) continue;
      final id = item['id'];
      if (id == null) continue;
      final value = '$id'.trim();
      if (value.isEmpty) continue;
      firstClientId = value;
      break;
    }

    if (firstClientId == null) return const <ResourceItem>[];

    final items = await _operatorRepository.fetchReplies(clientId: firstClientId);
    return _mapItems(items, ResourceKind.reply);
  }

  Future<List<ResourceItem>> fetchMeetings() async {
    final items = await _operatorRepository.fetchMeetings();
    return _mapItems(items, ResourceKind.meeting);
  }

  Future<HealthSnapshot> fetchHealth() async {
    final overview = await _operatorRepository.fetchControlOverview();
    return HealthSnapshot.fromJson({
      'status': _read(_asMap(overview['system']), 'posture', fallback: 'live'),
      'timestamp': DateTime.now().toIso8601String(),
      'uptime': 'control-overview',
    });
  }

  Future<DeliverabilityOverview> fetchDeliverabilityOverview() async {
    final json = await _operatorRepository.fetchDeliverabilityOverview();
    final mailboxes = (json['mailboxes'] as List? ?? const []).length;
    final degraded = (json['mailboxes'] as List? ?? const [])
        .whereType<Map>()
        .where((item) {
          final health = '${item['healthStatus'] ?? item['status'] ?? ''}'.toUpperCase();
          return health == 'DEGRADED' || health == 'CRITICAL';
        })
        .length;

    return DeliverabilityOverview.fromJson({
      'activeMailboxes': mailboxes,
      'degradedMailboxes': degraded,
    });
  }

  List<ResourceItem> _mapItems(List<dynamic> items, ResourceKind kind) {
    return items
        .whereType<Map>()
        .map((raw) => ResourceItem.fromJson(raw.cast<String, dynamic>(), kind))
        .toList();
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

String _read(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final value = map[key];
  if (value == null) return fallback;
  if (value is String) return value.trim().isEmpty ? fallback : value.trim();
  return '$value';
}
