import '../../../core/network/api_client.dart';

/// SUPPORT THAT KNOWS THIS BUSINESS (DD-35).
///
/// What is in the business's way, an answer on the spot built from product
/// knowledge and the business's own standing, a person when that cannot
/// settle it, and the requests a person is handling.
class ClientSupportRepository {
  ClientSupportRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<SupportStanding> standing() async =>
      SupportStanding.fromJson(_map(await _api.getJson('/client/support/standing', surface: ApiSurface.client)));

  Future<List<SupportTopic>> topics() async {
    final j = _map(await _api.getJson('/client/support/topics', surface: ApiSurface.client));
    return _list(j['topics']).map(_map).map(SupportTopic.fromJson).toList();
  }

  Future<SupportAnswer> ask(String message, List<SupportTurn> history) async {
    final j = await _api.postJson('/client/support/ask',
        surface: ApiSurface.client,
        body: {'message': message, 'history': [for (final t in history) t.toJson()]});
    return SupportAnswer.fromJson(_map(j));
  }

  /// Returns what happens next, in words.
  Future<String> handoff(String message, List<SupportTurn> conversation, List<String> answerIds) async {
    final j = _map(await _api.postJson('/client/support/handoff',
        surface: ApiSurface.client,
        body: {
          'message': message,
          'conversation': [for (final t in conversation) t.toJson()],
          'answerIds': answerIds,
        }));
    return '${j['says'] ?? 'Sent to a person. You will get a reply by email.'}';
  }

  Future<List<SupportCase>> cases() async {
    final j = _map(await _api.getJson('/client/support/inquiries', surface: ApiSurface.client));
    return _list(j['items']).map(_map).map(SupportCase.fromJson).toList();
  }

  Future<List<SupportMessage>> thread(String id) async {
    final j = _map(await _api.getJson('/client/support/inquiries/$id/thread', surface: ApiSurface.client));
    final inquiry = _map(j['inquiry']).isNotEmpty ? _map(j['inquiry']) : j;
    return _list(inquiry['messages'] ?? j['messages']).map(_map).map(SupportMessage.fromJson).toList();
  }

  Future<String> replyToCase(String id, String message) async {
    final j = _map(await _api.postJson('/client/support/cases/$id/reply',
        surface: ApiSurface.client, body: {'message': message}));
    return '${j['says'] ?? 'Sent.'}';
  }
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : const [];
String? _text(dynamic v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

class SupportPlace {
  const SupportPlace(this.key, this.label, this.route);
  final String key;
  final String label;
  final String route;

  static SupportPlace? fromJson(dynamic raw) {
    final j = _map(raw);
    final route = _text(j['route']);
    if (route == null) return null;
    return SupportPlace('${j['key'] ?? ''}', '${j['label'] ?? 'Open'}', route);
  }
}

class StandingItem {
  const StandingItem({
    required this.title,
    required this.detail,
    required this.yours,
    required this.state,
    required this.place,
  });

  final String title;
  final String detail;

  /// The owner's move, rather than Orchestrate's.
  final bool yours;

  /// blocking | waiting | info
  final String state;
  final SupportPlace? place;

  static StandingItem fromJson(Map<String, dynamic> j) => StandingItem(
        title: '${j['title'] ?? ''}',
        detail: '${j['detail'] ?? ''}',
        yours: j['whose'] == 'you',
        state: '${j['state'] ?? 'info'}',
        place: SupportPlace.fromJson(j['place']),
      );
}

class SupportStanding {
  const SupportStanding({required this.items, required this.checkedAt});
  final List<StandingItem> items;
  final DateTime? checkedAt;

  static SupportStanding fromJson(Map<String, dynamic> j) => SupportStanding(
        items: _list(j['items']).map(_map).map(StandingItem.fromJson).toList(),
        checkedAt: DateTime.tryParse('${j['checkedAt'] ?? ''}')?.toLocal(),
      );
}

class SupportQuestion {
  const SupportQuestion(this.question, this.answer, this.places);
  final String question;
  final String answer;
  final List<SupportPlace> places;
}

class SupportTopic {
  const SupportTopic(this.label, this.questions);
  final String label;
  final List<SupportQuestion> questions;

  static SupportTopic fromJson(Map<String, dynamic> j) => SupportTopic(
        '${j['label'] ?? ''}',
        [
          for (final q in _list(j['questions']).map(_map))
            SupportQuestion('${q['question'] ?? ''}', '${q['answer'] ?? ''}',
                _list(q['places']).map(SupportPlace.fromJson).whereType<SupportPlace>().toList()),
        ],
      );
}

class SupportTurn {
  const SupportTurn(this.fromYou, this.text, {this.answer});
  final bool fromYou;
  final String text;

  /// The answer behind a Support turn, with its places and offer of a person.
  final SupportAnswer? answer;

  Map<String, dynamic> toJson() => {'from': fromYou ? 'you' : 'support', 'text': text};
}

class SupportAnswer {
  const SupportAnswer({
    required this.id,
    required this.answer,
    required this.places,
    required this.question,
    required this.offerPerson,
  });

  final String id;
  final String answer;
  final List<SupportPlace> places;
  final String? question;
  final bool offerPerson;

  static SupportAnswer fromJson(Map<String, dynamic> j) => SupportAnswer(
        id: '${j['id'] ?? ''}',
        answer: '${j['answer'] ?? ''}',
        places: _list(j['places']).map(SupportPlace.fromJson).whereType<SupportPlace>().toList(),
        question: _text(j['question']),
        offerPerson: j['offerPerson'] == true,
      );
}

class SupportCase {
  const SupportCase({
    required this.id,
    required this.subject,
    required this.status,
    required this.withPerson,
    required this.at,
  });

  final String id;
  final String subject;
  final String status;
  final bool withPerson;
  final DateTime? at;

  bool get closed => status == 'CLOSED';

  /// Where it stands, in words.
  String get standing => closed
      ? 'Closed'
      : withPerson
          ? 'With a person'
          : status == 'NEW'
              ? 'Waiting for a person'
              : 'Answered';

  static SupportCase fromJson(Map<String, dynamic> j) => SupportCase(
        id: '${j['id'] ?? ''}',
        subject: '${j['subject'] ?? j['message'] ?? ''}',
        status: '${j['status'] ?? ''}'.toUpperCase(),
        withPerson: j['isEscalated'] == true || j['requiresHuman'] == true,
        at: DateTime.tryParse('${j['lastActivityAt'] ?? j['submittedAt'] ?? j['createdAt'] ?? ''}')?.toLocal(),
      );
}

class SupportMessage {
  const SupportMessage(this.who, this.text, this.at, this.fromYou);
  final String who;
  final String text;
  final DateTime? at;
  final bool fromYou;

  static SupportMessage fromJson(Map<String, dynamic> j) {
    final author = '${j['authorType'] ?? ''}'.toUpperCase();
    final who = switch (author) {
      'USER' => 'You',
      'OPERATOR' => 'Orchestrate support',
      'AI' => 'Support',
      _ => 'Orchestrate',
    };
    return SupportMessage(
      who,
      '${j['bodyText'] ?? j['content'] ?? ''}',
      DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
      author == 'USER',
    );
  }
}
