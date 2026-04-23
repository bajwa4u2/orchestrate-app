import '../../../core/network/api_client.dart';

class ClientMeetingsRepository {
  ClientMeetingsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchMeetings() async {
    final json = await _apiClient.getJson(
      '/replies',
      surface: ApiSurface.client,
    );
    final replies = (json as List? ?? const []).cast<dynamic>();

    final meetings = <Map<String, dynamic>>[];
    for (final item in replies) {
      if (item is! Map) continue;
      final reply = Map<String, dynamic>.from(item);
      final meetingRaw = reply['meeting'];
      if (meetingRaw is! Map) continue;
      final meeting = Map<String, dynamic>.from(meetingRaw);
      meetings.add(<String, dynamic>{
        ...meeting,
        if (reply['fromEmail'] != null) 'fromEmail': reply['fromEmail'],
        if (reply['subjectLine'] != null) 'subjectLine': reply['subjectLine'],
        if (reply['receivedAt'] != null) 'receivedAt': reply['receivedAt'],
      });
    }

    return meetings;
  }
}
