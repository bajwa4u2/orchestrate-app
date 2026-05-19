import 'package:orchestrate_app/core/network/api_client.dart';
import '../models/convergence_models.dart';
import '../models/learning_models.dart';

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
