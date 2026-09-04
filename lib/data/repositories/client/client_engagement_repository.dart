import '../../../core/network/api_client.dart';

/// UNDERTAKINGS, READ AND ACTED ON THROUGH THE RELATIONSHIP THEY BELONG TO.
///
/// The list is addressed through the relationship and never top-level. That is
/// containment, not routing taste: the moment undertakings get a list of their
/// own, the durable account identity quietly moves from the relationship to the
/// deal and the product becomes the pipeline board it exists not to be.
///
/// Nothing here interprets. Every sentence a person reads about what an
/// undertaking is, why it cannot be opened, or what stopping one means was
/// written by the authority that decided it.
class ClientEngagementRepository {
  ClientEngagementRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Every undertaking inside one relationship, including none.
  Future<RelationshipEngagements> forRelationship(String relationshipId) async {
    final json = await _apiClient.getJson(
      '/client/relationships/$relationshipId/engagements',
      surface: ApiSurface.client,
    );
    return RelationshipEngagements.fromJson(
        Map<String, dynamic>.from(json as Map));
  }

  /// One undertaking, in depth.
  Future<EngagementDetail?> detail(String engagementId) async {
    final json = await _apiClient.getJson(
      '/client/engagements/$engagementId',
      surface: ApiSurface.client,
    );
    final map = Map<String, dynamic>.from(json as Map);
    // The server answers a missing undertaking as a refusal rather than a 404,
    // so the surface can say which one is gone instead of showing an error page.
    if (map['ok'] == false) return null;
    return EngagementDetail.fromJson(map);
  }

  /// Admit that this relationship now contains a bounded undertaking.
  ///
  /// `admissionKey` is sent so a resubmitted form or a retried request is the
  /// same undertaking rather than a second one with the same purpose.
  Future<EngagementCommandResult> open({
    required String relationshipId,
    required String purpose,
    String? originNote,
    String? admissionKey,
  }) async {
    final json = await _apiClient.postJson(
      '/client/relationships/$relationshipId/engagements',
      body: {
        'purpose': purpose,
        if (originNote != null && originNote.trim().isNotEmpty)
          'originNote': originNote.trim(),
        if (admissionKey != null) 'admissionKey': admissionKey,
      },
      surface: ApiSurface.client,
    );
    return EngagementCommandResult.fromJson(
        Map<String, dynamic>.from(json as Map));
  }

  Future<EngagementCommandResult> complete(String engagementId) async {
    final json = await _apiClient.postJson(
      '/client/engagements/$engagementId/complete',
      body: const {},
      surface: ApiSurface.client,
    );
    return EngagementCommandResult.fromJson(
        Map<String, dynamic>.from(json as Map));
  }

  /// Stopped without concluding. The reason is required by the server, and
  /// this does not pretend otherwise by defaulting it.
  Future<EngagementCommandResult> abandon({
    required String engagementId,
    required String reason,
  }) async {
    final json = await _apiClient.postJson(
      '/client/engagements/$engagementId/abandon',
      body: {'reason': reason},
      surface: ApiSurface.client,
    );
    return EngagementCommandResult.fromJson(
        Map<String, dynamic>.from(json as Map));
  }
}

/// The whole lifecycle. Three states, and no fourth is coming.
enum EngagementState {
  open('OPEN'),
  completed('COMPLETED'),
  abandoned('ABANDONED');

  const EngagementState(this.wire);
  final String wire;

  static EngagementState parse(String? value) => switch (value) {
        'COMPLETED' => EngagementState.completed,
        'ABANDONED' => EngagementState.abandoned,
        _ => EngagementState.open,
      };

  bool get isTerminal => this != EngagementState.open;
}

class EngagementView {
  const EngagementView({
    required this.id,
    required this.purpose,
    required this.state,
    required this.stateMeans,
    required this.originMeans,
    required this.openedAt,
    required this.completedAt,
    required this.abandonedAt,
    required this.blocker,
    required this.needsAHuman,
  });

  final String id;
  final String purpose;
  final EngagementState state;

  /// The server's sentence for the state. Deliberately carried rather than
  /// mapped here — "completed" is not "won", and a client that writes its own
  /// wording is a client that will eventually say it is.
  final String stateMeans;
  final String originMeans;
  final DateTime? openedAt;
  final DateTime? completedAt;
  final DateTime? abandonedAt;

  /// Contact truth stopping work on this undertaking. A blocker, never a
  /// lifecycle change: a bounced address does not abandon a piece of work
  /// the business still intends.
  final String? blocker;
  final bool needsAHuman;

  static EngagementView fromJson(Map<String, dynamic> j) => EngagementView(
        id: (j['id'] ?? '').toString(),
        purpose: (j['purpose'] ?? '').toString(),
        state: EngagementState.parse(j['state'] as String?),
        stateMeans: (j['stateMeans'] ?? '').toString(),
        originMeans: (j['originMeans'] ?? '').toString(),
        openedAt: _time(j['openedAt']),
        completedAt: _time(j['completedAt']),
        abandonedAt: _time(j['abandonedAt']),
        blocker: _text(j['blocker']),
        needsAHuman: j['needsAHuman'] == true,
      );
}

class RelationshipEngagements {
  const RelationshipEngagements({
    required this.relationshipId,
    required this.counterparty,
    required this.says,
    required this.engagements,
  });

  final String relationshipId;
  final String? counterparty;

  /// The zero state as a sentence, from the server. A relationship holding no
  /// undertaking is a legitimate state rather than an empty list to fill.
  final String says;
  final List<EngagementView> engagements;

  List<EngagementView> get open =>
      engagements.where((e) => e.state == EngagementState.open).toList();
  List<EngagementView> get concluded =>
      engagements.where((e) => e.state.isTerminal).toList();

  static RelationshipEngagements fromJson(Map<String, dynamic> j) =>
      RelationshipEngagements(
        relationshipId: (j['relationshipId'] ?? '').toString(),
        counterparty: _text(j['counterparty']),
        says: (j['says'] ?? '').toString(),
        engagements: [
          for (final raw in (j['engagements'] as List? ?? const []))
            EngagementView.fromJson(Map<String, dynamic>.from(raw as Map)),
        ],
      );
}

class EngagementDetail {
  const EngagementDetail({
    required this.view,
    required this.relationshipId,
    required this.counterparty,
    required this.admittedBy,
    required this.originNote,
    required this.abandonedReason,
    required this.downstream,
  });

  final EngagementView view;
  final String relationshipId;
  final String counterparty;

  /// Who had the standing to say this undertaking exists. Never createdAt
  /// standing in for provenance.
  final String? admittedBy;
  final String? originNote;
  final String? abandonedReason;
  final EngagementDownstream downstream;

  static EngagementDetail fromJson(Map<String, dynamic> j) => EngagementDetail(
        view: EngagementView.fromJson(j),
        relationshipId: (j['relationshipId'] ?? '').toString(),
        counterparty: (j['counterparty'] ?? '').toString(),
        admittedBy: _text(j['admittedBy']),
        originNote: _text(j['originNote']),
        abandonedReason: _text(j['abandonedReason']),
        downstream: EngagementDownstream.fromJson(
            Map<String, dynamic>.from(j['downstream'] as Map? ?? const {})),
      );
}

/// What hangs off an undertaking when it exists.
///
/// Zero everywhere in production, and shown as an honest absence rather than
/// hidden. Chapter E establishes the containment; the lifecycles of these
/// belong to a later chapter and are not invented here.
class EngagementDownstream {
  const EngagementDownstream({
    required this.agreements,
    required this.obligations,
    required this.invoices,
    required this.says,
  });

  final int agreements;
  final int obligations;
  final int invoices;
  final String says;

  bool get anyExist => agreements > 0 || obligations > 0 || invoices > 0;

  static EngagementDownstream fromJson(Map<String, dynamic> j) =>
      EngagementDownstream(
        agreements: (j['agreements'] as num?)?.toInt() ?? 0,
        obligations: (j['obligations'] as num?)?.toInt() ?? 0,
        invoices: (j['invoices'] as num?)?.toInt() ?? 0,
        says: (j['says'] ?? '').toString(),
      );
}

/// What the server answered to a command.
///
/// `created` matters and is not cosmetic: a retried admission returns the
/// undertaking that already existed, and telling somebody "opened" when
/// nothing was opened would teach them the button does not work.
class EngagementCommandResult {
  const EngagementCommandResult({
    required this.ok,
    required this.code,
    required this.reason,
    required this.created,
    required this.note,
    required this.engagementId,
  });

  final bool ok;
  final String? code;

  /// The server's own sentence, rendered verbatim. It was written for the
  /// person who hit it and is the whole value of the response.
  final String? reason;
  final bool created;
  final String? note;
  final String? engagementId;

  static EngagementCommandResult fromJson(Map<String, dynamic> j) {
    final engagement = j['engagement'];
    return EngagementCommandResult(
      ok: j['ok'] != false,
      code: _text(j['code']),
      reason: _text(j['reason'] ?? j['why']),
      created: j['created'] == true,
      note: _text(j['note']),
      engagementId: engagement is Map
          ? _text(engagement['id'])
          : _text(j['engagementId']),
    );
  }
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _time(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
