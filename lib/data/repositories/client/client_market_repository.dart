import '../../../core/network/api_client.dart';

/// WHO MAY BE WORTH ENTERING INTO COMMERCIAL RELATIONSHIP WITH, AND WHY.
///
/// The server composes the commercial meaning. This types the answer and adds
/// nothing: no local scoring, no re-ranking, no "looks promising" rule. Five
/// surfaces each interpreting entities, signals and qualifications would arrive
/// at five opinions about the same company, and a business would act on
/// whichever one it happened to open.
class ClientMarketRepository {
  ClientMarketRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<MarketView> fetch({bool includeDeclined = false}) async {
    final json = await _apiClient.getJson(
      '/client/market',
      surface: ApiSurface.client,
      query: {if (includeDeclined) 'includeDeclined': 'true'},
    );
    return MarketView.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<CandidateDepth> candidate(String key) async {
    final json = await _apiClient.getJson(
      '/client/market/candidate/$key',
      surface: ApiSurface.client,
    );
    return CandidateDepth.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<Map<String, dynamic>> setPursuit({
    required String key,
    required PursuitDisposition disposition,
    String? note,
  }) async {
    final json = await _apiClient.postJson(
      '/client/market/candidate/$key/pursuit',
      surface: ApiSurface.client,
      body: {
        'disposition': disposition.wire,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Whether reaching out could proceed. A read — asking causes nothing.
  Future<Map<String, dynamic>> outreachReadiness(String key) async {
    final json = await _apiClient.getJson(
      '/client/market/candidate/$key/outreach-readiness',
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }
}

/// The business's own view of a counterparty. Internal judgement, always.
///
/// None of these sends anything, admits anything, or creates relationship
/// continuity. `pursuing` means someone decided it is worth effort — it must
/// never read as having made contact.
enum PursuitDisposition {
  unreviewed('UNREVIEWED', 'Not looked at'),
  pursuing('PURSUING', 'Worth pursuing'),
  holding('HOLDING', 'Keep in view'),
  declined('DECLINED', 'Not pursuing');

  const PursuitDisposition(this.wire, this.label);
  final String wire;
  final String label;

  static PursuitDisposition parse(String? value) {
    for (final d in PursuitDisposition.values) {
      if (d.wire == value) return d;
    }
    return PursuitDisposition.unreviewed;
  }
}

/// How much weight the current reading can carry.
enum Certainty {
  evidenced('EVIDENCED', 'Evidenced'),
  thin('THIN', 'Thin evidence'),
  insufficient('INSUFFICIENT', 'Not enough observed'),
  stale('STALE', 'Aged');

  const Certainty(this.wire, this.label);
  final String wire;
  final String label;

  static Certainty parse(String? value) {
    for (final c in Certainty.values) {
      if (c.wire == value) return c;
    }
    return Certainty.insufficient;
  }
}

/// What this business sells, and to whom.
///
/// Without it, "worth pursuing" has no object and every judgement below it is
/// unanchored. Composed by the server from the client's own offer.
class BusinessIntent {
  const BusinessIntent({
    required this.capability,
    required this.outcome,
    required this.buyerSituation,
    required this.triggers,
    required this.says,
  });

  final String capability;
  final String outcome;
  final String buyerSituation;
  final List<String> triggers;

  /// The whole thing in one sentence.
  final String says;

  static BusinessIntent? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return BusinessIntent(
      capability: (json['capability'] as String?) ?? '',
      outcome: (json['outcome'] as String?) ?? '',
      buyerSituation: (json['buyerSituation'] as String?) ?? '',
      triggers: ((json['triggers'] as List?) ?? const []).whereType<String>().toList(),
      says: (json['says'] as String?) ?? '',
    );
  }
}

class Candidate {
  const Candidate({
    required this.key,
    required this.name,
    required this.domain,
    required this.geography,
    required this.contactName,
    required this.contactRole,
    required this.hasRelationship,
    required this.relationshipId,
    required this.whyItMatters,
    required this.opportunityStrength,
    required this.opportunityConfidence,
    required this.certainty,
    required this.certaintyMeans,
    required this.evidenceCount,
    required this.newestEvidenceAt,
    required this.decision,
    required this.decidedAt,
    required this.reasons,
    required this.disposition,
    required this.dispositionMeans,
    required this.dispositionNote,
    required this.discoveredRepresentations,
  });

  /// Canonical counterparty identity. Server-derived and stable — never a
  /// generated id, which would make identity depend on when the page rendered.
  final String key;
  final String name;
  final String domain;
  final String? geography;
  final String? contactName;
  final String? contactRole;

  final bool hasRelationship;
  final String? relationshipId;

  /// Evidence-backed rationale, from the server, verbatim.
  final String? whyItMatters;
  final String? opportunityStrength;
  final int? opportunityConfidence;

  final Certainty certainty;
  final String certaintyMeans;

  /// Corroborated observations only. Not the generated scaffolding.
  final int evidenceCount;
  final DateTime? newestEvidenceAt;

  final String? decision;
  final DateTime? decidedAt;

  /// Sentences a person can act on. Never scoring internals.
  final List<String> reasons;

  final PursuitDisposition disposition;
  final String dispositionMeans;
  final String? dispositionNote;

  /// How many times discovery saw this one company.
  final int discoveredRepresentations;

  /// Whether this is waiting on a person's judgement.
  ///
  /// The test is a stated commercial reason, not a certainty grade — gating on
  /// evidence alone empties the surface, because every observation in
  /// production is either months old or came from the counterparty's own site.
  /// The certainty travels with it and the row leads with it when weak, so a
  /// person sees both the reason and how well-founded it is.
  bool get needsReview =>
      disposition == PursuitDisposition.unreviewed &&
      !hasRelationship &&
      (whyItMatters != null ||
          certainty == Certainty.evidenced ||
          certainty == Certainty.thin);

  static Candidate fromJson(Map<String, dynamic> json) {
    final judgement = json['judgement'] as Map?;
    return Candidate(
      key: (json['key'] as String?) ?? '',
      name: (json['name'] as String?)?.trim().isEmpty ?? true
          ? '(unnamed)'
          : (json['name'] as String).trim(),
      domain: (json['domain'] as String?) ?? '',
      geography: _text(json['geography']),
      contactName: _text(json['contactName']),
      contactRole: _text(json['contactRole']),
      hasRelationship: json['standing'] == 'RELATIONSHIP_EXISTS',
      relationshipId: _text(json['relationshipId']),
      whyItMatters: _text(json['whyItMatters']),
      opportunityStrength: _text(json['opportunityStrength']),
      opportunityConfidence: (json['opportunityConfidence'] as num?)?.toInt(),
      certainty: Certainty.parse(json['certainty'] as String?),
      certaintyMeans: (json['certaintyMeans'] as String?) ?? '',
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
      newestEvidenceAt: DateTime.tryParse(json['newestEvidenceAt']?.toString() ?? ''),
      decision: judgement == null ? null : _text(judgement['decision']),
      decidedAt: judgement == null
          ? null
          : DateTime.tryParse(judgement['decidedAt']?.toString() ?? ''),
      reasons: judgement == null
          ? const []
          : ((judgement['reasons'] as List?) ?? const [])
              .whereType<Map>()
              .map((r) => (r['say'] as String?) ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false),
      disposition: PursuitDisposition.parse(json['disposition'] as String?),
      dispositionMeans: (json['dispositionMeans'] as String?) ?? '',
      dispositionNote: _text(json['dispositionNote']),
      discoveredRepresentations:
          (json['discoveredRepresentations'] as num?)?.toInt() ?? 1,
    );
  }
}

class CandidateDepth {
  const CandidateDepth({
    required this.candidate,
    required this.intent,
    required this.evidence,
    required this.opportunityNarrative,
    required this.discoveredAt,
    required this.campaigns,
    required this.representations,
    required this.refusalReason,
  });

  final Candidate? candidate;
  final BusinessIntent? intent;
  final List<Observation> evidence;
  final String? opportunityNarrative;
  final DateTime? discoveredAt;
  final int campaigns;
  final int representations;
  final String? refusalReason;

  static CandidateDepth fromJson(Map<String, dynamic> json) {
    if (json['ok'] == false) {
      return CandidateDepth(
        candidate: null, intent: null, evidence: const [],
        opportunityNarrative: null, discoveredAt: null,
        campaigns: 0, representations: 0,
        refusalReason: (json['reason'] as String?) ??
            'That counterparty is not in your market.',
      );
    }
    final prov = Map<String, dynamic>.from(json['provenance'] as Map? ?? {});
    return CandidateDepth(
      candidate: Candidate.fromJson(json),
      intent: BusinessIntent.fromJson(
          json['intent'] is Map ? Map<String, dynamic>.from(json['intent'] as Map) : null),
      evidence: ((json['evidence'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Observation.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      opportunityNarrative: _text(json['opportunityNarrative']),
      discoveredAt: DateTime.tryParse(prov['discoveredAt']?.toString() ?? ''),
      campaigns: (prov['campaigns'] as num?)?.toInt() ?? 0,
      representations: (prov['representations'] as num?)?.toInt() ?? 0,
      refusalReason: null,
    );
  }
}

/// Something actually observed, with where it came from.
class Observation {
  const Observation({
    required this.kind,
    required this.headline,
    required this.source,
    required this.observedAt,
    required this.corroborated,
  });

  final String kind;
  final String headline;
  final String? source;
  final DateTime observedAt;
  final bool corroborated;

  static Observation fromJson(Map<String, dynamic> json) => Observation(
        kind: (json['kind'] as String?) ?? '',
        headline: (json['headline'] as String?) ?? '',
        source: _text(json['source']),
        observedAt:
            DateTime.tryParse(json['observedAt']?.toString() ?? '') ?? DateTime(1970),
        corroborated: json['corroborated'] == true,
      );
}

class MarketView {
  const MarketView({
    required this.intent,
    required this.candidates,
    required this.excludedWithoutIdentity,
    required this.excludedArtifacts,
    required this.excludedNote,
    required this.counts,
  });

  final BusinessIntent? intent;
  final List<Candidate> candidates;

  /// Counted, not hidden. A Market that silently drops a third of what
  /// discovery found is not one a business can rely on.
  final int excludedWithoutIdentity;
  final int excludedArtifacts;
  final String? excludedNote;

  final MarketCounts counts;

  List<Candidate> get needsReview =>
      candidates.where((c) => c.needsReview).toList(growable: false);

  List<Candidate> get decided => candidates
      .where((c) =>
          !c.hasRelationship &&
          c.disposition != PursuitDisposition.unreviewed)
      .toList(growable: false);

  /// Real companies nobody has observed anything about. Shown honestly rather
  /// than ranked as though they were findings.
  List<Candidate> get notEnoughKnown => candidates
      .where((c) =>
          !c.hasRelationship &&
          c.disposition == PursuitDisposition.unreviewed &&
          !c.needsReview)
      .toList(growable: false);

  List<Candidate> get alreadyRelated =>
      candidates.where((c) => c.hasRelationship).toList(growable: false);

  static MarketView fromJson(Map<String, dynamic> json) {
    final excluded = Map<String, dynamic>.from(json['excluded'] as Map? ?? {});
    final counts = Map<String, dynamic>.from(json['counts'] as Map? ?? {});
    return MarketView(
      intent: BusinessIntent.fromJson(
          json['intent'] is Map ? Map<String, dynamic>.from(json['intent'] as Map) : null),
      candidates: ((json['candidates'] as List?) ?? const [])
          .whereType<Map>()
          .map((c) => Candidate.fromJson(Map<String, dynamic>.from(c)))
          .toList(growable: false),
      excludedWithoutIdentity: (excluded['withoutIdentity'] as num?)?.toInt() ?? 0,
      excludedArtifacts: (excluded['discoveryArtifacts'] as num?)?.toInt() ?? 0,
      excludedNote: _text(excluded['note']),
      counts: MarketCounts(
        total: (counts['total'] as num?)?.toInt() ?? 0,
        needsReview: (counts['needsReview'] as num?)?.toInt() ?? 0,
        pursuing: (counts['pursuing'] as num?)?.toInt() ?? 0,
        alreadyRelated: (counts['alreadyRelated'] as num?)?.toInt() ?? 0,
        insufficientEvidence: (counts['insufficientEvidence'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class MarketCounts {
  const MarketCounts({
    required this.total,
    required this.needsReview,
    required this.pursuing,
    required this.alreadyRelated,
    required this.insufficientEvidence,
  });

  final int total;
  final int needsReview;
  final int pursuing;
  final int alreadyRelated;
  final int insufficientEvidence;
}

String? _text(Object? value) {
  final s = value?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}
