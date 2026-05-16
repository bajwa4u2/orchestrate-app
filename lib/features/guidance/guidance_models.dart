// Typed contracts for guidance replies that mirror the backend
// GuidanceReply / GuidanceContext shapes. The frontend never
// constructs a reply itself — replies always come from the backend
// guidance endpoints. These models exist so the rendered surface
// stays type-safe and the four-question contract stays visible.

class GuidanceNextStep {
  const GuidanceNextStep({
    required this.label,
    required this.ownership,
    this.route,
    this.blocking = false,
  });

  final String label;
  final String ownership;
  final String? route;
  final bool blocking;

  factory GuidanceNextStep.fromJson(Map<String, dynamic> json) {
    return GuidanceNextStep(
      label: (json['label'] ?? '').toString(),
      ownership: (json['ownership'] ?? 'informational').toString(),
      route: json['route']?.toString(),
      blocking: json['blocking'] == true,
    );
  }
}

class GuidanceRef {
  const GuidanceRef({required this.kind, required this.detail});

  final String kind;
  final String detail;

  factory GuidanceRef.fromJson(Map<String, dynamic> json) {
    return GuidanceRef(
      kind: (json['kind'] ?? 'unknown').toString(),
      detail: (json['detail'] ?? '').toString(),
    );
  }

  /// Human-readable label for the source. Templates above this layer
  /// must never invent claims; the ref label declares where this reply
  /// came from so the user can verify.
  String get sourceLabel {
    switch (kind) {
      case 'readiness-engine':
        return 'Readiness engine';
      case 'sending-identity':
        return 'Sending identity';
      case 'sending-identity-history':
        return 'Sending identity history';
      case 'mailbox':
        return 'Mailbox';
      case 'dispatch-governance':
        return 'Dispatch governance';
      case 'audit-log':
        return 'Audit log';
      case 'doctrine':
        return 'Platform doctrine';
      case 'package-fit-rules':
        return 'Package-fit rules';
      default:
        return kind;
    }
  }
}

class GuidanceReply {
  const GuidanceReply({
    required this.intent,
    required this.templateName,
    required this.title,
    required this.body,
    required this.whatChangesIt,
    required this.ownership,
    required this.refs,
    this.nextStep,
    this.auditEventId,
  });

  /// Stable identifier shared with the backend. Used by feedback +
  /// unsafe-response reporting.
  final String intent;

  /// Versioned template name (e.g. readiness.sending_identity.v1).
  /// Surfaced subtly in the refs panel so QA can find the template.
  final String templateName;

  /// One-sentence headline naming the current operational state.
  final String title;

  /// Why the user is in this state (one or two sentences).
  final String body;

  /// Who owns the next step + when it will change.
  final String whatChangesIt;

  /// Ownership tag: 'client' | 'orchestrate' | 'operator' | 'informational'.
  final String ownership;

  /// Backend subsystems the reply was grounded in.
  final List<GuidanceRef> refs;

  /// Single, named next step. Null when the assistant explicitly
  /// declares no action is required.
  final GuidanceNextStep? nextStep;

  /// Backend audit-event id for this reply. Used to submit feedback
  /// or report an inaccurate / unsafe response.
  final String? auditEventId;

  factory GuidanceReply.fromJson(Map<String, dynamic> json) {
    return GuidanceReply(
      intent: (json['intent'] ?? 'unknown').toString(),
      templateName: (json['templateName'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      whatChangesIt: (json['whatChangesIt'] ?? '').toString(),
      ownership: (json['ownership'] ?? 'informational').toString(),
      refs: (json['refs'] is List)
          ? (json['refs'] as List)
              .whereType<Map>()
              .map((m) => GuidanceRef.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false)
          : const <GuidanceRef>[],
      nextStep: json['nextStep'] is Map
          ? GuidanceNextStep.fromJson(
              Map<String, dynamic>.from(json['nextStep'] as Map))
          : null,
      auditEventId: json['auditEventId']?.toString(),
    );
  }
}

class GuidanceContextSnapshot {
  const GuidanceContextSnapshot({
    required this.mode,
    this.surface,
    this.scope,
    this.tier,
    this.setupComplete,
    this.subscriptionStatus,
    this.representationAuthorized,
    this.readinessBucket,
    this.readinessHeadline,
    this.readinessBlockerCode,
    this.mailboxConnectionState,
    this.sendingDomainStatus,
  });

  final String mode;
  final String? surface;
  final String? scope;
  final String? tier;
  final bool? setupComplete;
  final String? subscriptionStatus;
  final bool? representationAuthorized;
  final String? readinessBucket;
  final String? readinessHeadline;
  final String? readinessBlockerCode;
  final String? mailboxConnectionState;
  final String? sendingDomainStatus;

  factory GuidanceContextSnapshot.fromJson(Map<String, dynamic> json) {
    final readiness = json['readiness'] is Map
        ? Map<String, dynamic>.from(json['readiness'] as Map)
        : null;
    final mailbox = json['mailbox'] is Map
        ? Map<String, dynamic>.from(json['mailbox'] as Map)
        : null;
    final sendingIdentity = json['sendingIdentity'] is Map
        ? Map<String, dynamic>.from(json['sendingIdentity'] as Map)
        : null;
    return GuidanceContextSnapshot(
      mode: (json['mode'] ?? 'client').toString(),
      surface: json['surface']?.toString(),
      scope: json['scope']?.toString(),
      tier: json['tier']?.toString(),
      setupComplete: json['setupComplete'] as bool?,
      subscriptionStatus: json['subscriptionStatus']?.toString(),
      representationAuthorized: json['representationAuthorized'] as bool?,
      readinessBucket: readiness?['readinessBucket']?.toString(),
      readinessHeadline: readiness?['headline']?.toString(),
      readinessBlockerCode: readiness?['underlyingBlockerCode']?.toString(),
      mailboxConnectionState: mailbox?['connectionState']?.toString(),
      sendingDomainStatus: sendingIdentity?['status']?.toString(),
    );
  }
}
