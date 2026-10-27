import '../../../core/network/api_client.dart';

/// A follow-up Orchestrate is holding for the owner's yes (26 Oct 2026).
///
/// Its own words do not exist yet: Orchestrate writes a follow-up when it goes,
/// from the conversation as it stands then. What the owner reads is the first
/// note they already sent and, in the server's words, why it is waiting.
class HeldFollowUp {
  const HeldFollowUp({
    required this.id,
    required this.company,
    this.contactName,
    this.firstSubject,
    this.firstBody,
    this.firstSentAt,
    required this.reasonText,
    this.waitsUntil,
  });

  factory HeldFollowUp.fromJson(Map<String, dynamic> json) {
    final first = json['firstNote'] is Map ? Map<String, dynamic>.from(json['firstNote'] as Map) : null;
    return HeldFollowUp(
      id: json['id'].toString(),
      company: (json['company'] ?? '').toString(),
      contactName: json['contactName']?.toString(),
      firstSubject: first?['subject']?.toString(),
      firstBody: first?['body']?.toString(),
      firstSentAt: DateTime.tryParse(first?['sentAt']?.toString() ?? '')?.toLocal(),
      reasonText: (json['reasonText'] ?? '').toString(),
      waitsUntil: DateTime.tryParse(json['waitsUntil']?.toString() ?? '')?.toLocal(),
    );
  }

  final String id;
  final String company;
  final String? contactName;
  final String? firstSubject;
  final String? firstBody;
  final DateTime? firstSentAt;
  final String reasonText;
  final DateTime? waitsUntil;
}

/// Types the server's answers and nothing else; every rule and sentence about
/// who may say yes is decided on the server.
class ClientHeldFollowUpsRepository {
  ClientHeldFollowUpsRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<HeldFollowUp>> list() async {
    final json = await _apiClient.getJson('/client/held-follow-ups', surface: ApiSurface.client);
    final items = (json is Map ? json['items'] : null) as List? ?? const [];
    return [for (final raw in items) HeldFollowUp.fromJson(Map<String, dynamic>.from(raw as Map))];
  }

  /// Yes: Orchestrate writes the follow-up now, after one more look.
  Future<Map<String, dynamic>> send(String id) async {
    final json = await _apiClient.postJson('/client/held-follow-ups/$id/send', surface: ApiSurface.client, body: const {});
    return Map<String, dynamic>.from(json as Map);
  }

  /// No: this follow-up is not sent.
  Future<Map<String, dynamic>> dontSend(String id) async {
    final json = await _apiClient.postJson('/client/held-follow-ups/$id/dont-send', surface: ApiSurface.client, body: const {});
    return Map<String, dynamic>.from(json as Map);
  }
}
