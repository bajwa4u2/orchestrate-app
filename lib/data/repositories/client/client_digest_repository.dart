import '../../../core/network/api_client.dart';

/// What happened since yesterday morning, composed by the server: the same
/// lines the 8 AM email carries.
class ClientDigestRepository {
  ClientDigestRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<DigestView> fetch() async {
    final json = await _apiClient.getJson('/client/digest', surface: ApiSurface.client);
    return DigestView.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<bool> setMorningEmail(bool on) async {
    final json = await _apiClient.postJson(
      '/client/digest/morning-email',
      surface: ApiSurface.client,
      body: {'on': on},
    );
    return (json is Map ? json['morningEmail'] : null) == true;
  }
}

class DigestLine {
  const DigestLine({
    required this.kind,
    required this.headline,
    required this.detail,
    required this.items,
    required this.route,
    required this.action,
  });

  /// WAITING, PASSED, REPLIES, MEETINGS or RECEIVED.
  final String kind;
  final String headline;
  final String? detail;
  final List<String> items;
  final String route;
  final String action;

  static DigestLine fromJson(Map<String, dynamic> j) => DigestLine(
        kind: (j['kind'] as String?) ?? '',
        headline: (j['headline'] as String?) ?? '',
        detail: (j['detail'] as String?)?.trim().isEmpty ?? true ? null : j['detail'] as String,
        items: ((j['items'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
        route: (j['route'] as String?) ?? '/client/today',
        action: (j['action'] as String?) ?? 'Open',
      );
}

class DigestView {
  const DigestView({
    required this.hasNews,
    required this.lines,
    required this.quietLine,
    required this.morningEmail,
    this.motion,
  });

  /// Notes moving without the owner (4 Oct 2026).
  final DigestMotion? motion;

  final bool hasNews;
  final List<DigestLine> lines;
  final String? quietLine;
  final bool morningEmail;

  static DigestView fromJson(Map<String, dynamic> j) => DigestView(
        hasNews: j['hasNews'] == true,
        lines: ((j['lines'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => DigestLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        quietLine: j['quietLine'] as String?,
        morningEmail: j['morningEmail'] != false,
        motion: j['motion'] is Map ? DigestMotion.fromJson(Map<String, dynamic>.from(j['motion'] as Map)) : null,
      );
}

/// What is moving without the owner: notes sent lately, and what goes next.
class DigestMotion {
  const DigestMotion({
    required this.sentRecently,
    required this.sentTo,
    required this.firstNotesWaiting,
    this.firstNotesNextAt,
    required this.followUpsWaiting,
    this.followUpsNextAt,
  });

  final int sentRecently;
  final List<String> sentTo;
  final int firstNotesWaiting;
  final DateTime? firstNotesNextAt;
  final int followUpsWaiting;
  final DateTime? followUpsNextAt;

  static DigestMotion fromJson(Map<String, dynamic> j) => DigestMotion(
        sentRecently: (j['sentRecently'] as num?)?.toInt() ?? 0,
        sentTo: ((j['sentTo'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
        firstNotesWaiting: (j['firstNotesWaiting'] as num?)?.toInt() ?? 0,
        firstNotesNextAt: DateTime.tryParse(j['firstNotesNextAt']?.toString() ?? '')?.toLocal(),
        followUpsWaiting: (j['followUpsWaiting'] as num?)?.toInt() ?? 0,
        followUpsNextAt: DateTime.tryParse(j['followUpsNextAt']?.toString() ?? '')?.toLocal(),
      );
}
