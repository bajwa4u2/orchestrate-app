import '../../../core/network/api_client.dart';
import 'client_mailbox_repository.dart';

class ClientMeetingsRepository {
  ClientMeetingsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _mailboxRepository = ClientMailboxRepository(apiClient: apiClient);

  final ApiClient _apiClient;
  final ClientMailboxRepository _mailboxRepository;

  Future<List<dynamic>> fetchMeetings() async {
    final replies = await _mailboxRepository.fetchRepliesSafe(limit: 100);
    final meetings = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final reply in replies) {
      final replyMap = _asMap(reply);
      final meeting = _asMap(replyMap['meeting']);
      if (meeting.isEmpty) continue;

      final id = _string(meeting['id']);
      if (id.isNotEmpty && seen.contains(id)) continue;
      if (id.isNotEmpty) seen.add(id);

      meetings.add(<String, dynamic>{
        ...meeting,
        if (!_asMap(meeting['lead']).isNotEmpty && _asMap(replyMap['lead']).isNotEmpty)
          'lead': _asMap(replyMap['lead']),
        if (!_asMap(meeting['campaign']).isNotEmpty && _asMap(replyMap['campaign']).isNotEmpty)
          'campaign': _asMap(replyMap['campaign']),
      });
    }

    meetings.sort((a, b) {
      final aTime = DateTime.tryParse(_string(a['scheduledAt'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(_string(b['scheduledAt'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return meetings;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }

  String _string(dynamic value) => value == null ? '' : value.toString().trim();
}
