// Typed models for the operator cognition surface. Mirror the
// payloads returned by /operator/cognition/home,
// /operator/readiness/board, /operator/continuity/*,
// /operator/runtime-truth/overview, /operator/audit/events.
//
// Doctrine: OPERATOR_WORKSPACE_SPECIFICATION.md §5, §9.
// All numbers, labels, and timestamps come from the backend.
// The UI never invents state.

class TrustRibbon {
  const TrustRibbon({
    required this.vaultAdapter,
    required this.vaultWarning,
    required this.providersHealthy,
    required this.providersTotal,
    required this.dnsVerified,
    required this.dnsTotal,
    required this.oauthReauthRequired,
  });

  final String vaultAdapter;
  final bool vaultWarning;
  final int providersHealthy;
  final int providersTotal;
  final int dnsVerified;
  final int dnsTotal;
  final int oauthReauthRequired;

  factory TrustRibbon.fromJson(Map<String, dynamic> json) {
    final vault = _asMap(json['vault']);
    final providers = _asMap(json['providers']);
    final dns = _asMap(json['dns']);
    return TrustRibbon(
      vaultAdapter: (vault['adapter'] ?? 'unknown').toString(),
      vaultWarning: vault['warning'] == true,
      providersHealthy: _asInt(providers['healthy']),
      providersTotal: _asInt(providers['total']),
      dnsVerified: _asInt(dns['verified']),
      dnsTotal: _asInt(dns['total']),
      oauthReauthRequired: _asInt(json['oauthReauthRequired']),
    );
  }
}

class CognitionFeedItem {
  const CognitionFeedItem({
    required this.kind,
    required this.severity,
    required this.faculty,
    required this.sourceId,
    required this.title,
    required this.summary,
    required this.facultyRoute,
    required this.observedAt,
    this.actionLabel,
    this.actionEndpoint,
  });

  final String kind;
  final String severity; // 'attention' | 'info'
  final String faculty;
  final String sourceId;
  final String title;
  final String summary;
  final String facultyRoute;
  final DateTime observedAt;
  final String? actionLabel;
  final String? actionEndpoint;

  factory CognitionFeedItem.fromJson(Map<String, dynamic> json) {
    final action =
        json['action'] is Map ? _asMap(json['action']) : <String, dynamic>{};
    return CognitionFeedItem(
      kind: (json['kind'] ?? 'info').toString(),
      severity: (json['severity'] ?? 'info').toString(),
      faculty: (json['faculty'] ?? 'cognition').toString(),
      sourceId: (json['sourceId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      facultyRoute: (json['facultyRoute'] ?? '/ops/overview').toString(),
      observedAt: DateTime.tryParse((json['observedAt'] ?? '').toString()) ??
          DateTime.now(),
      actionLabel: action['label']?.toString(),
      actionEndpoint: action['endpoint']?.toString(),
    );
  }
}

class ContinuityHealth {
  const ContinuityHealth({
    required this.inFlight,
    required this.blockedTotal,
    required this.blockedByReason,
    required this.sentLastHour,
    required this.failedLastHour,
    required this.jobsPending,
    required this.jobsFailed,
    required this.recoveringActionsLast24h,
  });

  final int inFlight;
  final int blockedTotal;
  final Map<String, int> blockedByReason;
  final int sentLastHour;
  final int failedLastHour;
  final int jobsPending;
  final int jobsFailed;
  final int recoveringActionsLast24h;

  factory ContinuityHealth.fromJson(Map<String, dynamic> json) {
    final by = json['blockedByReason'] is Map
        ? _asMap(json['blockedByReason'])
        : <String, dynamic>{};
    final reasons = <String, int>{};
    by.forEach((k, v) => reasons[k.toString()] = _asInt(v));
    return ContinuityHealth(
      inFlight: _asInt(json['inFlight']),
      blockedTotal: _asInt(json['blockedTotal']),
      blockedByReason: reasons,
      sentLastHour: _asInt(json['sentLastHour']),
      failedLastHour: _asInt(json['failedLastHour']),
      jobsPending: _asInt(json['jobsPending']),
      jobsFailed: _asInt(json['jobsFailed']),
      recoveringActionsLast24h: _asInt(json['recoveringActionsLast24h']),
    );
  }
}

class TruthHighlights {
  const TruthHighlights({
    required this.providers,
    required this.mailboxes,
    required this.sendingDomains,
    required this.deliverabilityBouncesLast24h,
    required this.deliverabilityComplaintsLast24h,
  });

  final List<TruthProviderRow> providers;
  final TruthMailboxes mailboxes;
  final TruthSendingDomains sendingDomains;
  final int? deliverabilityBouncesLast24h;
  final int? deliverabilityComplaintsLast24h;

  factory TruthHighlights.fromJson(Map<String, dynamic> json) {
    final deliverability = json['deliverability'] is Map
        ? _asMap(json['deliverability'])
        : <String, dynamic>{};
    return TruthHighlights(
      providers: (json['providers'] is List)
          ? (json['providers'] as List)
              .whereType<Map>()
              .map((m) =>
                  TruthProviderRow.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false)
          : const [],
      mailboxes: TruthMailboxes.fromJson(_asMap(json['mailboxes'])),
      sendingDomains:
          TruthSendingDomains.fromJson(_asMap(json['sendingDomains'])),
      deliverabilityBouncesLast24h: deliverability['bouncesLast24h'] == null
          ? null
          : _asInt(deliverability['bouncesLast24h']),
      deliverabilityComplaintsLast24h:
          deliverability['complaintsLast24h'] == null
              ? null
              : _asInt(deliverability['complaintsLast24h']),
    );
  }
}

class TruthProviderRow {
  const TruthProviderRow({
    required this.name,
    required this.total,
    required this.healthy,
    required this.degraded,
    required this.critical,
  });

  final String name;
  final int total;
  final int healthy;
  final int degraded;
  final int critical;

  factory TruthProviderRow.fromJson(Map<String, dynamic> json) {
    return TruthProviderRow(
      name: (json['name'] ?? 'UNKNOWN').toString(),
      total: _asInt(json['total']),
      healthy: _asInt(json['healthy']),
      degraded: _asInt(json['degraded']),
      critical: _asInt(json['critical']),
    );
  }
}

class TruthMailboxes {
  const TruthMailboxes({
    required this.total,
    required this.healthy,
    required this.degraded,
    required this.critical,
    required this.requiresReauth,
    required this.items,
  });

  final int total;
  final int healthy;
  final int degraded;
  final int critical;
  final int requiresReauth;
  final List<TruthMailboxItem> items;

  factory TruthMailboxes.fromJson(Map<String, dynamic> json) {
    return TruthMailboxes(
      total: _asInt(json['total']),
      healthy: _asInt(json['healthy']),
      degraded: _asInt(json['degraded']),
      critical: _asInt(json['critical']),
      requiresReauth: _asInt(json['requiresReauth']),
      items: (json['items'] is List)
          ? (json['items'] as List)
              .whereType<Map>()
              .map((m) =>
                  TruthMailboxItem.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false)
          : const [],
    );
  }
}

class TruthMailboxItem {
  const TruthMailboxItem({
    required this.id,
    required this.provider,
    required this.emailAddress,
    required this.connectionState,
    required this.healthStatus,
    this.lastSyncedAt,
    this.lastAuthAt,
    this.lastRefreshAt,
  });

  final String id;
  final String provider;
  final String emailAddress;
  final String connectionState;
  final String healthStatus;
  final String? lastSyncedAt;
  final String? lastAuthAt;
  final String? lastRefreshAt;

  factory TruthMailboxItem.fromJson(Map<String, dynamic> json) {
    return TruthMailboxItem(
      id: (json['id'] ?? '').toString(),
      provider: (json['provider'] ?? 'UNKNOWN').toString(),
      emailAddress: (json['emailAddress'] ?? '').toString(),
      connectionState:
          (json['connectionState'] ?? 'UNKNOWN').toString(),
      healthStatus: (json['healthStatus'] ?? 'UNKNOWN').toString(),
      lastSyncedAt: json['lastSyncedAt']?.toString(),
      lastAuthAt: json['lastAuthAt']?.toString(),
      lastRefreshAt: json['lastRefreshAt']?.toString(),
    );
  }
}

class TruthSendingDomains {
  const TruthSendingDomains({
    required this.total,
    required this.active,
    required this.pending,
    required this.blocked,
    required this.paused,
    required this.items,
  });

  final int total;
  final int active;
  final int pending;
  final int blocked;
  final int paused;
  final List<TruthSendingDomainItem> items;

  factory TruthSendingDomains.fromJson(Map<String, dynamic> json) {
    return TruthSendingDomains(
      total: _asInt(json['total']),
      active: _asInt(json['active']),
      pending: _asInt(json['pending']),
      blocked: _asInt(json['blocked']),
      paused: _asInt(json['paused']),
      items: (json['items'] is List)
          ? (json['items'] as List)
              .whereType<Map>()
              .map((m) => TruthSendingDomainItem.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList(growable: false)
          : const [],
    );
  }
}

class TruthSendingDomainItem {
  const TruthSendingDomainItem({
    required this.id,
    required this.domain,
    required this.status,
    this.lastCheckedAt,
    this.dnsVerifiedAt,
    this.failedReason,
  });

  final String id;
  final String domain;
  final String status;
  final String? lastCheckedAt;
  final String? dnsVerifiedAt;
  final String? failedReason;

  factory TruthSendingDomainItem.fromJson(Map<String, dynamic> json) {
    return TruthSendingDomainItem(
      id: (json['id'] ?? '').toString(),
      domain: (json['domain'] ?? '').toString(),
      status: (json['status'] ?? 'UNKNOWN').toString(),
      lastCheckedAt: json['lastCheckedAt']?.toString(),
      dnsVerifiedAt: json['dnsVerifiedAt']?.toString(),
      failedReason: json['failedReason']?.toString(),
    );
  }
}

class ActiveAdaptations {
  const ActiveAdaptations({
    required this.playbooksFiredToday,
    required this.suggestionsPending,
    required this.guardrailsArmed,
    required this.healingToday,
  });

  final int playbooksFiredToday;
  final int suggestionsPending;
  final int guardrailsArmed;
  final int healingToday;

  factory ActiveAdaptations.fromJson(Map<String, dynamic> json) {
    return ActiveAdaptations(
      playbooksFiredToday: _asInt(json['playbooksFiredToday']),
      suggestionsPending: _asInt(json['suggestionsPending']),
      guardrailsArmed: _asInt(json['guardrailsArmed']),
      healingToday: _asInt(json['healingToday']),
    );
  }
}

class OperatorActivityEntry {
  const OperatorActivityEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.actorId,
    this.actorDisplayName,
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final DateTime createdAt;
  final String? actorId;
  final String? actorDisplayName;

  factory OperatorActivityEntry.fromJson(Map<String, dynamic> json) {
    final actor =
        json['actor'] is Map ? _asMap(json['actor']) : <String, dynamic>{};
    return OperatorActivityEntry(
      id: (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      entityType: (json['entityType'] ?? '').toString(),
      entityId: (json['entityId'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      actorId: actor['id']?.toString(),
      actorDisplayName: actor['displayName']?.toString(),
    );
  }
}

class ReadinessBoard {
  const ReadinessBoard({
    required this.asOf,
    required this.totals,
    required this.rows,
  });

  final DateTime asOf;
  final Map<String, int> totals;
  final List<ReadinessBoardRow> rows;

  factory ReadinessBoard.fromJson(Map<String, dynamic> json) {
    final totalsRaw =
        json['totals'] is Map ? _asMap(json['totals']) : <String, dynamic>{};
    final totals = <String, int>{};
    totalsRaw.forEach((k, v) => totals[k.toString()] = _asInt(v));
    return ReadinessBoard(
      asOf: DateTime.tryParse((json['asOf'] ?? '').toString()) ??
          DateTime.now(),
      totals: totals,
      rows: (json['rows'] is List)
          ? (json['rows'] as List)
              .whereType<Map>()
              .map((m) =>
                  ReadinessBoardRow.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false)
          : const [],
    );
  }
}

class ReadinessBoardRow {
  const ReadinessBoardRow({
    required this.clientId,
    required this.displayName,
    required this.readinessBucket,
    required this.executionState,
    required this.title,
    required this.detail,
    this.nextAction,
  });

  final String clientId;
  final String displayName;
  final String readinessBucket;
  final String executionState;
  final String title;
  final String detail;
  final String? nextAction;

  factory ReadinessBoardRow.fromJson(Map<String, dynamic> json) {
    return ReadinessBoardRow(
      clientId: (json['clientId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      readinessBucket: (json['readinessBucket'] ?? 'unknown').toString(),
      executionState: (json['executionState'] ?? 'UNKNOWN').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      nextAction: json['nextAction']?.toString(),
    );
  }
}

class CognitionHome {
  const CognitionHome({
    required this.asOf,
    required this.trustRibbon,
    required this.attentionTotal,
    required this.attentionByFaculty,
    required this.readinessTotals,
    required this.feed,
    required this.continuityHealth,
    required this.truthHighlights,
    required this.activeAdaptations,
    required this.recentOperatorActivity,
  });

  final DateTime asOf;
  final TrustRibbon trustRibbon;
  final int attentionTotal;
  final Map<String, int> attentionByFaculty;
  final Map<String, int> readinessTotals;
  final List<CognitionFeedItem> feed;
  final ContinuityHealth continuityHealth;
  final TruthHighlights truthHighlights;
  final ActiveAdaptations activeAdaptations;
  final List<OperatorActivityEntry> recentOperatorActivity;

  factory CognitionHome.fromJson(Map<String, dynamic> json) {
    final attention = _asMap(json['attention']);
    final byFacultyRaw = attention['byFaculty'] is Map
        ? _asMap(attention['byFaculty'])
        : <String, dynamic>{};
    final byFaculty = <String, int>{};
    byFacultyRaw.forEach((k, v) => byFaculty[k.toString()] = _asInt(v));

    final readinessRaw = json['readinessTotals'] is Map
        ? _asMap(json['readinessTotals'])
        : <String, dynamic>{};
    final readiness = <String, int>{};
    readinessRaw.forEach((k, v) => readiness[k.toString()] = _asInt(v));

    return CognitionHome(
      asOf: DateTime.tryParse((json['asOf'] ?? '').toString()) ??
          DateTime.now(),
      trustRibbon: TrustRibbon.fromJson(_asMap(json['trustRibbon'])),
      attentionTotal: _asInt(attention['totalCount']),
      attentionByFaculty: byFaculty,
      readinessTotals: readiness,
      feed: (json['feed'] is List)
          ? (json['feed'] as List)
              .whereType<Map>()
              .map((m) =>
                  CognitionFeedItem.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false)
          : const [],
      continuityHealth: ContinuityHealth.fromJson(
        json['continuityHealth'] is Map
            ? _asMap(json['continuityHealth'])
            : <String, dynamic>{},
      ),
      truthHighlights: TruthHighlights.fromJson(
        json['truthHighlights'] is Map
            ? _asMap(json['truthHighlights'])
            : <String, dynamic>{},
      ),
      activeAdaptations: ActiveAdaptations.fromJson(
        json['activeAdaptations'] is Map
            ? _asMap(json['activeAdaptations'])
            : <String, dynamic>{},
      ),
      recentOperatorActivity:
          (json['recentOperatorActivity'] is List)
              ? (json['recentOperatorActivity'] as List)
                  .whereType<Map>()
                  .map((m) => OperatorActivityEntry.fromJson(
                      Map<String, dynamic>.from(m)))
                  .toList(growable: false)
              : const [],
    );
  }
}

class BlockedWorkRow {
  const BlockedWorkRow({
    required this.id,
    required this.clientId,
    required this.campaignId,
    required this.mailboxId,
    required this.status,
    required this.subjectLine,
    required this.errorMessage,
    required this.errorCategory,
    this.failedAt,
    required this.createdAt,
  });

  final String id;
  final String? clientId;
  final String? campaignId;
  final String? mailboxId;
  final String status;
  final String subjectLine;
  final String? errorMessage;
  final String errorCategory;
  final String? failedAt;
  final String createdAt;

  factory BlockedWorkRow.fromJson(Map<String, dynamic> json) {
    return BlockedWorkRow(
      id: (json['id'] ?? '').toString(),
      clientId: json['clientId']?.toString(),
      campaignId: json['campaignId']?.toString(),
      mailboxId: json['mailboxId']?.toString(),
      status: (json['status'] ?? '').toString(),
      subjectLine: (json['subjectLine'] ?? '').toString(),
      errorMessage: json['errorMessage']?.toString(),
      errorCategory: (json['errorCategory'] ?? 'UNCLASSIFIED').toString(),
      failedAt: json['failedAt']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.actorId,
    this.actorDisplayName,
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final DateTime createdAt;
  final String? actorId;
  final String? actorDisplayName;

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    final actor =
        json['actor'] is Map ? _asMap(json['actor']) : <String, dynamic>{};
    return AuditEvent(
      id: (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      entityType: (json['entityType'] ?? '').toString(),
      entityId: (json['entityId'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      actorId: actor['id']?.toString(),
      actorDisplayName:
          actor['displayName']?.toString() ?? actor['fullName']?.toString(),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  helpers
// ──────────────────────────────────────────────────────────────

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', v));
  return <String, dynamic>{};
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
