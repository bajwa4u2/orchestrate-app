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
    final json = await _operatorRepository.fetchCommandOverview();
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
    final items = await _operatorRepository.fetchReplies();
    return _mapItems(items, ResourceKind.reply);
  }

  Future<List<ResourceItem>> fetchMeetings() async {
    final items = await _operatorRepository.fetchMeetings();
    return _mapItems(items, ResourceKind.meeting);
  }

  Future<HealthSnapshot> fetchHealth() async {
    final overview = await _operatorRepository.fetchCommandOverview();
    final today = _asMap(overview['today']);
    final execution = _asMap(overview['execution']);
    final alerts = _asMap(overview['alerts']);

    return HealthSnapshot.fromJson({
      'status': _read(overview, 'systemPosture', fallback: 'Live'),
      'message': _read(overview, 'systemPhase', fallback: 'Operator workspace live'),
      'lastCheckAt': DateTime.now().toIso8601String(),
      'checks': [
        {
          'key': 'sent_today',
          'label': 'Sent today',
          'status': 'ok',
          'value': _read(today, 'sent', fallback: '0'),
        },
        {
          'key': 'failed_jobs',
          'label': 'Failed jobs',
          'status': _read(execution, 'failedJobs', fallback: '0') == '0' ? 'ok' : 'warn',
          'value': _read(execution, 'failedJobs', fallback: '0'),
        },
        {
          'key': 'open_alerts',
          'label': 'Open alerts',
          'status': _read(alerts, 'critical', fallback: '0') == '0' ? 'ok' : 'warn',
          'value': _read(alerts, 'open', fallback: '0'),
        },
      ],
    });
  }

  Future<DeliverabilityOverview> fetchDeliverabilityOverview() async {
    final json = await _operatorRepository.fetchDeliverabilityOverview();
    return DeliverabilityOverview.fromJson(json);
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
