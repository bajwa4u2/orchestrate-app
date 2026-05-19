import 'package:orchestrate_app/core/network/api_client.dart';
import '../models/cognition_models.dart';

/// Single read-only touchpoint for the operator cognition surface.
/// Hits the additive endpoints documented in
/// OPERATOR_WORKSPACE_SPECIFICATION.md §9.
class OperatorCognitionRepository {
  OperatorCognitionRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<CognitionHome> fetchHome() async {
    final json = await _api.getJson(
      '/operator/cognition/home',
      surface: ApiSurface.operator,
    );
    return CognitionHome.fromJson(_asMap(json));
  }

  Future<ReadinessBoard> fetchReadinessBoard() async {
    final json = await _api.getJson(
      '/operator/readiness/board',
      surface: ApiSurface.operator,
    );
    return ReadinessBoard.fromJson(_asMap(json));
  }

  Future<ContinuityHealth> fetchContinuitySummary() async {
    final json = await _api.getJson(
      '/operator/continuity/summary',
      surface: ApiSurface.operator,
    );
    return ContinuityHealth.fromJson(_asMap(json));
  }

  Future<List<BlockedWorkRow>> fetchBlockedWork({
    String? category,
    int? limit,
  }) async {
    final query = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (limit != null) 'limit': '$limit',
    };
    final json = await _api.getJson(
      '/operator/continuity/blocked',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => BlockedWorkRow.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<TruthHighlights> fetchRuntimeTruth() async {
    final json = await _api.getJson(
      '/operator/runtime-truth/overview',
      surface: ApiSurface.operator,
    );
    return TruthHighlights.fromJson(_asMap(json));
  }

  Future<List<AuditEvent>> fetchAuditEvents({
    String? action,
    String? entityType,
    String? actorUserId,
    int? limit,
    String? cursor,
  }) async {
    final query = <String, String>{
      if (action != null && action.isNotEmpty) 'action': action,
      if (entityType != null && entityType.isNotEmpty)
        'entityType': entityType,
      if (actorUserId != null && actorUserId.isNotEmpty)
        'actorUserId': actorUserId,
      if (limit != null) 'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final json = await _api.getJson(
      '/operator/audit/events',
      query: query.isEmpty ? null : query,
      surface: ApiSurface.operator,
    );
    return _asList(json)
        .whereType<Map>()
        .map((m) => AuditEvent.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
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
