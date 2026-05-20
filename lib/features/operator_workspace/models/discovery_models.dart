// Operator-side typed models for the market-intelligence /
// signal-acquisition layer. Mirror /operator/discovery/sources and
// /operator/discovery/inventory. Operator-only — clients never see
// source internals.

class DiscoverySourcesView {
  const DiscoverySourcesView({
    required this.asOf,
    required this.configuredCount,
    required this.totalCount,
    required this.sources,
    required this.stats,
  });

  final DateTime asOf;
  final int configuredCount;
  final int totalCount;
  final List<DiscoverySourceRow> sources;
  final List<DiscoverySourceStat> stats;

  DiscoverySourceStat? statFor(String kind) {
    for (final s in stats) {
      if (s.kind == kind) return s;
    }
    return null;
  }

  factory DiscoverySourcesView.fromJson(Map<String, dynamic> json) {
    return DiscoverySourcesView(
      asOf: _date(json['asOf']),
      configuredCount: _int(json['configuredCount']),
      totalCount: _int(json['totalCount']),
      sources: _list(json['sources'])
          .whereType<Map>()
          .map((m) => DiscoverySourceRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      stats: _list(json['stats'])
          .whereType<Map>()
          .map((m) => DiscoverySourceStat.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}

class DiscoverySourceRow {
  const DiscoverySourceRow({
    required this.kind,
    required this.displayName,
    required this.role,
    required this.paid,
    required this.configured,
    required this.requiresConfig,
    required this.description,
  });

  final String kind;
  final String displayName;
  final String role;
  final bool paid;
  final bool configured;
  final List<String> requiresConfig;
  final String description;

  factory DiscoverySourceRow.fromJson(Map<String, dynamic> json) {
    return DiscoverySourceRow(
      kind: (json['kind'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['kind'] ?? '').toString(),
      role: (json['role'] ?? 'discovery').toString(),
      paid: json['paid'] == true,
      configured: json['configured'] == true,
      requiresConfig: _list(json['requiresConfig'])
          .map((e) => e.toString())
          .toList(growable: false),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class DiscoverySourceStat {
  const DiscoverySourceStat({
    required this.kind,
    required this.runs,
    required this.candidatesAcquired,
    required this.throttledRuns,
    required this.cacheHits,
    required this.errors,
    required this.lastError,
    required this.lastRunAtIso,
  });

  final String kind;
  final int runs;
  final int candidatesAcquired;
  final int throttledRuns;
  final int cacheHits;
  final int errors;
  final String? lastError;
  final String? lastRunAtIso;

  factory DiscoverySourceStat.fromJson(Map<String, dynamic> json) {
    return DiscoverySourceStat(
      kind: (json['kind'] ?? '').toString(),
      runs: _int(json['runs']),
      candidatesAcquired: _int(json['candidatesAcquired']),
      throttledRuns: _int(json['throttledRuns']),
      cacheHits: _int(json['cacheHits']),
      errors: _int(json['errors']),
      lastError: json['lastError']?.toString(),
      lastRunAtIso: json['lastRunAtIso']?.toString(),
    );
  }
}

class DiscoveryInventoryView {
  const DiscoveryInventoryView({
    required this.asOf,
    required this.total,
    required this.byState,
    required this.executableInventory,
    required this.fresh,
    required this.aging,
    required this.stale,
  });

  final DateTime asOf;
  final int total;
  final Map<String, int> byState;
  final int executableInventory;
  final int fresh;
  final int aging;
  final int stale;

  factory DiscoveryInventoryView.fromJson(Map<String, dynamic> json) {
    final byStateRaw = json['byState'] is Map
        ? Map<String, dynamic>.from(json['byState'] as Map)
        : <String, dynamic>{};
    final byState = <String, int>{};
    byStateRaw.forEach((k, v) => byState[k.toString()] = _int(v));
    final freshness = json['freshness'] is Map
        ? Map<String, dynamic>.from(json['freshness'] as Map)
        : <String, dynamic>{};
    return DiscoveryInventoryView(
      asOf: _date(json['asOf']),
      total: _int(json['total']),
      byState: byState,
      executableInventory: _int(json['executableInventory']),
      fresh: _int(freshness['fresh']),
      aging: _int(freshness['aging']),
      stale: _int(freshness['stale']),
    );
  }
}

/// Autonomous discovery-refill runtime truth for one campaign.
class DiscoveryRefillView {
  const DiscoveryRefillView({
    required this.campaignId,
    required this.campaignStatus,
    required this.decision,
    required this.trace,
    required this.recordedAt,
    required this.profile,
  });

  final String campaignId;
  final String? campaignStatus;
  final DiscoveryRefillDecisionView? decision;
  final DiscoveryRefillTraceView? trace;
  final String? recordedAt;
  final DiscoveryProfileStateView? profile;

  factory DiscoveryRefillView.fromJson(Map<String, dynamic> json) {
    final decisionRaw = json['decision'];
    final traceRaw = json['lastTrace'];
    final profileRaw = json['profile'];
    return DiscoveryRefillView(
      campaignId: (json['campaignId'] ?? '').toString(),
      campaignStatus: json['campaignStatus']?.toString(),
      decision: decisionRaw is Map
          ? DiscoveryRefillDecisionView.fromJson(
              Map<String, dynamic>.from(decisionRaw))
          : null,
      trace: traceRaw is Map
          ? DiscoveryRefillTraceView.fromJson(
              Map<String, dynamic>.from(traceRaw))
          : null,
      recordedAt: json['recordedAt']?.toString(),
      profile: profileRaw is Map
          ? DiscoveryProfileStateView.fromJson(
              Map<String, dynamic>.from(profileRaw))
          : null,
    );
  }
}

/// Discovery profile lifecycle — the explicit truth that discovery
/// is no longer paused by default.
class DiscoveryProfileStateView {
  const DiscoveryProfileStateView({
    required this.status,
    required this.enabled,
    required this.lastRunAt,
    required this.nextRunAt,
  });

  final String status;
  final bool enabled;
  final String? lastRunAt;
  final String? nextRunAt;

  factory DiscoveryProfileStateView.fromJson(Map<String, dynamic> json) {
    return DiscoveryProfileStateView(
      status: (json['status'] ?? '').toString(),
      enabled: json['enabled'] == true,
      lastRunAt: json['lastRunAt']?.toString(),
      nextRunAt: json['nextRunAt']?.toString(),
    );
  }
}

class DiscoveryRefillDecisionView {
  const DiscoveryRefillDecisionView({
    required this.activate,
    required this.reason,
    required this.detail,
    required this.decisionMode,
    required this.minimumRefillGuarantee,
    required this.overrodeAdvisoryHold,
    required this.executableInventory,
    required this.threshold,
  });

  final bool activate;
  final String reason;
  final String detail;
  final String decisionMode;
  final bool minimumRefillGuarantee;
  final bool overrodeAdvisoryHold;
  final int executableInventory;
  final int threshold;

  factory DiscoveryRefillDecisionView.fromJson(Map<String, dynamic> json) {
    return DiscoveryRefillDecisionView(
      activate: json['activate'] == true,
      reason: (json['reason'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      decisionMode: (json['decisionMode'] ?? 'deterministic').toString(),
      minimumRefillGuarantee: json['minimumRefillGuarantee'] == true,
      overrodeAdvisoryHold: json['overrodeAdvisoryHold'] == true,
      executableInventory: _int(json['executableInventory']),
      threshold: _int(json['threshold']),
    );
  }
}

class DiscoveryRefillTraceView {
  const DiscoveryRefillTraceView({
    required this.acquired,
    required this.beforeDedupe,
    required this.afterDedupe,
    required this.suppressed,
    required this.eligible,
    required this.ineligible,
    required this.promotedToInventory,
    required this.connectors,
  });

  final int acquired;
  final int beforeDedupe;
  final int afterDedupe;
  final int suppressed;
  final int eligible;
  final int ineligible;
  final int promotedToInventory;
  final List<DiscoveryTraceConnector> connectors;

  factory DiscoveryRefillTraceView.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> stage(String key) => json[key] is Map
        ? Map<String, dynamic>.from(json[key] as Map)
        : <String, dynamic>{};
    final dedupe = stage('dedupeSuppression');
    final eligibility = stage('qualificationEligibility');
    return DiscoveryRefillTraceView(
      acquired: _int(stage('candidateNormalization')['acquired']),
      beforeDedupe: _int(dedupe['beforeDedupe']),
      afterDedupe: _int(dedupe['afterDedupe']),
      suppressed: _int(dedupe['suppressed']),
      eligible: _int(eligibility['eligible']),
      ineligible: _int(eligibility['ineligible']),
      promotedToInventory:
          _int(stage('executablePromotion')['promotedToInventory']),
      connectors: _list(json['connectorExecution'])
          .whereType<Map>()
          .map((m) =>
              DiscoveryTraceConnector.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}

class DiscoveryTraceConnector {
  const DiscoveryTraceConnector({
    required this.kind,
    required this.configured,
    required this.candidates,
    required this.throttled,
    required this.error,
  });

  final String kind;
  final bool configured;
  final int candidates;
  final bool throttled;
  final String? error;

  factory DiscoveryTraceConnector.fromJson(Map<String, dynamic> json) {
    return DiscoveryTraceConnector(
      kind: (json['kind'] ?? '').toString(),
      configured: json['configured'] == true,
      candidates: _int(json['candidates']),
      throttled: json['throttled'] == true,
      error: json['error']?.toString(),
    );
  }
}

// helpers
List<dynamic> _list(dynamic v) => v is List ? v : const <dynamic>[];

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime _date(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
