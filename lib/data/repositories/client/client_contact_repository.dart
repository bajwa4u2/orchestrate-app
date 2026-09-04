import '../../../core/network/api_client.dart';

/// DO WE HAVE A CONTACT WE MAY RESPONSIBLY USE.
///
/// Not "is this mailbox verified" — the platform cannot answer that and does
/// not pretend to. Every judgement here comes from the server; this types the
/// answer and adds nothing.
class ClientContactRepository {
  ClientContactRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<ContactReadiness> forCounterparty(String counterpartyKey) async {
    final json = await _apiClient.getJson(
      '/client/contact-readiness/$counterpartyKey',
      surface: ApiSurface.client,
    );
    return ContactReadiness.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Record a contact the business already knows.
  ///
  /// Returns the server's answer including the recomputed eligibility, so a
  /// surface can show that recording a fact did not make it sendable.
  Future<Map<String, dynamic>> provide({
    required String counterpartyKey,
    required String address,
    String? personName,
    String? role,
    String? sourceNote,
  }) async {
    final json = await _apiClient.postJson(
      '/client/contact-readiness/$counterpartyKey',
      surface: ApiSurface.client,
      body: {
        'address': address.trim(),
        if (personName != null && personName.trim().isNotEmpty)
          'personName': personName.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        if (sourceNote != null && sourceNote.trim().isNotEmpty)
          'sourceNote': sourceNote.trim(),
      },
    );
    return Map<String, dynamic>.from(json as Map);
  }
}

/// Where an address came from, said as what it lets anyone claim.
enum ContactProvenance {
  clientAuthoritative('CLIENT_AUTHORITATIVE', 'You told us'),
  externalDiscovery('EXTERNAL_DISCOVERY', 'A data provider'),
  inferred('INFERRED', 'Constructed from a pattern'),
  unknown('UNKNOWN', 'Origin not recorded');

  const ContactProvenance(this.wire, this.label);
  final String wire;
  final String label;

  static ContactProvenance parse(String? value) {
    for (final p in ContactProvenance.values) {
      if (p.wire == value) return p;
    }
    return ContactProvenance.unknown;
  }
}

/// Whether there is a destination this business may use, and why not.
enum ContactReadinessState {
  noContact('NO_CONTACT', 'No contact'),
  ready('READY', 'Contact ready'),
  needsStrongerEvidence('NEEDS_STRONGER_EVIDENCE', 'Needs a better source'),
  suppressed('SUPPRESSED', 'Must not be contacted'),
  conflicts('CONFLICTS_WITH_COUNTERPARTY', 'Does not look like theirs'),
  belongsToYou('BELONGS_TO_YOU', 'Your own business'),
  ambiguous('AMBIGUOUS', 'Needs your choice'),
  invalid('INVALID', 'Cannot receive mail');

  const ContactReadinessState(this.wire, this.label);
  final String wire;
  final String label;

  static ContactReadinessState parse(String? value) {
    for (final s in ContactReadinessState.values) {
      if (s.wire == value) return s;
    }
    return ContactReadinessState.noContact;
  }

  /// Whether a person can do something about it from here.
  bool get actionable =>
      this == ContactReadinessState.noContact ||
      this == ContactReadinessState.needsStrongerEvidence ||
      this == ContactReadinessState.ambiguous ||
      this == ContactReadinessState.conflicts ||
      this == ContactReadinessState.invalid;

  /// Whether this is settled and nothing should be offered.
  bool get terminal =>
      this == ContactReadinessState.suppressed ||
      this == ContactReadinessState.belongsToYou;
}

class ContactCandidate {
  const ContactCandidate({
    required this.contactId,
    required this.address,
    required this.personName,
    required this.role,
    required this.provenance,
    required this.provenanceSays,
    required this.eligible,
    required this.why,
  });

  final String contactId;
  final String? address;

  /// Null when nobody recorded a name. Never derived from the local part —
  /// `info@` is a role mailbox, not a person called Info.
  final String? personName;
  final String? role;
  final ContactProvenance provenance;
  final String provenanceSays;
  final bool eligible;
  final String? why;

  /// What to call this destination on screen.
  String get displayName => personName ?? role ?? address ?? 'Unknown contact';

  static ContactCandidate fromJson(Map<String, dynamic> j) => ContactCandidate(
        contactId: (j['contactId'] as String?) ?? '',
        address: _text(j['address']),
        personName: _text(j['personName']),
        role: _text(j['role']),
        provenance: ContactProvenance.parse(j['provenance'] as String?),
        provenanceSays: (j['provenanceSays'] as String?) ?? '',
        eligible: j['eligible'] == true,
        why: _text(j['why']),
      );
}

class ContactReadiness {
  const ContactReadiness({
    required this.counterpartyKey,
    required this.state,
    required this.says,
    required this.because,
    required this.selected,
    required this.alternatives,
    required this.canProvideContact,
  });

  final String counterpartyKey;
  final ContactReadinessState state;

  /// The server's own sentence.
  final String says;
  final String because;
  final ContactCandidate? selected;
  final List<ContactCandidate> alternatives;
  final bool canProvideContact;

  static ContactReadiness fromJson(Map<String, dynamic> j) => ContactReadiness(
        counterpartyKey: (j['counterpartyKey'] as String?) ?? '',
        state: ContactReadinessState.parse(j['state'] as String?),
        says: (j['says'] as String?) ?? '',
        because: (j['because'] as String?) ?? '',
        selected: j['selected'] is Map
            ? ContactCandidate.fromJson(Map<String, dynamic>.from(j['selected'] as Map))
            : null,
        alternatives: ((j['alternatives'] as List?) ?? const [])
            .whereType<Map>()
            .map((a) => ContactCandidate.fromJson(Map<String, dynamic>.from(a)))
            .toList(growable: false),
        canProvideContact: j['canProvideContact'] == true,
      );
}

String? _text(Object? value) {
  final s = value?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}
