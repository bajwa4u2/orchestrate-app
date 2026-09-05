import '../../../core/authority/consequence.dart';
import '../../../core/network/api_client.dart';

export '../../../core/authority/consequence.dart' show Consequence;

/// What this business, and this person, may actually do.
///
/// The backend decides every one of these answers. This repository types the
/// reply and nothing else — it holds no rule, no threshold and no fallback. A
/// client-side "if they're the owner, probably yes" is precisely the kind of
/// second opinion that ends with a company being told it agreed to something
/// nobody authorised, so there isn't one.
///
/// The human sentences (`meaning`, `why`, `resolution`) also come from the
/// backend. They are the same words in every surface because they are written
/// once, on the side that knows why the answer is what it is.
class ClientAuthorityRepository {
  ClientAuthorityRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Standing authority: the business, this person, and Orchestrate.
  Future<AuthorityProjection> fetch() async {
    final json = await _apiClient.getJson(
      '/client/authority/projection',
      surface: ApiSurface.client,
    );
    return AuthorityProjection.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Where this person's designation stands, and what supports it.
  ///
  /// Its own call rather than a field on the projection: the projection answers
  /// "what may happen", and this answers "what did I send and what is being
  /// relied on". Conflating them is how "we are reviewing what you sent" ended
  /// up being the whole of what a business could learn.
  Future<EvidenceStanding> evidence() async {
    final json = await _apiClient.getJson(
      '/client/representative/evidence',
      surface: ApiSurface.client,
    );
    return EvidenceStanding.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Add something supporting to a submission still under review.
  Future<({bool ok, String? reason})> addSupport(String reference) async {
    final json = await _apiClient.postJson(
      '/client/representative/evidence',
      body: {'reference': reference},
      surface: ApiSurface.client,
    );
    final map = Map<String, dynamic>.from(json as Map);
    return (ok: map['ok'] == true, reason: map['reason'] as String?);
  }

  /// Whether one specific act may proceed, and if not, why.
  ///
  /// Asking causes nothing, so a screen can shape itself around the answer
  /// before it offers the act rather than refusing after the click.
  Future<ActionAuthority> can({
    required Consequence consequence,
    PerformedBy by = PerformedBy.human,
  }) async {
    final json = await _apiClient.getJson(
      '/client/authority/can',
      surface: ApiSurface.client,
      query: {'consequence': consequence.wire, 'by': by.wire},
    );
    return ActionAuthority.fromJson(Map<String, dynamic>.from(json as Map));
  }
}

/// Who would carry the act out. The same act has different answers.
enum PerformedBy {
  /// The person, themselves, in the product.
  human('HUMAN'),

  /// Orchestrate, on the business's behalf, which needs delegation the person
  /// having the authority does not by itself supply.
  orchestrate('ORCHESTRATE');

  const PerformedBy(this.wire);
  final String wire;
}

/// The three areas a business grants separately. Never a ranking: holding
/// financial authority says nothing about agreements, and vice versa.
enum AuthorityArea {
  communication('COMMUNICATION'),
  contractual('CONTRACTUAL'),
  financial('FINANCIAL');

  const AuthorityArea(this.wire);
  final String wire;

  static AuthorityArea? parse(String? value) {
    for (final area in AuthorityArea.values) {
      if (area.wire == value) return area;
    }
    return null;
  }
}

/// Where a person's own designation stands.
///
/// Six states, because they are six different situations. "Pending" for all of
/// them would tell a refused applicant to keep waiting and tell someone we need
/// something from that everything is fine.
enum SubmissionState {
  notSubmitted('NOT_SUBMITTED'),
  submitted('SUBMITTED'),
  moreEvidenceRequested('MORE_EVIDENCE_REQUESTED'),
  admitted('ADMITTED'),
  refused('REFUSED'),
  superseded('SUPERSEDED');

  const SubmissionState(this.wire);
  final String wire;

  static SubmissionState parse(String? value) {
    for (final s in SubmissionState.values) {
      if (s.wire == value) return s;
    }
    return SubmissionState.notSubmitted;
  }

  /// Whether this state is waiting on Orchestrate rather than on the person.
  bool get waitingOnUs => this == SubmissionState.submitted;

  /// Whether the person has something to do about it.
  bool get needsYou =>
      this == SubmissionState.moreEvidenceRequested || this == SubmissionState.refused;
}

class Submission {
  const Submission({
    required this.state,
    required this.since,
    required this.asserted,
    required this.operatorAsked,
    required this.refusedBecause,
    required this.meaning,
  });

  final SubmissionState state;
  final DateTime? since;

  /// What the person said the business authorises them to do.
  final String? asserted;

  /// The operator's own words when they could not tell.
  final String? operatorAsked;

  /// The operator's own words when they refused.
  final String? refusedBecause;
  final String meaning;

  static Submission fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const Submission(
        state: SubmissionState.notSubmitted,
        since: null, asserted: null, operatorAsked: null,
        refusedBecause: null, meaning: '',
      );
    }
    return Submission(
      state: SubmissionState.parse(json['state'] as String?),
      since: DateTime.tryParse(json['since']?.toString() ?? ''),
      asserted: (json['asserted'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['asserted'] as String).trim(),
      operatorAsked: (json['operatorAsked'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['operatorAsked'] as String).trim(),
      refusedBecause: (json['refusedBecause'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['refusedBecause'] as String).trim(),
      meaning: (json['meaning'] as String?) ?? '',
    );
  }
}

/// WHERE ORCHESTRATE'S OWN AUTHORITY CAME FROM.
///
/// Without this, a person reads "your business has not recognised you as able
/// to decide for it" and, directly beneath it, "Orchestrate may communicate on
/// your behalf", and the two look like they cannot both be true. They are both
/// true, and the bridge is a record: somebody accepted, on a date, somewhere in
/// the product, and — for the oldest rows — named no areas at all.
class GrantProvenance {
  const GrantProvenance({
    required this.acceptedBy,
    required this.acceptedAt,
    required this.scopeWasStated,
    required this.say,
    required this.why,
  });

  final String acceptedBy;
  final DateTime? acceptedAt;

  /// False when the record named no areas, so it resolves to communication
  /// only. Different from a business deciding communication only.
  final bool scopeWasStated;

  /// What happened, in a sentence a person can check.
  final String say;

  /// Why that permits what it permits.
  final String why;

  static GrantProvenance? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return GrantProvenance(
      acceptedBy: (json['acceptedBy'] as String?) ?? 'someone in this workspace',
      acceptedAt: DateTime.tryParse('${json['acceptedAt'] ?? ''}'),
      scopeWasStated: json['scopeWasStated'] == true,
      say: (json['say'] as String?) ?? '',
      why: (json['why'] as String?) ?? '',
    );
  }
}

/// What a claim rests on, and what is still being asked for.
class EvidenceStanding {
  const EvidenceStanding({
    required this.state,
    required this.claimed,
    required this.admitted,
    required this.notAdmitted,
    required this.reliedUpon,
    required this.asking,
    required this.refusedBecause,
    required this.mayAddSupport,
  });

  final SubmissionState state;

  /// The areas this person said the business authorised them for.
  final List<String> claimed;
  final List<String> admitted;

  /// Claimed and not admitted. Only meaningful once a decision exists.
  final List<String> notAdmitted;

  /// What Orchestrate is already relying on, rather than asking for again.
  final List<({String what, String detail})> reliedUpon;

  /// What is being asked of this person now, when anything is.
  final ({String what, String why, String how})? asking;

  final String? refusedBecause;

  /// Evidence may only be added to something still under review. Attaching it
  /// to a decided submission would supply evidence for a judgement already
  /// made.
  final bool mayAddSupport;

  static EvidenceStanding fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic raw) =>
        ((raw as List?) ?? const []).whereType<String>().toList();
    final asking = json['asking'];
    return EvidenceStanding(
      state: SubmissionState.parse(json['state'] as String?),
      claimed: strings(json['claimed']),
      admitted: strings(json['admitted']),
      notAdmitted: strings(json['notAdmitted']),
      reliedUpon: ((json['reliedUpon'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => (
                what: '${m['what'] ?? ''}',
                detail: '${m['detail'] ?? ''}',
              ))
          .toList(growable: false),
      asking: asking is Map
          ? (
              what: '${asking['what'] ?? ''}',
              why: '${asking['why'] ?? ''}',
              how: '${asking['how'] ?? ''}',
            )
          : null,
      refusedBecause: (json['refusedBecause'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['refusedBecause'] as String).trim(),
      mayAddSupport: json['mayAddSupport'] == true,
    );
  }
}

class AuthorityProjection {
  const AuthorityProjection({
    required this.businessName,
    required this.legalNameOnRecord,
    required this.submission,
    required this.organizationEstablished,
    required this.recognisedPeople,
    required this.underReview,
    required this.organizationMeaning,
    required this.youAreRecognised,
    required this.describedAs,
    required this.areas,
    required this.youMeaning,
    required this.orchestrateDelegated,
    required this.orchestrateEverGranted,
    required this.orchestrateIsLegacyCommunicationOnly,
    required this.orchestrateMeaning,
    this.orchestrateProvenance,
    required this.missing,
  });

  final String businessName;
  final bool legalNameOnRecord;

  /// Where this person's own designation stands.
  final Submission submission;

  /// Whether the business has named anyone at all. Distinct from whether *you*
  /// are one of them, because the honest sentence differs.
  final bool organizationEstablished;
  final int recognisedPeople;
  final bool underReview;
  final String organizationMeaning;

  final bool youAreRecognised;

  /// What the business calls this person. Recorded; carries no authority.
  final String? describedAs;
  final List<AreaStanding> areas;
  final String youMeaning;

  final List<String> orchestrateDelegated;
  final bool orchestrateEverGranted;
  final bool orchestrateIsLegacyCommunicationOnly;
  final String orchestrateMeaning;

  /// Where Orchestrate's authority came from. Null when it has none.
  final GrantProvenance? orchestrateProvenance;

  /// Genuine blockers only. A settled step is never listed as a satisfied
  /// checkbox, because a list of ticks is a progress bar wearing a disguise.
  final List<MissingStep> missing;

  AreaStanding? area(AuthorityArea which) {
    for (final a in areas) {
      if (a.area == which) return a;
    }
    return null;
  }

  bool canAct(AuthorityArea which) => area(which)?.canAct ?? false;

  /// True when this person may establish someone else in any area at all.
  bool get canRecogniseAnyone => areas.any((a) => a.canRecogniseOthers);

  static AuthorityProjection fromJson(Map<String, dynamic> json) {
    final business = Map<String, dynamic>.from(json['business'] as Map? ?? {});
    final org = Map<String, dynamic>.from(json['organization'] as Map? ?? {});
    final you = Map<String, dynamic>.from(json['you'] as Map? ?? {});
    final orch = Map<String, dynamic>.from(json['orchestrate'] as Map? ?? {});
    return AuthorityProjection(
      businessName: (business['name'] as String?)?.trim().isNotEmpty == true
          ? (business['name'] as String).trim()
          : 'This business',
      legalNameOnRecord: business['legalNameOnRecord'] == true,
      submission: Submission.fromJson(json['submission'] is Map
          ? Map<String, dynamic>.from(json['submission'] as Map)
          : null),
      organizationEstablished: org['established'] == true,
      recognisedPeople: (org['recognisedPeople'] as num?)?.toInt() ?? 0,
      underReview: org['underReview'] == true,
      organizationMeaning: (org['meaning'] as String?) ?? '',
      youAreRecognised: you['recognised'] == true,
      describedAs: (you['describedAs'] as String?)?.trim().isEmpty ?? true
          ? null
          : (you['describedAs'] as String).trim(),
      areas: ((you['areas'] as List?) ?? const [])
          .whereType<Map>()
          .map((a) => AreaStanding.fromJson(Map<String, dynamic>.from(a)))
          .where((a) => a.area != null)
          .toList(growable: false),
      youMeaning: (you['meaning'] as String?) ?? '',
      orchestrateDelegated: ((orch['delegated'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      orchestrateEverGranted: orch['everGranted'] == true,
      orchestrateIsLegacyCommunicationOnly: orch['isLegacyCommunicationOnly'] == true,
      orchestrateMeaning: (orch['meaning'] as String?) ?? '',
      orchestrateProvenance: GrantProvenance.fromJson(
        orch['provenance'] is Map
            ? Map<String, dynamic>.from(orch['provenance'] as Map)
            : null,
      ),
      missing: ((json['missing'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => MissingStep.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}

class AreaStanding {
  const AreaStanding({
    required this.area,
    required this.label,
    required this.canAct,
    required this.canAuthoriseOrchestrate,
    required this.canRecogniseOthers,
  });

  final AuthorityArea? area;

  /// The business-facing name for the area, from the backend.
  final String label;

  /// May this person approve acts of this class themselves.
  final bool canAct;

  /// May this person let Orchestrate act in this area. A separate fact from
  /// [canAct]: doing something yourself and letting software do it are not the
  /// same decision.
  final bool canAuthoriseOrchestrate;

  /// May this person recognise someone else in this area.
  final bool canRecogniseOthers;

  static AreaStanding fromJson(Map<String, dynamic> json) => AreaStanding(
        area: AuthorityArea.parse(json['capability'] as String?),
        label: (json['label'] as String?) ?? '',
        canAct: json['canAct'] == true,
        canAuthoriseOrchestrate: json['canAuthoriseOrchestrate'] == true,
        canRecogniseOthers: json['canRecogniseOthers'] == true,
      );
}

class MissingStep {
  const MissingStep({required this.key, required this.say, required this.because});

  final String key;

  /// What is missing, in a sentence.
  final String say;

  /// Why it matters. Present so a blocker never reads as bureaucracy.
  final String because;

  static MissingStep fromJson(Map<String, dynamic> json) => MissingStep(
        key: (json['key'] as String?) ?? '',
        say: (json['say'] as String?) ?? '',
        because: (json['because'] as String?) ?? '',
      );
}

class ActionAuthority {
  const ActionAuthority({
    required this.permitted,
    required this.consequence,
    required this.requiresLabel,
    required this.refusal,
  });

  final bool permitted;
  final String consequence;

  /// The area this act needs, when it needs one. Null for internal work.
  final String? requiresLabel;
  final AuthorityRefusal? refusal;

  static ActionAuthority fromJson(Map<String, dynamic> json) {
    final requires = json['requires'] as Map?;
    final refusal = json['refusal'] as Map?;
    return ActionAuthority(
      permitted: json['permitted'] == true,
      consequence: (json['consequence'] as String?) ?? '',
      requiresLabel: requires == null ? null : requires['label'] as String?,
      refusal: refusal == null
          ? null
          : AuthorityRefusal.fromJson(Map<String, dynamic>.from(refusal)),
    );
  }
}

/// A refusal that explains itself.
///
/// [code] is for us; [why] and [resolution] are for the person. A refusal
/// without a resolution is a dead end, and the backend does not issue one.
class AuthorityRefusal {
  const AuthorityRefusal({
    required this.code,
    required this.why,
    required this.resolution,
  });

  final String code;
  final String why;
  final String resolution;

  static AuthorityRefusal fromJson(Map<String, dynamic> json) => AuthorityRefusal(
        code: (json['code'] as String?) ?? 'REFUSED',
        why: (json['why'] as String?) ?? '',
        resolution: (json['resolution'] as String?) ?? '',
      );
}
