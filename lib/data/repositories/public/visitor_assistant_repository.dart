import '../../../core/network/api_client.dart';

/// THE VISITOR ASSISTANT (founder, 2 Oct 2026).
///
/// Answers someone on the public site from the same product truth signed-in
/// Support uses, the kind of business they say they are, and today's
/// published prices. No session: nothing here reads an account.
class VisitorAssistantRepository {
  VisitorAssistantRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<String>> starters() async {
    final j = _map(await _api.getJson('/public/assistant/starters'));
    return [for (final q in _list(j['questions'])) '$q'];
  }

  Future<VisitorAnswer> ask(String message, List<VisitorTurn> history, {String? page}) async {
    final j = await _api.postJson('/public/assistant/ask', body: {
      'message': message,
      'history': [for (final t in history) t.toJson()],
      if (page != null) 'page': page,
    });
    return VisitorAnswer.fromJson(_map(j));
  }

  /// Returns what happens next, in words.
  Future<String> handoff({
    required String name,
    required String email,
    String? company,
    required String message,
    required List<VisitorTurn> conversation,
    required List<String> answerIds,
    String? page,
  }) async {
    final j = _map(await _api.postJson('/public/assistant/handoff', body: {
      'name': name,
      'email': email,
      if (company != null && company.isNotEmpty) 'company': company,
      'message': message,
      'conversation': [for (final t in conversation) t.toJson()],
      'answerIds': answerIds,
      if (page != null) 'page': page,
    }));
    return '${j['says'] ?? 'Thank you. A person will reply to your email within one business day.'}';
  }
}

class VisitorPlace {
  const VisitorPlace({required this.key, required this.label, required this.route});
  final String key;
  final String label;
  final String route;

  static VisitorPlace fromJson(Map<String, dynamic> j) =>
      VisitorPlace(key: '${j['key'] ?? ''}', label: '${j['label'] ?? ''}', route: '${j['route'] ?? '/'}');
}

class VisitorAnswer {
  const VisitorAnswer({
    required this.id,
    required this.answer,
    required this.places,
    required this.question,
    required this.offerPerson,
  });

  final String id;
  final String answer;
  final List<VisitorPlace> places;
  final String? question;
  final bool offerPerson;

  static VisitorAnswer fromJson(Map<String, dynamic> j) => VisitorAnswer(
        id: '${j['id'] ?? ''}',
        answer: '${j['answer'] ?? ''}',
        places: [for (final p in _list(j['places'])) VisitorPlace.fromJson(_map(p))],
        question: (j['question'] as String?)?.trim().isEmpty ?? true ? null : j['question'] as String,
        offerPerson: j['offerPerson'] == true,
      );
}

class VisitorTurn {
  const VisitorTurn.you(this.text)
      : fromYou = true,
        answer = null;
  VisitorTurn.support(VisitorAnswer this.answer)
      : fromYou = false,
        text = answer.answer;

  final bool fromYou;
  final String text;
  final VisitorAnswer? answer;

  Map<String, dynamic> toJson() => {'from': fromYou ? 'you' : 'support', 'text': text};
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : const [];
