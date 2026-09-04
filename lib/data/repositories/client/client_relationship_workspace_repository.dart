import '../../../core/network/api_client.dart';

/// THE DURABLE BUSINESS RELATIONSHIP.
///
/// The relationship — not the transaction, campaign, message or invoice — is
/// the unit of account. It is durable commercial context between identifiable
/// parties; it may hold zero, one or many undertakings, and it does not end
/// because one of them completes.
///
/// Every judgement here comes from the server. This once carried its own
/// `stage` vocabulary (IDENTIFIED / CONTACTED / IN_CONVERSATION / ENGAGED)
/// computed alongside the backend's condition, so the same relationship could
/// read one word in the list and another in the detail. There is one answer now
/// and this types it.
class ClientRelationshipWorkspaceRepository {
  ClientRelationshipWorkspaceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<RelationshipList> fetchList({String? view}) async {
    final json = await _apiClient.getJson(
      '/client/relationships',
      surface: ApiSurface.client,
      query: {if (view != null && view.isNotEmpty) 'view': view},
    );
    return RelationshipList.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<RelationshipDepth> fetchDepth(String id) async {
    final json = await _apiClient.getJson(
      '/client/relationships/$id',
      surface: ApiSurface.client,
    );
    return RelationshipDepth.fromJson(Map<String, dynamic>.from(json as Map));
  }
}

/// Where a relationship actually stands. Derived from admitted truth, never a
/// stage anybody edits.
enum RelationshipCondition {
  inEngagement('IN_ENGAGEMENT', 'In an undertaking'),
  inDispute('IN_DISPUTE', 'Disputed'),
  active('ACTIVE', 'Active'),
  dormant('DORMANT', 'Quiet'),
  closed('CLOSED', 'Closed');

  const RelationshipCondition(this.wire, this.label);
  final String wire;
  final String label;

  static RelationshipCondition parse(String? value) {
    for (final c in RelationshipCondition.values) {
      if (c.wire == value) return c;
    }
    return RelationshipCondition.dormant;
  }

  /// Whether this condition should draw the eye. Problems and decisions earn
  /// prime space; a healthy relationship stays quiet.
  bool get wantsAttention => this == RelationshipCondition.inDispute;
}

/// WHETHER A MESSAGE CAN PRESENTLY REACH THEM.
///
/// A separate axis from condition, and never a substitute for it. A
/// relationship can be active with reachability failed — the first describes
/// durable commercial continuity, the second describes a channel.
///
/// This distinction has to be legible on screen. Collapsing them is how a
/// business either believes it has a live relationship with an address that
/// does not work, or believes a real relationship is over because one message
/// bounced.
enum Reachability {
  confirmed('CONFIRMED', 'Reaching them'),
  failed('FAILED', 'No confirmed reachability'),
  unknown('UNKNOWN', 'No confirmed reachability'),
  notAttempted('NOT_ATTEMPTED', 'Nothing sent');

  const Reachability(this.wire, this.label);
  final String wire;
  final String label;

  static Reachability parse(String? value) {
    for (final r in Reachability.values) {
      if (r.wire == value) return r;
    }
    return Reachability.notAttempted;
  }

  /// A failed channel is worth a person's attention. An unknown one is worth
  /// saying plainly and not worth alarming anyone about.
  bool get wantsAttention => this == Reachability.failed;
}

class RelationshipSummary {
  const RelationshipSummary({
    required this.id,
    required this.counterparty,
    required this.counterpartyKey,
    required this.condition,
    required this.conditionMeans,
    required this.conditionBecause,
    required this.reachability,
    required this.reachabilityBecause,
    required this.lastEventAt,
    required this.openEngagementId,
    required this.engagementCount,
    required this.attention,
  });

  final String id;
  final String counterparty;
  final String counterpartyKey;
  final RelationshipCondition condition;
  final String conditionMeans;

  /// What was true that made this the answer. Never a bare label.
  final String conditionBecause;

  /// Whether a message can presently reach them. A separate question.
  final Reachability reachability;
  final String reachabilityBecause;
  final DateTime? lastEventAt;
  final String? openEngagementId;
  final int engagementCount;
  final int attention;

  static RelationshipSummary fromJson(Map<String, dynamic> j) => RelationshipSummary(
        id: (j['id'] as String?) ?? '',
        counterparty: (j['counterparty'] as String?)?.trim().isEmpty ?? true
            ? '(unnamed)'
            : (j['counterparty'] as String).trim(),
        counterpartyKey: (j['counterpartyKey'] as String?) ?? '',
        condition: RelationshipCondition.parse(j['condition'] as String?),
        conditionMeans: (j['conditionMeans'] as String?) ?? '',
        conditionBecause: (j['conditionBecause'] as String?) ?? '',
        reachability: Reachability.parse(j['reachability'] as String?),
        reachabilityBecause: (j['reachabilityBecause'] as String?) ?? '',
        lastEventAt: DateTime.tryParse(j['lastEventAt']?.toString() ?? ''),
        openEngagementId: _text(j['openEngagementId']),
        engagementCount: (j['engagementCount'] as num?)?.toInt() ?? 0,
        attention: (j['attention'] as num?)?.toInt() ?? 0,
      );
}

class RelationshipList {
  const RelationshipList({
    required this.relationships,
    required this.counts,
    required this.note,
  });

  final List<RelationshipSummary> relationships;
  final Map<RelationshipCondition, int> counts;
  final String note;

  static RelationshipList fromJson(Map<String, dynamic> j) {
    final raw = Map<String, dynamic>.from(j['counts'] as Map? ?? {});
    return RelationshipList(
      relationships: ((j['relationships'] as List?) ?? const [])
          .whereType<Map>()
          .map((r) => RelationshipSummary.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false),
      counts: {
        for (final c in RelationshipCondition.values)
          c: (raw[c.wire] as num?)?.toInt() ?? 0,
      },
      note: (j['note'] as String?) ?? '',
    );
  }
}

/// Why this relationship exists at all.
class RelationshipOrigin {
  const RelationshipOrigin({
    required this.says,
    required this.at,
    required this.provenanceIsWeak,
  });

  final String says;
  final DateTime? at;

  /// True when the record was created after the fact it describes — every
  /// production row is in this state, one by more than two months.
  final bool provenanceIsWeak;

  static RelationshipOrigin fromJson(Map<String, dynamic>? j) => RelationshipOrigin(
        says: (j?['says'] as String?) ?? '',
        at: DateTime.tryParse(j?['at']?.toString() ?? ''),
        provenanceIsWeak: j?['provenanceIsWeak'] == true,
      );
}

/// One commercial undertaking, contained inside the relationship.
class EngagementSummary {
  const EngagementSummary({
    required this.id,
    required this.reference,
    required this.state,
    required this.openedAt,
    required this.completedAt,
    required this.abandonedAt,
  });

  final String id;
  final String? reference;
  final String state;
  final DateTime? openedAt;
  final DateTime? completedAt;
  final DateTime? abandonedAt;

  bool get isOpen => state == 'OPEN';

  String get label => switch (state) {
        'OPEN' => 'Open',
        'COMPLETED' => 'Completed',
        'ABANDONED' => 'Abandoned',
        _ => state,
      };

  static EngagementSummary fromJson(Map<String, dynamic> j) => EngagementSummary(
        id: (j['id'] as String?) ?? '',
        reference: _text(j['reference']),
        state: (j['state'] as String?) ?? 'OPEN',
        openedAt: DateTime.tryParse(j['openedAt']?.toString() ?? ''),
        completedAt: DateTime.tryParse(j['completedAt']?.toString() ?? ''),
        abandonedAt: DateTime.tryParse(j['abandonedAt']?.toString() ?? ''),
      );
}

/// One thing that happened, in commercial terms.
class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.says,
    required this.at,
    required this.until,
    required this.occurrences,
    required this.consequence,
    required this.isCurrent,
    required this.engagementId,
  });

  final String kind;

  /// Written by the server, verbatim.
  final String says;
  final DateTime at;

  /// Set when a run of the same outcome was told as one.
  final DateTime? until;
  final int occurrences;
  final String consequence;

  /// False when a later fact replaced this one. History, not the answer.
  final bool isCurrent;
  final String? engagementId;

  static TimelineEntry fromJson(Map<String, dynamic> j) => TimelineEntry(
        kind: (j['kind'] as String?) ?? 'OTHER',
        says: (j['says'] as String?) ?? '',
        at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime(1970),
        until: DateTime.tryParse(j['until']?.toString() ?? ''),
        occurrences: (j['occurrences'] as num?)?.toInt() ?? 1,
        consequence: (j['consequence'] as String?) ?? '',
        isCurrent: j['isCurrent'] != false,
        engagementId: _text(j['engagementId']),
      );
}

/// Inbound the relationship is holding, referenced from Chapter B's Attention.
class RelationshipAttention {
  const RelationshipAttention({
    required this.id,
    required this.subject,
    required this.from,
    required this.receivedAt,
  });

  final String id;
  final String subject;
  final String? from;
  final DateTime? receivedAt;

  static RelationshipAttention fromJson(Map<String, dynamic> j) => RelationshipAttention(
        id: (j['id'] as String?) ?? '',
        subject: (j['subject'] as String?) ?? '(no subject)',
        from: _text(j['from']),
        receivedAt: DateTime.tryParse(j['receivedAt']?.toString() ?? ''),
      );
}

class RelationshipDepth {
  const RelationshipDepth({
    required this.id,
    required this.counterparty,
    required this.counterpartyKey,
    required this.condition,
    required this.conditionMeans,
    required this.conditionBecause,
    required this.reachability,
    required this.reachabilityMeans,
    required this.reachabilityBecause,
    required this.origin,
    required this.engagements,
    required this.currentEngagementId,
    required this.attention,
    required this.timeline,
    required this.eventCount,
    required this.refusalReason,
  });

  final String id;
  final String counterparty;
  final String counterpartyKey;
  final RelationshipCondition condition;
  final String conditionMeans;
  final String conditionBecause;

  /// The channel, not the relationship. Shown beside the condition and never
  /// folded into it.
  final Reachability reachability;
  final String reachabilityMeans;
  final String reachabilityBecause;
  final RelationshipOrigin origin;
  final List<EngagementSummary> engagements;
  final String? currentEngagementId;
  final List<RelationshipAttention> attention;
  final List<TimelineEntry> timeline;
  final int eventCount;
  final String? refusalReason;

  EngagementSummary? get currentEngagement {
    for (final e in engagements) {
      if (e.id == currentEngagementId) return e;
    }
    return null;
  }

  List<EngagementSummary> get pastEngagements =>
      engagements.where((e) => e.id != currentEngagementId).toList(growable: false);

  static RelationshipDepth fromJson(Map<String, dynamic> j) {
    if (j['ok'] == false) {
      return RelationshipDepth(
        id: '', counterparty: '', counterpartyKey: '',
        condition: RelationshipCondition.dormant,
        conditionMeans: '', conditionBecause: '',
        reachability: Reachability.notAttempted,
        reachabilityMeans: '', reachabilityBecause: '',
        origin: RelationshipOrigin.fromJson(null),
        engagements: const [], currentEngagementId: null,
        attention: const [], timeline: const [], eventCount: 0,
        refusalReason: (j['reason'] as String?) ??
            'Your business has no relationship on record with that counterparty.',
      );
    }
    final counts = Map<String, dynamic>.from(j['counts'] as Map? ?? {});
    return RelationshipDepth(
      id: (j['id'] as String?) ?? '',
      counterparty: (j['counterparty'] as String?)?.trim().isEmpty ?? true
          ? '(unnamed)'
          : (j['counterparty'] as String).trim(),
      counterpartyKey: (j['counterpartyKey'] as String?) ?? '',
      condition: RelationshipCondition.parse(j['condition'] as String?),
      conditionMeans: (j['conditionMeans'] as String?) ?? '',
      conditionBecause: (j['conditionBecause'] as String?) ?? '',
      reachability: Reachability.parse(j['reachability'] as String?),
      reachabilityMeans: (j['reachabilityMeans'] as String?) ?? '',
      reachabilityBecause: (j['reachabilityBecause'] as String?) ?? '',
      origin: RelationshipOrigin.fromJson(
          j['origin'] is Map ? Map<String, dynamic>.from(j['origin'] as Map) : null),
      engagements: ((j['engagements'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => EngagementSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      currentEngagementId: _text(j['currentEngagementId']),
      attention: ((j['attention'] as List?) ?? const [])
          .whereType<Map>()
          .map((a) => RelationshipAttention.fromJson(Map<String, dynamic>.from(a)))
          .toList(growable: false),
      timeline: ((j['timeline'] as List?) ?? const [])
          .whereType<Map>()
          .map((t) => TimelineEntry.fromJson(Map<String, dynamic>.from(t)))
          .toList(growable: false),
      eventCount: (counts['events'] as num?)?.toInt() ?? 0,
      refusalReason: null,
    );
  }
}

String? _text(Object? value) {
  final s = value?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}
