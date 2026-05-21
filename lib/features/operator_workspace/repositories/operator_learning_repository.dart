import 'package:orchestrate_app/core/network/api_client.dart';
import '../models/campaign_lifecycle_models.dart';
import '../models/convergence_models.dart';
import '../models/discovery_models.dart';
import '../models/learning_models.dart';
import '../models/runtime_truth_models.dart';

/// Operator-only touchpoint for the Self-AI learning substrate
/// (LearningEvent / OperationalMemory / RuntimePattern /
/// PolicyAdjustmentSuggestion / CostGuardrail / SelfHealingAction
/// + OperationalPlaybook + PlaybookExecution).
///
/// All endpoints already exist under /operator/learning/* and are
/// operator-auth gated. Mutating endpoints accept / reject / activate
/// / disable / archive / rollback. UI never edits learning rows
/// directly; every change is a new audit row.
class OperatorLearningRepository {
  OperatorLearningRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<LearningEventEntry>> listEvents({
    String? kind,
    String? sentiment,
    String? clientId,
    String? campaignId,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/events',
      query: _query({
        'kind': kind,
        'sentiment': sentiment,
        'clientId': clientId,
        'campaignId': campaignId,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => LearningEventEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<List<OperationalMemoryEntry>> listMemory({
    String? scope,
    String? key,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/memory',
      query: _query({
        'scope': scope,
        'key': key,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) =>
            OperationalMemoryEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<List<RuntimePatternEntry>> listPatterns({
    String? status,
    String? clientId,
    String? campaignId,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/patterns',
      query: _query({
        'status': status,
        'clientId': clientId,
        'campaignId': campaignId,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => RuntimePatternEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<List<PolicySuggestionEntry>> listSuggestions({
    String? status,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/suggestions',
      query: _query({
        'status': status,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) =>
            PolicySuggestionEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<PolicySuggestionEntry> acceptSuggestion({
    required String id,
    String? notes,
  }) async {
    final json = await _api.postJson(
      '/operator/learning/suggestions/$id/accept',
      body: <String, dynamic>{
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      surface: ApiSurface.operator,
    );
    return PolicySuggestionEntry.fromJson(_asMap(json));
  }

  Future<PolicySuggestionEntry> rejectSuggestion({
    required String id,
    String? notes,
  }) async {
    final json = await _api.postJson(
      '/operator/learning/suggestions/$id/reject',
      body: <String, dynamic>{
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      surface: ApiSurface.operator,
    );
    return PolicySuggestionEntry.fromJson(_asMap(json));
  }

  Future<List<CostGuardrailEntry>> listGuardrails() async {
    final json = await _api.getJson(
      '/operator/learning/guardrails',
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => CostGuardrailEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<CostGuardrailEntry> upsertGuardrail({
    required String scope,
    String? scopeId,
    required String kind,
    required double threshold,
    required int windowSeconds,
    double? warningRatio,
    bool? isActive,
  }) async {
    final json = await _api.postJson(
      '/operator/learning/guardrails',
      body: <String, dynamic>{
        'scope': scope,
        if (scopeId != null && scopeId.isNotEmpty) 'scopeId': scopeId,
        'kind': kind,
        'threshold': threshold,
        'windowSeconds': windowSeconds,
        if (warningRatio != null) 'warningRatio': warningRatio,
        if (isActive != null) 'isActive': isActive,
      },
      surface: ApiSurface.operator,
    );
    return CostGuardrailEntry.fromJson(_asMap(json));
  }

  Future<List<SelfHealingEntry>> listHealingActions({
    String? clientId,
    String? campaignId,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/healing-actions',
      query: _query({
        'clientId': clientId,
        'campaignId': campaignId,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => SelfHealingEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<List<PlaybookEntry>> listPlaybooks({
    String? status,
    String? scopeType,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/playbooks',
      query: _query({
        'status': status,
        'scopeType': scopeType,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => PlaybookEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<List<PlaybookExecutionEntry>> listPlaybookExecutions({
    required String playbookId,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/playbooks/$playbookId/executions',
      query: _query({'limit': limit?.toString()}),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) =>
            PlaybookExecutionEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<PlaybookEntry> activatePlaybook({
    required String id,
    required String automationLevel,
    String? notes,
  }) async {
    final json = await _api.postJson(
      '/operator/learning/playbooks/$id/activate',
      body: <String, dynamic>{
        'automationLevel': automationLevel,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      surface: ApiSurface.operator,
    );
    return PlaybookEntry.fromJson(_asMap(json));
  }

  Future<PlaybookEntry> disablePlaybook({
    required String id,
    String? notes,
  }) async {
    final json = await _api.postJson(
      '/operator/learning/playbooks/$id/disable',
      body: <String, dynamic>{
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      surface: ApiSurface.operator,
    );
    return PlaybookEntry.fromJson(_asMap(json));
  }

  Future<PlaybookEntry> archivePlaybook({required String id}) async {
    final json = await _api.postJson(
      '/operator/learning/playbooks/$id/archive',
      body: const <String, dynamic>{},
      surface: ApiSurface.operator,
    );
    return PlaybookEntry.fromJson(_asMap(json));
  }

  Future<PlaybookExecutionEntry> rollbackExecution({
    required String executionId,
    required String reason,
  }) async {
    final json = await _api.postJson(
      '/operator/learning/playbooks/executions/$executionId/rollback',
      body: <String, dynamic>{'reason': reason},
      surface: ApiSurface.operator,
    );
    return PlaybookExecutionEntry.fromJson(_asMap(json));
  }

  // ──────────────────────────────────────────────────────────────
  //  Convergence layer
  // ──────────────────────────────────────────────────────────────

  Future<ConvergenceSnapshot> fetchConvergenceMetrics({
    int? windowSeconds,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/convergence-metrics',
      query: _query({'windowSeconds': windowSeconds?.toString()}),
      surface: ApiSurface.operator,
    );
    return ConvergenceSnapshot.fromJson(_asMap(json));
  }

  Future<AiEconomy> fetchAiEconomy({int? windowSeconds}) async {
    final json = await _api.getJson(
      '/operator/learning/ai-economy',
      query: _query({'windowSeconds': windowSeconds?.toString()}),
      surface: ApiSurface.operator,
    );
    return AiEconomy.fromJson(_asMap(json));
  }

  Future<List<ReasoningCacheEntry>> listReasoningCache({
    String? source,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/reasoning-cache',
      query: _query({
        'source': source,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => ReasoningCacheEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<void> invalidateReasoningCacheEntry({required String id}) async {
    await _api.postJson(
      '/operator/learning/reasoning-cache/$id/invalidate',
      body: const <String, dynamic>{},
      surface: ApiSurface.operator,
    );
  }

  Future<List<EscalationEntry>> listEscalations({
    String? reason,
    String? severity,
    bool? onlyOpen,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/operator/learning/escalations',
      query: _query({
        'reason': reason,
        'severity': severity,
        'onlyOpen': onlyOpen == true ? 'true' : null,
        'limit': limit?.toString(),
      }),
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => EscalationEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  // ──────────────────────────────────────────────────────────────
  //  Canonical runtime-truth faculty
  // ──────────────────────────────────────────────────────────────

  /// Per-action AI invocation budgets + the deterministic-vs-AI
  /// economy from the stabilization layer.
  Future<RuntimeBudgetSnapshot> fetchRuntimeBudgets() async {
    final json = await _api.getJson(
      '/operator/runtime-truth/budgets',
      surface: ApiSurface.operator,
    );
    return RuntimeBudgetSnapshot.fromJson(_asMap(json));
  }

  /// Deterministic green-path verdict + canonical truth for an
  /// action, client, and campaign.
  Future<GreenPathView> fetchGreenPath({
    String? clientId,
    String? campaignId,
    String? action,
  }) async {
    final json = await _api.getJson(
      '/operator/runtime-truth/green-path',
      query: _query({
        'clientId': clientId,
        'campaignId': campaignId,
        'action': action,
      }),
      surface: ApiSurface.operator,
    );
    return GreenPathView.fromJson(_asMap(json));
  }

  /// The single canonical runtime-truth object for a client / campaign.
  Future<CanonicalTruthView> fetchCanonicalTruth({
    String? clientId,
    String? campaignId,
  }) async {
    final json = await _api.getJson(
      '/operator/runtime-truth/canonical',
      query: _query({'clientId': clientId, 'campaignId': campaignId}),
      surface: ApiSurface.operator,
    );
    return CanonicalTruthView.fromJson(_asMap(json));
  }

  // ──────────────────────────────────────────────────────────────
  //  Market intelligence / signal acquisition
  // ──────────────────────────────────────────────────────────────

  /// Discovery source coverage + per-source health / acquisition
  /// telemetry. A `campaignId` additionally returns that campaign's
  /// reply-learning source down-rank per source.
  Future<DiscoverySourcesView> fetchDiscoverySources({
    String? campaignId,
  }) async {
    final json = await _api.getJson(
      '/operator/discovery/sources',
      query: _query({'campaignId': campaignId}),
      surface: ApiSurface.operator,
    );
    return DiscoverySourcesView.fromJson(_asMap(json));
  }

  /// Executable-inventory quality — counts by lifecycle state +
  /// freshness distribution.
  Future<DiscoveryInventoryView> fetchDiscoveryInventory() async {
    final json = await _api.getJson(
      '/operator/discovery/inventory',
      surface: ApiSurface.operator,
    );
    return DiscoveryInventoryView.fromJson(_asMap(json));
  }

  /// Canonical campaign-lifecycle truth — every real campaign with
  /// its lifecycle / discovery / continuity state. Same Campaign
  /// source the client workspace reads, so the operator never sees a
  /// split-brain "0 campaigns" while the client has a live operation.
  Future<OperatorCampaignLifecycleView> fetchCampaignLifecycle() async {
    final json = await _api.getJson(
      '/campaigns/lifecycle',
      surface: ApiSurface.operator,
    );
    return OperatorCampaignLifecycleView.fromJson(_asMap(json));
  }

  /// Autonomous discovery-refill runtime truth for a campaign — the
  /// governor decision and the stage-by-stage trace of the last run.
  Future<DiscoveryRefillView> fetchDiscoveryRefill({
    required String campaignId,
  }) async {
    final json = await _api.getJson(
      '/operator/discovery/refill',
      query: {'campaignId': campaignId},
      surface: ApiSurface.operator,
    );
    return DiscoveryRefillView.fromJson(_asMap(json));
  }

  Map<String, String>? _query(Map<String, String?> input) {
    final filtered = <String, String>{};
    input.forEach((k, v) {
      if (v != null && v.isNotEmpty) filtered[k] = v;
    });
    return filtered.isEmpty ? null : filtered;
  }
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, vv) => MapEntry('$k', vv));
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic v) {
  if (v is List) return v;
  return const <dynamic>[];
}
