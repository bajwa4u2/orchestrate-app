import '../../../core/network/api_client.dart';

/// WHAT WAS DONE, BY WHOM, TO WHAT, AND WHEN.
///
/// The evidence behind every other operator surface. An operator admitting a
/// designation or resolving a case is making a decision that someone may have
/// to account for months later, and this is where that account lives.
///
/// Extracted from the retired operator estate along with the timeline that
/// renders it. The estate is gone; the audit trail is not optional.
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

  /// Who did it, in a name a person recognises. Null where the actor was the
  /// system rather than a human — which is itself worth being able to see.
  final String? actorDisplayName;

  static AuditEvent fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] is Map
        ? Map<String, dynamic>.from(json['actor'] as Map)
        : const <String, dynamic>{};
    return AuditEvent(
      id: (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      entityType: (json['entityType'] ?? '').toString(),
      entityId: (json['entityId'] ?? '').toString(),
      // Deliberately not defaulting to now(): an event with an unreadable
      // timestamp is not an event that happened this instant, and showing it
      // as the newest thing in the list would be a lie about the record.
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      actorId: actor['id']?.toString(),
      actorDisplayName: (actor['displayName'] ?? actor['fullName'] ?? actor['email'])
          ?.toString(),
    );
  }
}

class AuditEventsRepository {
  AuditEventsRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<AuditEvent>> fetch({
    String? action,
    String? entityType,
    String? actorUserId,
    int? limit,
    String? cursor,
  }) async {
    final json = await _api.getJson(
      '/operator/audit/events',
      query: {
        if (action != null && action.isNotEmpty) 'action': action,
        if (entityType != null && entityType.isNotEmpty) 'entityType': entityType,
        if (actorUserId != null && actorUserId.isNotEmpty) 'actorUserId': actorUserId,
        if (limit != null) 'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
      surface: ApiSurface.operator,
    );
    // The endpoint answers a bare array today. The envelope forms are tolerated
    // so a later pagination wrapper does not silently render an empty audit
    // trail — an audit surface that shows nothing must mean nothing happened,
    // never that the shape changed.
    final rows = json is List
        ? json
        : json is Map
            ? ((json['events'] ?? json['data'] ?? json['rows']) as List? ?? const [])
            : const [];
    return [
      for (final raw in rows)
        if (raw is Map) AuditEvent.fromJson(Map<String, dynamic>.from(raw)),
    ];
  }
}
