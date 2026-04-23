import '../../../core/network/api_client.dart';

class ClientMeetingsRepository {
  ClientMeetingsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchMeetings() async {
    final overview = await _apiClient.getJson(
      '/client/overview',
      surface: ApiSurface.client,
    );

    final map = Map<String, dynamic>.from(overview as Map);
    final activity = _asMap(map['activity']);
    final execution = _asMap(map['execution']);

    return <Map<String, dynamic>>[
      {
        'title': 'Meeting handoff',
        'count': activity['meetings'] ?? activity['meetingCount'] ?? 0,
        'summary': _read(execution, 'summary', fallback: 'Meeting activity will appear here as replies progress.'),
        'state': _read(execution, 'surfaceLabel', fallback: _read(execution, 'stateLabel', fallback: 'Pending')),
      },
    ];
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

String _read(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = '$value'.trim();
  return text.isEmpty ? fallback : text;
}
