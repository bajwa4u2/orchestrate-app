// Operator-side typed models for the Self-AI convergence layer.
// Mirror /operator/learning/convergence-metrics,
// /operator/learning/ai-economy, /operator/learning/reasoning-cache,
// /operator/learning/escalations.

class ConvergenceSnapshot {
  const ConvergenceSnapshot({
    required this.asOf,
    required this.windowSeconds,
    required this.processStats,
    required this.reuse,
    required this.patterns,
    required this.suggestions,
    required this.healing,
    required this.playbookOutcomes,
    required this.escalationsByReason,
    required this.greenPath,
  });

  final DateTime asOf;
  final int windowSeconds;
  final Map<String, dynamic> processStats;
  final ConvergenceReuse reuse;
  final ConvergencePatterns patterns;
  final ConvergenceSuggestions suggestions;
  final ConvergenceHealing healing;
  final Map<String, int> playbookOutcomes;
  final Map<String, int> escalationsByReason;
  final GreenPathEconomy greenPath;

  factory ConvergenceSnapshot.fromJson(Map<String, dynamic> json) {
    final playbookOutcomesRaw = json['playbooks'] is Map
        ? _asMap(_asMap(json['playbooks'])['outcomesInWindow'])
        : <String, dynamic>{};
    final escByReasonRaw =
        _asMap(json['escalationsByReason'] ?? <String, dynamic>{});
    final outcomes = <String, int>{};
    playbookOutcomesRaw.forEach((k, v) => outcomes[k.toString()] = _asInt(v));
    final byReason = <String, int>{};
    escByReasonRaw.forEach((k, v) => byReason[k.toString()] = _asInt(v));
    return ConvergenceSnapshot(
      asOf: _asDate(json['asOf']),
      windowSeconds: _asInt(json['windowSeconds']),
      processStats: _asMap(json['processStats']),
      reuse: ConvergenceReuse.fromJson(_asMap(json['reuse'])),
      patterns: ConvergencePatterns.fromJson(_asMap(json['patterns'])),
      suggestions:
          ConvergenceSuggestions.fromJson(_asMap(json['suggestions'])),
      healing: ConvergenceHealing.fromJson(_asMap(json['healing'])),
      playbookOutcomes: outcomes,
      escalationsByReason: byReason,
      greenPath: GreenPathEconomy.fromJson(_asMap(json['greenPath'])),
    );
  }
}

/// Deterministic-vs-AI execution share — how much of execution is now
/// deterministic infrastructure behaviour versus genuine AI authority
/// invocation.
class GreenPathEconomy {
  const GreenPathEconomy({
    required this.authorityAiCalls,
    required this.authorityShortCircuits,
    required this.authorityDurableCacheHits,
    required this.continuityGreenPathReuse,
    required this.continuityGreenPathMint,
    required this.continuityAiAuthority,
    required this.convergencePromotions,
    required this.deterministicExecutions,
    required this.aiExecutions,
    required this.deterministicBypassRate,
  });

  final int authorityAiCalls;
  final int authorityShortCircuits;
  final int authorityDurableCacheHits;
  final int continuityGreenPathReuse;
  final int continuityGreenPathMint;
  final int continuityAiAuthority;
  final int convergencePromotions;
  final int deterministicExecutions;
  final int aiExecutions;
  final double deterministicBypassRate;

  factory GreenPathEconomy.fromJson(Map<String, dynamic> json) {
    return GreenPathEconomy(
      authorityAiCalls: _asInt(json['authorityAiCalls']),
      authorityShortCircuits: _asInt(json['authorityShortCircuits']),
      authorityDurableCacheHits: _asInt(json['authorityDurableCacheHits']),
      continuityGreenPathReuse: _asInt(json['continuityGreenPathReuse']),
      continuityGreenPathMint: _asInt(json['continuityGreenPathMint']),
      continuityAiAuthority: _asInt(json['continuityAiAuthority']),
      convergencePromotions: _asInt(json['convergencePromotions']),
      deterministicExecutions: _asInt(json['deterministicExecutions']),
      aiExecutions: _asInt(json['aiExecutions']),
      deterministicBypassRate: _asDouble(json['deterministicBypassRate']),
    );
  }
}

class ConvergenceReuse {
  const ConvergenceReuse({
    required this.reuseEventsInWindow,
    required this.escalationsInWindow,
    required this.escalationsTotal,
    required this.escalationsResolved,
    required this.reuseRate,
    required this.escalationRate,
    required this.cacheRows,
    required this.cacheHitsInWindow,
    required this.promptTokensInCachedDecisions,
    required this.completionTokensInCachedDecisions,
  });

  final int reuseEventsInWindow;
  final int escalationsInWindow;
  final int escalationsTotal;
  final int escalationsResolved;
  final double reuseRate;
  final double escalationRate;
  final int cacheRows;
  final int cacheHitsInWindow;
  final int promptTokensInCachedDecisions;
  final int completionTokensInCachedDecisions;

  factory ConvergenceReuse.fromJson(Map<String, dynamic> json) {
    return ConvergenceReuse(
      reuseEventsInWindow: _asInt(json['reuseEventsInWindow']),
      escalationsInWindow: _asInt(json['escalationsInWindow']),
      escalationsTotal: _asInt(json['escalationsTotal']),
      escalationsResolved: _asInt(json['escalationsResolved']),
      reuseRate: _asDouble(json['reuseRate']),
      escalationRate: _asDouble(json['escalationRate']),
      cacheRows: _asInt(json['cacheRows']),
      cacheHitsInWindow: _asInt(json['cacheHitsInWindow']),
      promptTokensInCachedDecisions:
          _asInt(json['promptTokensInCachedDecisions']),
      completionTokensInCachedDecisions:
          _asInt(json['completionTokensInCachedDecisions']),
    );
  }
}

class ConvergencePatterns {
  const ConvergencePatterns({required this.confirmed, required this.candidate});
  final int confirmed;
  final int candidate;
  factory ConvergencePatterns.fromJson(Map<String, dynamic> json) =>
      ConvergencePatterns(
        confirmed: _asInt(json['confirmed']),
        candidate: _asInt(json['candidate']),
      );
}

class ConvergenceSuggestions {
  const ConvergenceSuggestions({
    required this.pending,
    required this.accepted,
    required this.rejected,
  });
  final int pending;
  final int accepted;
  final int rejected;
  factory ConvergenceSuggestions.fromJson(Map<String, dynamic> json) =>
      ConvergenceSuggestions(
        pending: _asInt(json['pending']),
        accepted: _asInt(json['accepted']),
        rejected: _asInt(json['rejected']),
      );
}

class ConvergenceHealing {
  const ConvergenceHealing({
    required this.appliedInWindow,
    required this.revertedInWindow,
    this.recoverySuccessRate,
  });
  final int appliedInWindow;
  final int revertedInWindow;
  final double? recoverySuccessRate;
  factory ConvergenceHealing.fromJson(Map<String, dynamic> json) =>
      ConvergenceHealing(
        appliedInWindow: _asInt(json['appliedInWindow']),
        revertedInWindow: _asInt(json['revertedInWindow']),
        recoverySuccessRate: json['recoverySuccessRate'] == null
            ? null
            : _asDouble(json['recoverySuccessRate']),
      );
}

class AiEconomy {
  const AiEconomy({
    required this.asOf,
    required this.windowSeconds,
    required this.cacheBySource,
    required this.cacheByModel,
    required this.guardrails,
    required this.breachesInWindow,
  });

  final DateTime asOf;
  final int windowSeconds;
  final List<AiEconomyRow> cacheBySource;
  final List<AiEconomyRow> cacheByModel;
  final List<AiEconomyGuardrail> guardrails;
  final int breachesInWindow;

  factory AiEconomy.fromJson(Map<String, dynamic> json) {
    return AiEconomy(
      asOf: _asDate(json['asOf']),
      windowSeconds: _asInt(json['windowSeconds']),
      cacheBySource: _asList(json['cacheBySource'])
          .whereType<Map>()
          .map((m) => AiEconomyRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      cacheByModel: _asList(json['cacheByModel'])
          .whereType<Map>()
          .map((m) => AiEconomyRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      guardrails: _asList(json['guardrails'])
          .whereType<Map>()
          .map((m) => AiEconomyGuardrail.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      breachesInWindow: _asInt(json['breachesInWindow']),
    );
  }
}

class AiEconomyRow {
  const AiEconomyRow({
    required this.label,
    required this.rows,
    required this.hits,
    required this.promptTokens,
    required this.completionTokens,
  });

  final String label;
  final int rows;
  final int hits;
  final int promptTokens;
  final int completionTokens;

  factory AiEconomyRow.fromJson(Map<String, dynamic> json) {
    return AiEconomyRow(
      label: (json['source'] ?? json['modelKey'] ?? 'unknown').toString(),
      rows: _asInt(json['rows']),
      hits: _asInt(json['hits']),
      promptTokens: _asInt(json['promptTokens']),
      completionTokens: _asInt(json['completionTokens']),
    );
  }
}

class AiEconomyGuardrail {
  const AiEconomyGuardrail({
    required this.id,
    required this.kind,
    required this.scope,
    required this.threshold,
    required this.windowSeconds,
    required this.breachCount,
    this.lastBreachAt,
  });

  final String id;
  final String kind;
  final String scope;
  final double threshold;
  final int windowSeconds;
  final int breachCount;
  final DateTime? lastBreachAt;

  factory AiEconomyGuardrail.fromJson(Map<String, dynamic> json) {
    return AiEconomyGuardrail(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      scope: (json['scope'] ?? '').toString(),
      threshold: _asDouble(json['threshold']),
      windowSeconds: _asInt(json['windowSeconds']),
      breachCount: _asInt(json['breachCount']),
      lastBreachAt: json['lastBreachAt'] == null
          ? null
          : _asDate(json['lastBreachAt']),
    );
  }
}

class ReasoningCacheEntry {
  const ReasoningCacheEntry({
    required this.id,
    required this.fingerprint,
    required this.source,
    required this.modelKey,
    required this.summary,
    required this.hits,
    required this.promptTokens,
    required this.completionTokens,
    required this.expiresAt,
    required this.updatedAt,
    this.lastHitAt,
    this.estimatedCostUsd,
    this.decisionJson,
  });

  final String id;
  final String fingerprint;
  final String source;
  final String? modelKey;
  final String? summary;
  final int hits;
  final int promptTokens;
  final int completionTokens;
  final DateTime expiresAt;
  final DateTime updatedAt;
  final DateTime? lastHitAt;
  final double? estimatedCostUsd;
  final Map<String, dynamic>? decisionJson;

  factory ReasoningCacheEntry.fromJson(Map<String, dynamic> json) {
    return ReasoningCacheEntry(
      id: (json['id'] ?? '').toString(),
      fingerprint: (json['fingerprint'] ?? '').toString(),
      source: (json['source'] ?? 'OTHER').toString(),
      modelKey: json['modelKey']?.toString(),
      summary: json['summary']?.toString(),
      hits: _asInt(json['hits']),
      promptTokens: _asInt(json['promptTokens']),
      completionTokens: _asInt(json['completionTokens']),
      expiresAt: _asDate(json['expiresAt']),
      updatedAt: _asDate(json['updatedAt']),
      lastHitAt:
          json['lastHitAt'] == null ? null : _asDate(json['lastHitAt']),
      estimatedCostUsd: json['estimatedCostUsd'] == null
          ? null
          : _asDouble(json['estimatedCostUsd']),
      decisionJson: json['decisionJson'] is Map
          ? Map<String, dynamic>.from(json['decisionJson'] as Map)
          : null,
    );
  }
}

class EscalationEntry {
  const EscalationEntry({
    required this.id,
    required this.fingerprint,
    required this.reason,
    required this.severity,
    required this.triggeredAt,
    this.resolvedAt,
    this.resolutionRefType,
    this.resolutionRefId,
    this.sourceEventId,
    this.contextJson,
    this.clientId,
    this.campaignId,
  });

  final String id;
  final String fingerprint;
  final String reason;
  final String severity;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? resolutionRefType;
  final String? resolutionRefId;
  final String? sourceEventId;
  final Map<String, dynamic>? contextJson;
  final String? clientId;
  final String? campaignId;

  factory EscalationEntry.fromJson(Map<String, dynamic> json) {
    return EscalationEntry(
      id: (json['id'] ?? '').toString(),
      fingerprint: (json['fingerprint'] ?? '').toString(),
      reason: (json['reason'] ?? 'NOVELTY').toString(),
      severity: (json['severity'] ?? 'MEDIUM').toString(),
      triggeredAt: _asDate(json['triggeredAt']),
      resolvedAt:
          json['resolvedAt'] == null ? null : _asDate(json['resolvedAt']),
      resolutionRefType: json['resolutionRefType']?.toString(),
      resolutionRefId: json['resolutionRefId']?.toString(),
      sourceEventId: json['sourceEventId']?.toString(),
      contextJson: json['contextJson'] is Map
          ? Map<String, dynamic>.from(json['contextJson'] as Map)
          : null,
      clientId: json['clientId']?.toString(),
      campaignId: json['campaignId']?.toString(),
    );
  }
}

// helpers
Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, vv) => MapEntry('$k', vv));
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic v) {
  if (v is List) return v;
  return const <dynamic>[];
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

DateTime _asDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
