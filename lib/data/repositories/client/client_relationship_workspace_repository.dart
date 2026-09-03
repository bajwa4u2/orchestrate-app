import '../../../core/network/api_client.dart';

/// The durable unit, read for the workspace.
///
/// One repository for relationships, their engagements and their timeline —
/// because they are one thing. Splitting them into three would rebuild in the
/// data layer exactly the module separation the workspace exists to remove.
class ClientRelationshipWorkspaceRepository {
  ClientRelationshipWorkspaceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// [view] is a saved view of the same records — never another domain.
  Future<List<RelationshipSummary>> list({String view = 'all'}) async {
    final json = await _apiClient.getJson(
      '/client/relationships?view=$view',
      surface: ApiSurface.client,
    );
    final items = (json is Map ? json['items'] : null);
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => RelationshipSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RelationshipWorkspace> detail(String id) async {
    final json = await _apiClient.getJson(
      '/client/relationships/$id',
      surface: ApiSurface.client,
    );
    return RelationshipWorkspace.fromJson(Map<String, dynamic>.from(json as Map));
  }
}

class RelationshipSummary {
  const RelationshipSummary({
    required this.id,
    required this.counterparty,
    required this.stage,
    required this.closed,
    this.lastEventAt,
    this.engagementCount = 0,
    this.openEngagementRef,
    this.hasHeardBack = false,
  });

  final String id;
  final String counterparty;
  final String stage;
  final bool closed;
  final DateTime? lastEventAt;
  final int engagementCount;
  final String? openEngagementRef;
  final bool hasHeardBack;

  factory RelationshipSummary.fromJson(Map<String, dynamic> j) {
    final open = j['openEngagement'];
    return RelationshipSummary(
      id: j['id']?.toString() ?? '',
      counterparty: j['counterparty']?.toString() ?? 'Unnamed',
      stage: j['stage']?.toString() ?? 'IDENTIFIED',
      closed: j['closed'] == true,
      lastEventAt: DateTime.tryParse(j['lastEventAt']?.toString() ?? ''),
      engagementCount: (j['engagementCount'] as num?)?.toInt() ?? 0,
      openEngagementRef:
          open is Map ? (open['reference']?.toString() ?? 'Engagement') : null,
      hasHeardBack: j['hasHeardBack'] == true,
    );
  }

  /// Words a person uses, not enum names.
  String get stageLabel => switch (stage) {
        'IDENTIFIED' => 'Identified',
        'CONTACTED' => 'Contacted',
        'IN_CONVERSATION' => 'In conversation',
        'ENGAGED' => 'Engaged',
        'CLOSED' => 'Closed',
        _ => stage,
      };
}

class RelationshipWorkspace {
  const RelationshipWorkspace({
    required this.id,
    required this.counterparty,
    required this.closed,
    required this.engagements,
    required this.timeline,
    required this.correspondence,
    this.closedReason,
    this.lastEventAt,
  });

  final String id;
  final String counterparty;
  final bool closed;
  final String? closedReason;
  final DateTime? lastEventAt;
  final List<EngagementSummary> engagements;
  final List<TimelineEvent> timeline;
  final List<Correspondence> correspondence;

  factory RelationshipWorkspace.fromJson(Map<String, dynamic> j) {
    final r = Map<String, dynamic>.from(j['relationship'] as Map? ?? {});
    return RelationshipWorkspace(
      id: r['id']?.toString() ?? '',
      counterparty: r['counterparty']?.toString() ?? 'Unnamed',
      closed: r['closed'] == true,
      closedReason: r['closedReason']?.toString(),
      lastEventAt: DateTime.tryParse(r['lastEventAt']?.toString() ?? ''),
      engagements: (j['engagements'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => EngagementSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      timeline: (j['timeline'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => TimelineEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      correspondence: (j['correspondence'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Correspondence.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  EngagementSummary? get current {
    for (final e in engagements) {
      if (e.state == 'OPEN') return e;
    }
    return engagements.isNotEmpty ? engagements.first : null;
  }
}

class EngagementSummary {
  const EngagementSummary({
    required this.id,
    required this.state,
    this.reference,
    this.openedAt,
    this.completedAt,
  });

  final String id;
  final String state;
  final String? reference;
  final DateTime? openedAt;
  final DateTime? completedAt;

  factory EngagementSummary.fromJson(Map<String, dynamic> j) => EngagementSummary(
        id: j['id']?.toString() ?? '',
        state: j['state']?.toString() ?? 'OPEN',
        reference: j['reference']?.toString(),
        openedAt: DateTime.tryParse(j['openedAt']?.toString() ?? ''),
        completedAt: DateTime.tryParse(j['completedAt']?.toString() ?? ''),
      );

  String get title => reference?.isNotEmpty == true ? reference! : 'Engagement';
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.consequence,
    this.evidenceKind,
    this.engagementId,
  });

  final String id;
  final String type;
  final DateTime occurredAt;
  final String? consequence;
  final String? evidenceKind;
  final String? engagementId;

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? 'event',
        occurredAt:
            DateTime.tryParse(j['occurredAt']?.toString() ?? '') ?? DateTime.now(),
        consequence: j['consequence']?.toString(),
        evidenceKind: j['evidenceKind']?.toString(),
        engagementId: j['engagementId']?.toString(),
      );

  /// Backend event types are snake_case machine names. Say them in English.
  String get label {
    final words = type.replaceAll('_', ' ').replaceAll('.', ' ').trim();
    if (words.isEmpty) return 'Event';
    return words[0].toUpperCase() + words.substring(1);
  }
}

class Correspondence {
  const Correspondence({
    required this.id,
    required this.status,
    required this.deliveryKnown,
    this.subject,
    this.sentAt,
    this.deliveryEvidence,
    this.direction,
  });

  final String id;
  final String status;
  final bool deliveryKnown;
  final String? subject;
  final DateTime? sentAt;
  final String? deliveryEvidence;
  final String? direction;

  factory Correspondence.fromJson(Map<String, dynamic> j) => Correspondence(
        id: j['id']?.toString() ?? '',
        status: j['status']?.toString() ?? 'UNKNOWN',
        deliveryKnown: j['deliveryKnown'] == true,
        subject: j['subjectLine']?.toString(),
        sentAt: DateTime.tryParse(j['sentAt']?.toString() ?? ''),
        deliveryEvidence: j['deliveryEvidence']?.toString(),
        direction: j['direction']?.toString(),
      );

  /// WHAT ACTUALLY HAPPENED TO THIS MESSAGE.
  ///
  /// Three answers, never two. The client used to have `sent` in 68 files and
  /// `delivered` in 4, which meant sent was silently read as delivered. Having
  /// left is not the same as having arrived, and not knowing is its own state
  /// that deserves saying out loud.
  DeliveryTruth get delivery {
    if (status == 'BOUNCED' || deliveryEvidence?.contains('bounce') == true) {
      return DeliveryTruth.bounced;
    }
    if (status == 'FAILED') return DeliveryTruth.failed;
    if (deliveryKnown) return DeliveryTruth.delivered;
    if (status == 'SENT' || sentAt != null) return DeliveryTruth.noEvidenceYet;
    return DeliveryTruth.notSent;
  }
}

enum DeliveryTruth {
  notSent,
  noEvidenceYet,
  delivered,
  bounced,
  failed;

  String get label => switch (this) {
        DeliveryTruth.notSent => 'Not sent',
        DeliveryTruth.noEvidenceYet => 'Sent — no delivery evidence yet',
        DeliveryTruth.delivered => 'Delivered',
        DeliveryTruth.bounced => 'Bounced',
        DeliveryTruth.failed => 'Failed',
      };
}
