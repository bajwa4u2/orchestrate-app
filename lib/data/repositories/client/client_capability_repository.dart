import '../../../core/network/api_client.dart';

/// WHAT THIS ORGANISATION MAY DO, AND WHY NOT.
///
/// Every judgement comes from the server. There is deliberately no plan matrix
/// here: a client that decides for itself what a plan permits is a second
/// commercial authority, and the one the customer is looking at will be the
/// wrong one. This types the answer and adds nothing.
class ClientCapabilityRepository {
  ClientCapabilityRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<CapabilityProjection> fetch() async {
    final json = await _apiClient.getJson(
      '/client/capabilities',
      surface: ApiSurface.client,
    );
    return CapabilityProjection.fromJson(Map<String, dynamic>.from(json as Map));
  }
}

/// Where an organisation's right to operate comes from.
///
/// A grant is not a purchase, and none of these except a paid subscription is a
/// customer. Kept explicit so no surface can quietly present granted access as
/// commercial traction.
enum EntitlementSource {
  paid('PAID_SUBSCRIPTION', 'Active subscription'),
  internal('INTERNAL_OPERATIONAL', 'Internal operational access'),
  storeReview('STORE_REVIEW', 'App-store review access'),
  legacyGrant('LEGACY_GRANTED_ACCESS', 'Access granted by Orchestrate'),
  none('NONE', 'No plan active');

  const EntitlementSource(this.wire, this.label);
  final String wire;
  final String label;

  static EntitlementSource parse(String? value) {
    for (final s in EntitlementSource.values) {
      if (s.wire == value) return s;
    }
    return EntitlementSource.none;
  }
}

/// What the organisation may currently operate.
///
/// `lapsed` is deliberately not `none`. A business that operated Orchestrate
/// and stopped paying keeps everything it built; one that never activated has
/// nothing to keep, and the two need different sentences.
enum EntitlementState {
  none('NONE'),
  active('ACTIVE'),
  lapsed('LAPSED'),
  paymentIssue('PAYMENT_ISSUE');

  const EntitlementState(this.wire);
  final String wire;

  static EntitlementState parse(String? value) {
    for (final s in EntitlementState.values) {
      if (s.wire == value) return s;
    }
    return EntitlementState.none;
  }

  /// Whether the organisation is operating right now, however it got there.
  bool get operating => this == active || this == paymentIssue;
}

class Entitlement {
  const Entitlement({
    required this.state,
    required this.source,
    required this.says,
    required this.because,
    required this.isPayingCustomer,
  });

  final EntitlementState state;
  final EntitlementSource source;

  /// The server's own sentence.
  final String says;
  final String because;
  final bool isPayingCustomer;

  static Entitlement fromJson(Map<String, dynamic> j) => Entitlement(
        state: EntitlementState.parse(j['state'] as String?),
        source: EntitlementSource.parse(j['source'] as String?),
        says: (j['says'] as String?) ?? '',
        because: (j['because'] as String?) ?? '',
        isPayingCustomer: j['isPayingCustomer'] == true,
      );
}

class CapabilityVerdict {
  const CapabilityVerdict({
    required this.capability,
    required this.permitted,
    required this.code,
    required this.why,
    required this.resolution,
  });

  final String capability;
  final bool permitted;

  /// `PLAN_ACTIVATION_REQUIRED` or `EXECUTION_SERVICE_NOT_ACTIVATED`. Never an
  /// authority code and never a destination code — those are different
  /// boundaries with different answers.
  final String? code;
  final String? why;
  final String? resolution;

  static CapabilityVerdict fromJson(Map<String, dynamic> j) => CapabilityVerdict(
        capability: (j['capability'] as String?) ?? '',
        permitted: j['permitted'] == true,
        code: _text(j['code']),
        why: _text(j['why']),
        resolution: _text(j['resolution']),
      );
}

class CapabilityProjection {
  const CapabilityProjection({
    required this.entitlement,
    required this.capabilities,
    required this.model,
    required this.note,
  });

  final Entitlement entitlement;
  final List<CapabilityVerdict> capabilities;

  /// What Orchestrate sells, as shape rather than as a price list.
  final List<({String dimension, String means})> model;
  final String note;

  CapabilityVerdict? forCapability(String capability) {
    for (final c in capabilities) {
      if (c.capability == capability) return c;
    }
    return null;
  }

  bool may(String capability) => forCapability(capability)?.permitted ?? false;

  static CapabilityProjection fromJson(Map<String, dynamic> j) => CapabilityProjection(
        entitlement: Entitlement.fromJson(
            Map<String, dynamic>.from((j['entitlement'] as Map?) ?? const {})),
        capabilities: ((j['capabilities'] as List?) ?? const [])
            .whereType<Map>()
            .map((c) => CapabilityVerdict.fromJson(Map<String, dynamic>.from(c)))
            .toList(growable: false),
        model: ((j['model'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => (
                  dimension: (m['dimension'] as String?) ?? '',
                  means: (m['means'] as String?) ?? '',
                ))
            .toList(growable: false),
        note: (j['note'] as String?) ?? '',
      );
}

String? _text(Object? value) {
  final s = value?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}
