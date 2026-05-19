// Operator-side typed models mirroring the Self-AI learning rows
// exposed under /operator/learning/*. All operator UI rendering of
// these rows must respect the doctrine:
//   - deterministic > memory > AI ordering in the UI
//   - append-only — no row is ever mutated
//   - accept / reject / activate / rollback create new rows
// See architecture-self-ai-learning + OPERATOR_WORKSPACE_SPECIFICATION.md.

class LearningEventEntry {
  const LearningEventEntry({
    required this.id,
    required this.kind,
    required this.sentiment,
    required this.signal,
    this.clientId,
    this.campaignId,
    required this.observedAt,
    this.factsJson,
  });

  final String id;
  final String kind;
  final String sentiment;
  final String signal;
  final String? clientId;
  final String? campaignId;
  final DateTime observedAt;
  final Map<String, dynamic>? factsJson;

  factory LearningEventEntry.fromJson(Map<String, dynamic> json) {
    return LearningEventEntry(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      sentiment: (json['sentiment'] ?? 'NEUTRAL').toString(),
      signal: (json['signal'] ?? '').toString(),
      clientId: json['clientId']?.toString(),
      campaignId: json['campaignId']?.toString(),
      observedAt: DateTime.tryParse((json['observedAt'] ?? '').toString()) ??
          DateTime.now(),
      factsJson: json['factsJson'] is Map
          ? Map<String, dynamic>.from(json['factsJson'] as Map)
          : null,
    );
  }
}

class OperationalMemoryEntry {
  const OperationalMemoryEntry({
    required this.id,
    required this.scope,
    required this.key,
    required this.lastObservedAt,
    this.valueJson,
    this.clientId,
    this.campaignId,
  });

  final String id;
  final String scope;
  final String key;
  final DateTime lastObservedAt;
  final Map<String, dynamic>? valueJson;
  final String? clientId;
  final String? campaignId;

  factory OperationalMemoryEntry.fromJson(Map<String, dynamic> json) {
    return OperationalMemoryEntry(
      id: (json['id'] ?? '').toString(),
      scope: (json['scope'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      lastObservedAt:
          DateTime.tryParse((json['lastObservedAt'] ?? '').toString()) ??
              DateTime.now(),
      valueJson: json['valueJson'] is Map
          ? Map<String, dynamic>.from(json['valueJson'] as Map)
          : null,
      clientId: json['clientId']?.toString(),
      campaignId: json['campaignId']?.toString(),
    );
  }
}

class RuntimePatternEntry {
  const RuntimePatternEntry({
    required this.id,
    required this.label,
    required this.signal,
    required this.scope,
    required this.status,
    required this.sentiment,
    required this.occurrences,
    required this.windowSeconds,
    required this.firstObservedAt,
    required this.lastObservedAt,
    this.clientId,
    this.campaignId,
    this.evidenceJson,
  });

  final String id;
  final String label;
  final String signal;
  final String scope;
  final String status;
  final String sentiment;
  final int occurrences;
  final int windowSeconds;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final String? clientId;
  final String? campaignId;
  final Map<String, dynamic>? evidenceJson;

  factory RuntimePatternEntry.fromJson(Map<String, dynamic> json) {
    return RuntimePatternEntry(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      signal: (json['signal'] ?? '').toString(),
      scope: (json['scope'] ?? '').toString(),
      status: (json['status'] ?? 'CANDIDATE').toString(),
      sentiment: (json['sentiment'] ?? 'NEUTRAL').toString(),
      occurrences: _asInt(json['occurrences']),
      windowSeconds: _asInt(json['windowSeconds']),
      firstObservedAt: _asDate(json['firstObservedAt']),
      lastObservedAt: _asDate(json['lastObservedAt']),
      clientId: json['clientId']?.toString(),
      campaignId: json['campaignId']?.toString(),
      evidenceJson: json['evidenceJson'] is Map
          ? Map<String, dynamic>.from(json['evidenceJson'] as Map)
          : null,
    );
  }
}

class PolicySuggestionEntry {
  const PolicySuggestionEntry({
    required this.id,
    required this.proposalTitle,
    required this.proposalRationale,
    required this.category,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.rejectedAt,
    this.appliedAt,
    this.notes,
    this.proposalJson,
    this.clientId,
    this.campaignId,
    this.sourcePatternId,
  });

  final String id;
  final String proposalTitle;
  final String proposalRationale;
  final String category;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? appliedAt;
  final String? notes;
  final Map<String, dynamic>? proposalJson;
  final String? clientId;
  final String? campaignId;
  final String? sourcePatternId;

  factory PolicySuggestionEntry.fromJson(Map<String, dynamic> json) {
    return PolicySuggestionEntry(
      id: (json['id'] ?? '').toString(),
      proposalTitle: (json['proposalTitle'] ?? '').toString(),
      proposalRationale: (json['proposalRationale'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      status: (json['status'] ?? 'PROPOSED').toString(),
      createdAt: _asDate(json['createdAt']),
      acceptedAt: json['acceptedAt'] == null ? null : _asDate(json['acceptedAt']),
      rejectedAt: json['rejectedAt'] == null ? null : _asDate(json['rejectedAt']),
      appliedAt: json['appliedAt'] == null ? null : _asDate(json['appliedAt']),
      notes: json['notes']?.toString(),
      proposalJson: json['proposalJson'] is Map
          ? Map<String, dynamic>.from(json['proposalJson'] as Map)
          : null,
      clientId: json['clientId']?.toString(),
      campaignId: json['campaignId']?.toString(),
      sourcePatternId: json['sourcePatternId']?.toString(),
    );
  }
}

class CostGuardrailEntry {
  const CostGuardrailEntry({
    required this.id,
    required this.scope,
    required this.kind,
    required this.threshold,
    required this.windowSeconds,
    required this.warningRatio,
    required this.isActive,
    required this.breachCount,
    this.scopeId,
    this.lastBreachAt,
    required this.updatedAt,
  });

  final String id;
  final String scope;
  final String kind;
  final double threshold;
  final int windowSeconds;
  final double warningRatio;
  final bool isActive;
  final int breachCount;
  final String? scopeId;
  final DateTime? lastBreachAt;
  final DateTime updatedAt;

  factory CostGuardrailEntry.fromJson(Map<String, dynamic> json) {
    return CostGuardrailEntry(
      id: (json['id'] ?? '').toString(),
      scope: (json['scope'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      threshold: _asDouble(json['threshold']),
      windowSeconds: _asInt(json['windowSeconds']),
      warningRatio: _asDouble(json['warningRatio']),
      isActive: json['isActive'] != false,
      breachCount: _asInt(json['breachCount']),
      scopeId: json['scopeId']?.toString(),
      lastBreachAt:
          json['lastBreachAt'] == null ? null : _asDate(json['lastBreachAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }
}

class SelfHealingEntry {
  const SelfHealingEntry({
    required this.id,
    required this.kind,
    required this.status,
    required this.reason,
    required this.appliedAt,
    this.revertedAt,
    this.clientId,
    this.campaignId,
    this.mailboxId,
    this.actionJson,
    this.resultJson,
    this.suggestionId,
  });

  final String id;
  final String kind;
  final String status;
  final String reason;
  final DateTime appliedAt;
  final DateTime? revertedAt;
  final String? clientId;
  final String? campaignId;
  final String? mailboxId;
  final Map<String, dynamic>? actionJson;
  final Map<String, dynamic>? resultJson;
  final String? suggestionId;

  factory SelfHealingEntry.fromJson(Map<String, dynamic> json) {
    return SelfHealingEntry(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      status: (json['status'] ?? 'APPLIED').toString(),
      reason: (json['reason'] ?? '').toString(),
      appliedAt: _asDate(json['appliedAt']),
      revertedAt:
          json['revertedAt'] == null ? null : _asDate(json['revertedAt']),
      clientId: json['clientId']?.toString(),
      campaignId: json['campaignId']?.toString(),
      mailboxId: json['mailboxId']?.toString(),
      actionJson: json['actionJson'] is Map
          ? Map<String, dynamic>.from(json['actionJson'] as Map)
          : null,
      resultJson: json['resultJson'] is Map
          ? Map<String, dynamic>.from(json['resultJson'] as Map)
          : null,
      suggestionId: json['suggestionId']?.toString(),
    );
  }
}

class PlaybookEntry {
  const PlaybookEntry({
    required this.id,
    required this.playbookKey,
    required this.name,
    required this.scopeType,
    required this.status,
    required this.automationLevel,
    required this.confidenceScore,
    required this.updatedAt,
    this.description,
    this.organizationId,
  });

  final String id;
  final String playbookKey;
  final String name;
  final String scopeType;
  final String status;
  final String automationLevel;
  final double confidenceScore;
  final DateTime updatedAt;
  final String? description;
  final String? organizationId;

  factory PlaybookEntry.fromJson(Map<String, dynamic> json) {
    return PlaybookEntry(
      id: (json['id'] ?? '').toString(),
      playbookKey: (json['playbookKey'] ?? '').toString(),
      name: (json['name'] ?? json['playbookKey'] ?? '').toString(),
      scopeType: (json['scopeType'] ?? 'GLOBAL').toString(),
      status: (json['status'] ?? 'CANDIDATE').toString(),
      automationLevel: (json['automationLevel'] ?? 'LEVEL_0').toString(),
      confidenceScore: _asDouble(json['confidenceScore']),
      updatedAt: _asDate(json['updatedAt']),
      description: json['description']?.toString(),
      organizationId: json['organizationId']?.toString(),
    );
  }
}

class PlaybookExecutionEntry {
  const PlaybookExecutionEntry({
    required this.id,
    required this.playbookId,
    required this.outcome,
    required this.evaluatedAt,
    this.matchedFactsJson,
    this.executedActionsJson,
    this.resultRefType,
    this.resultRefId,
    this.errorMessage,
    this.rolledBackAt,
    this.rolledBackReason,
    this.latencyMs,
  });

  final String id;
  final String playbookId;
  final String outcome;
  final DateTime evaluatedAt;
  final Map<String, dynamic>? matchedFactsJson;
  final Map<String, dynamic>? executedActionsJson;
  final String? resultRefType;
  final String? resultRefId;
  final String? errorMessage;
  final DateTime? rolledBackAt;
  final String? rolledBackReason;
  final int? latencyMs;

  factory PlaybookExecutionEntry.fromJson(Map<String, dynamic> json) {
    return PlaybookExecutionEntry(
      id: (json['id'] ?? '').toString(),
      playbookId: (json['playbookId'] ?? '').toString(),
      outcome: (json['outcome'] ?? '').toString(),
      evaluatedAt: _asDate(json['evaluatedAt']),
      matchedFactsJson: json['matchedFactsJson'] is Map
          ? Map<String, dynamic>.from(json['matchedFactsJson'] as Map)
          : null,
      executedActionsJson: json['executedActionsJson'] is Map
          ? Map<String, dynamic>.from(json['executedActionsJson'] as Map)
          : null,
      resultRefType: json['resultRefType']?.toString(),
      resultRefId: json['resultRefId']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
      rolledBackAt:
          json['rolledBackAt'] == null ? null : _asDate(json['rolledBackAt']),
      rolledBackReason: json['rolledBackReason']?.toString(),
      latencyMs: json['latencyMs'] == null ? null : _asInt(json['latencyMs']),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  helpers
// ──────────────────────────────────────────────────────────────

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

DateTime _asDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
