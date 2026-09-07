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
    this.unattachedMeetings = const [],
    this.viewCounts = const {},
  });

  final List<RelationshipSummary> relationships;
  final Map<RelationshipCondition, int> counts;
  final String note;

  /// Meetings this business holds that belong to no relationship on record.
  ///
  /// Real, and previously invisible. A meeting offered before invitees were
  /// recorded has nothing to correlate on, and a meeting with somebody the
  /// business has no relationship row for is still a commitment somebody may
  /// attend. Forcing a correlation would put it on a stranger's record.
  final List<RelationshipMeeting> unattachedMeetings;

  /// How many relationships each saved view holds, counted before filtering.
  ///
  /// A view that is currently empty still reports zero rather than
  /// disappearing. A tab that vanishes when it has nothing in it is how a
  /// person stops believing the tabs are the whole picture.
  final Map<String, int> viewCounts;

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
      unattachedMeetings: RelationshipMeeting.listFrom(j['unattachedMeetings']),
      viewCounts: {
        for (final e in (Map<String, dynamic>.from(j['viewCounts'] as Map? ?? {})).entries)
          e.key: (e.value as num?)?.toInt() ?? 0,
      },
    );
  }
}

/// A meeting, seen from inside the relationship it belongs to.
///
/// Meetings stopped being a destination on the grounds that they are events
/// inside a relationship. This is the type that makes that true rather than
/// only stated — before it, a booked meeting appeared nowhere in the workspace
/// at all.
class RelationshipMeeting {
  const RelationshipMeeting({
    required this.id,
    required this.title,
    required this.status,
    required this.handoffStage,
    required this.scheduledAt,
    required this.entrance,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String status;

  /// Whether the meeting exists on the provider. A meeting that never reached
  /// it was never offered to anybody, whatever its status says.
  final String handoffStage;
  final DateTime? scheduledAt;

  /// When it actually began and ended, which may legitimately differ from the
  /// schedule. Three facts, none standing in for another: a meeting due at one
  /// and held at ten is a true thing that happened, and a surface given only
  /// one timestamp has to present the plan as though it were the event.
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Did this actually happen?
  bool get wasHeld => startedAt != null;

  /// Held far enough from its schedule that saying so is worth the words.
  ///
  /// Fifteen minutes, because meetings routinely start a little late and
  /// captioning that would be noise. Three hours early is not noise.
  bool get heldAwayFromSchedule {
    final due = scheduledAt;
    final held = startedAt;
    if (due == null || held == null) return false;
    return held.difference(due).abs() > const Duration(minutes: 15);
  }

  /// Where the counterparty goes. Absent when there is more than one invitee,
  /// because then there is no single door.
  final String? entrance;

  bool get neverReachedProvider => handoffStage == 'NEVER_REACHED_PROVIDER';

  static const _settled = {'COMPLETED', 'CANCELED', 'NO_SHOW'};

  /// Still going to happen.
  ///
  /// A settled meeting is not ahead, and neither is one the provider never
  /// confirmed — nobody was invited to that, so there is nothing to be ahead
  /// of. Both halves are needed: a booked meeting sitting in the same list as
  /// four cancelled ones reads as archive, and the live one disappears into
  /// it.
  bool get isAhead {
    if (_settled.contains(status.toUpperCase())) return false;
    if (neverReachedProvider) return false;
    final at = scheduledAt;
    return at != null && at.isAfter(DateTime.now());
  }

  static RelationshipMeeting fromJson(Map<String, dynamic> j) => RelationshipMeeting(
        id: (j['id'] as String?) ?? '',
        title: _text(j['title']) ?? 'Meeting',
        status: (j['status'] as String?) ?? '',
        handoffStage: (j['handoffStage'] as String?) ?? '',
        scheduledAt: DateTime.tryParse('${j['scheduledAt'] ?? ''}'),
        startedAt: DateTime.tryParse('${j['startedAt'] ?? ''}'),
        completedAt: DateTime.tryParse('${j['completedAt'] ?? ''}'),
        entrance: _text(j['entrance']),
      );

  static List<RelationshipMeeting> listFrom(Object? raw) =>
      ((raw as List?) ?? const [])
          .whereType<Map>()
          .map((m) => RelationshipMeeting.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
}

/// ONE COMMERCIAL OBLIGATION, WHICH IS THE ONLY PART OF THIS WITH A CLOCK.
class CommercialObligationView {
  const CommercialObligationView({
    required this.id,
    required this.description,
    required this.state,
    required this.dueAt,
    required this.owedBy,
  });

  final String id;
  final String description;
  final String state;
  final DateTime? dueAt;

  /// Whose obligation it is. A thing this business owes and a thing it is
  /// owed are opposite situations, and a surface that renders them alike is
  /// telling somebody to chase their own commitment.
  final String owedBy;

  bool get owedByUs => owedBy.toUpperCase() == 'CLIENT';

  static CommercialObligationView fromJson(Map<String, dynamic> j) =>
      CommercialObligationView(
        id: (j['id'] as String?) ?? '',
        description: _text(j['description']) ?? 'Obligation',
        state: (j['state'] as String?) ?? '',
        dueAt: DateTime.tryParse('${j['dueAt'] ?? ''}'),
        owedBy: (j['owedBy'] as String?) ?? '',
      );
}

/// AGREEMENT → OBLIGATION → INVOICE → PAYMENT, AS ONE CONTINUITY.
///
/// Four counts rather than four modules, because the sequence is the point: an
/// obligation exists because something was agreed, an invoice because
/// something was owed, a payment because something was invoiced. Rendered as
/// separate lists, a business would have to assemble that itself.
///
/// Production holds none of these for any client. That absence is the reason
/// to give them a home now rather than later: without one, the first agreement
/// a business signs arrives into a product with nowhere to show it.
class RelationshipCommercial {
  const RelationshipCommercial({
    this.agreements = 0,
    this.obligations = 0,
    this.invoices = 0,
    this.payments = 0,
    this.dueNext = const [],
    this.says = '',
    this.explains,
  });

  final int agreements;
  final int obligations;
  final int invoices;
  final int payments;

  /// Obligations still owed, soonest first.
  final List<CommercialObligationView> dueNext;

  final String says;

  /// The honest empty state: what belongs here and why none exists yet.
  final String? explains;

  bool get isEmpty =>
      agreements == 0 && obligations == 0 && invoices == 0 && payments == 0;

  static RelationshipCommercial fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RelationshipCommercial();
    int len(Object? v) => (v is List) ? v.length : 0;
    return RelationshipCommercial(
      agreements: len(j['agreements']),
      obligations: len(j['obligations']),
      invoices: len(j['invoices']),
      payments: len(j['payments']),
      dueNext: ((j['dueNext'] as List?) ?? const [])
          .whereType<Map>()
          .map((o) => CommercialObligationView.fromJson(
              Map<String, dynamic>.from(o)))
          .toList(growable: false),
      says: (j['says'] as String?) ?? '',
      explains: _text(j['explains']),
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
    this.authority = '',
    this.subjectType,
    this.subjectId,
    this.decidedCondition = false,
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

  /// Who says so. An observed fact and an admitted one are not equal, and a
  /// history that renders them alike is asserting more than it knows.
  final String authority;

  /// What this fact concerned, and therefore what could be opened from it.
  final String? subjectType;
  final String? subjectId;

  /// One of the facts that made the relationship's condition what it is.
  ///
  /// Set by the server from the same ladder that derived the condition. The
  /// client does not decide this — a second condition engine here is how two
  /// surfaces come to disagree about the same relationship.
  final bool decidedCondition;

  /// Whether this fact was admitted rather than merely observed.
  bool get isAdmitted => authority.toUpperCase().contains('ADMIT') ||
      authority.toUpperCase() == 'CLIENT' ||
      authority.toUpperCase() == 'COUNTERPARTY';

  static TimelineEntry fromJson(Map<String, dynamic> j) => TimelineEntry(
        kind: (j['kind'] as String?) ?? 'OTHER',
        says: (j['says'] as String?) ?? '',
        at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime(1970),
        authority: (j['authority'] as String?) ?? '',
        subjectType: _text(j['subjectType']),
        subjectId: _text(j['subjectId']),
        decidedCondition: j['decidedCondition'] == true,
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
    this.meetingsUpcoming = const [],
    this.meetingsPast = const [],
    this.meetingsSays = '',
    this.commercial = const RelationshipCommercial(),
    this.conditionDecidedBy = '',
    this.conditionShownInHistory = false,
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

  /// Meetings held with this counterparty.
  final List<RelationshipMeeting> meetingsUpcoming;
  final List<RelationshipMeeting> meetingsPast;
  final String meetingsSays;

  bool get hasMeetings => meetingsUpcoming.isNotEmpty || meetingsPast.isNotEmpty;

  /// What has been agreed, owed, invoiced and paid with this counterparty.
  final RelationshipCommercial commercial;

  /// Which class of admitted fact decided the condition.
  final String conditionDecidedBy;

  /// Whether there is anything in the history to point at.
  ///
  /// Some conditions are decided by the ABSENCE of facts — nothing recorded,
  /// or nothing for ninety days. There is no entry to highlight, and a surface
  /// has to say that in words rather than mark a row that does not exist.
  final bool conditionShownInHistory;

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
      meetingsUpcoming: RelationshipMeeting.listFrom(
          (j['meetings'] as Map?)?['upcoming']),
      meetingsPast: RelationshipMeeting.listFrom((j['meetings'] as Map?)?['past']),
      meetingsSays: ((j['meetings'] as Map?)?['says'] as String?) ?? '',
      conditionDecidedBy: (j['conditionDecidedBy'] as String?) ?? '',
      conditionShownInHistory: j['conditionShownInHistory'] == true,
      commercial: RelationshipCommercial.fromJson(
          j['commercial'] is Map
              ? Map<String, dynamic>.from(j['commercial'] as Map)
              : null),
    );
  }
}

String? _text(Object? value) {
  final s = value?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}
