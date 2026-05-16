import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'guidance_models.dart';

/// Single touch-point for the Phase 1 guidance + explainability API.
/// Read-only. Never sends operational mutations. Every call hits a
/// versioned backend endpoint that returns a typed GuidanceReply.
class GuidanceRepository {
  GuidanceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // ──────────────────────────────────────────────────────────────────
  // Client-mode (authenticated)
  // ──────────────────────────────────────────────────────────────────

  Future<GuidanceContextSnapshot> fetchClientContext({String? surface}) async {
    final json = await _apiClient.getJson(
      '/client/guidance/context',
      query: surface == null ? null : <String, String>{'surface': surface},
      surface: ApiSurface.client,
    );
    return GuidanceContextSnapshot.fromJson(_asMap(json));
  }

  Future<GuidanceReply> explainReadiness({String? surface}) async {
    final json = await _apiClient.getJson(
      '/client/guidance/readiness',
      query: surface == null ? null : <String, String>{'surface': surface},
      surface: ApiSurface.client,
    );
    return GuidanceReply.fromJson(_asMap(json));
  }

  Future<GuidanceReply> explainExecutionState({
    required String kind,
    String? surface,
  }) async {
    final json = await _apiClient.getJson(
      '/client/guidance/execution-state',
      query: <String, String>{
        'kind': kind,
        if (surface != null) 'surface': surface,
      },
      surface: ApiSurface.client,
    );
    return GuidanceReply.fromJson(_asMap(json));
  }

  Future<GuidanceReply> explainSendingIdentity({String? surface}) async {
    final json = await _apiClient.getJson(
      '/client/guidance/sending-identity',
      query: surface == null ? null : <String, String>{'surface': surface},
      surface: ApiSurface.client,
    );
    return GuidanceReply.fromJson(_asMap(json));
  }

  Future<GuidanceReply> explainDispatchGovernance({String? surface}) async {
    final json = await _apiClient.getJson(
      '/client/guidance/dispatch-governance',
      query: surface == null ? null : <String, String>{'surface': surface},
      surface: ApiSurface.client,
    );
    return GuidanceReply.fromJson(_asMap(json));
  }

  Future<void> submitFeedback({
    required String auditEventId,
    required String rating,
    String? note,
  }) async {
    await _apiClient.postJson(
      '/client/guidance/feedback',
      body: <String, dynamic>{
        'auditEventId': auditEventId,
        'rating': rating,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      surface: ApiSurface.client,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Public (visitor) endpoints — no auth required
  // ──────────────────────────────────────────────────────────────────

  Future<GuidanceContextSnapshot> fetchVisitorContext({
    String? surface,
    String? sessionId,
  }) async {
    final json = await _apiClient.getJson(
      '/public/guidance/context',
      query: <String, String>{
        if (surface != null) 'surface': surface,
        if (sessionId != null) 'sessionId': sessionId,
      },
      surface: ApiSurface.public,
    );
    return GuidanceContextSnapshot.fromJson(_asMap(json));
  }

  Future<GuidanceReply> recommendPackageFit({
    bool? needsRevenueContinuity,
    int? countries,
    int? regions,
    int? metros,
    bool? excludeOrInclude,
    bool? ownedMailbox,
    bool? ownedSendingDomain,
    String? notesHint,
    String? surface,
    String? sessionId,
  }) async {
    final body = <String, dynamic>{
      if (needsRevenueContinuity != null)
        'needsRevenueContinuity': needsRevenueContinuity,
      if (countries != null) 'countries': countries,
      if (regions != null) 'regions': regions,
      if (metros != null) 'metros': metros,
      if (excludeOrInclude != null) 'excludeOrInclude': excludeOrInclude,
      if (ownedMailbox != null) 'ownedMailbox': ownedMailbox,
      if (ownedSendingDomain != null) 'ownedSendingDomain': ownedSendingDomain,
      if (notesHint != null) 'notesHint': notesHint,
      if (surface != null) 'surface': surface,
      if (sessionId != null) 'sessionId': sessionId,
    };
    final json = await _apiClient.postJson(
      '/public/guidance/package-fit',
      body: body,
      surface: ApiSurface.public,
    );
    return GuidanceReply.fromJson(_asMap(json));
  }

  /// Open / public: anyone can flag an inaccurate or unsafe response.
  Future<String?> reportUnsafeResponse({
    String? auditEventId,
    String? surface,
    required String reason,
    String? detail,
    String? reporterEmail,
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/guidance/report',
        body: <String, dynamic>{
          if (auditEventId != null) 'auditEventId': auditEventId,
          if (surface != null) 'surface': surface,
          'reason': reason,
          if (detail != null) 'detail': detail,
          if (reporterEmail != null) 'reporterEmail': reporterEmail,
        },
        surface: ApiSurface.public,
      );
      final map = _asMap(json);
      return map['reportId']?.toString();
    } catch (error) {
      debugPrint('[guidance_repository] report failed: $error');
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return <String, dynamic>{};
  }
}
