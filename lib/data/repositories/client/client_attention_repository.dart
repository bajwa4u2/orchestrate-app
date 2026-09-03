import '../../../core/network/api_client.dart';

/// WHAT THIS BUSINESS IS OWED, AND WHAT IT OWES.
///
/// Attention means a human owes meaningful work because something cannot
/// proceed safely or truthfully without it. Not a notification, not an unread
/// count — a list that fires for everything teaches the person reading it to
/// stop reading, and the one item that genuinely needed them is the one they
/// scroll past.
///
/// Ownership is decided by the backend and typed here without reinterpretation.
/// A client-side "this looks like theirs" would be a second opinion about whose
/// work it is, and one of the two would be wrong in front of a real business.
class ClientAttentionRepository {
  ClientAttentionRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Everything waiting. Envelope only — no message body is fetched for this.
  Future<AttentionView> fetch({bool includeSettled = false}) async {
    final json = await _apiClient.getJson(
      '/client/attention',
      surface: ApiSurface.client,
      query: {if (includeSettled) 'includeSettled': 'true'},
    );
    return AttentionView.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// One message, rendered safely, fetched at the moment of reading.
  Future<SafeMessage> review(String id) async {
    final json = await _apiClient.getJson(
      '/client/attention/$id',
      surface: ApiSurface.client,
    );
    return SafeMessage.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Record that a client has dealt with something.
  ///
  /// Returns the backend's own answer, refusals included. A refused action is
  /// a different outcome from a failed request and the caller can tell.
  Future<Map<String, dynamic>> settle({
    required String id,
    required AttentionAction action,
  }) async {
    final json = await _apiClient.postJson(
      '/client/attention/$id/settle',
      surface: ApiSurface.client,
      body: {'action': action.wire},
    );
    return Map<String, dynamic>.from(json as Map);
  }
}

/// Who owes the work.
///
/// A first-class fact rather than something inferred, because every wrong
/// answer is a specific harm: showing operator work to a client is a demand
/// they cannot satisfy, and hiding client work is the custody defect itself.
enum AttentionOwner {
  /// This business's own human has to act.
  client('CLIENT'),

  /// Orchestrate has to act. Visible, and honestly not theirs.
  operator('OPERATOR'),

  /// Resolvable deterministically, with no human consequence.
  system('SYSTEM'),

  /// Worth knowing. Nobody owes anything.
  none('NONE');

  const AttentionOwner(this.wire);
  final String wire;

  static AttentionOwner parse(String? value) {
    for (final o in AttentionOwner.values) {
      if (o.wire == value) return o;
    }
    return AttentionOwner.none;
  }
}

enum AttentionState {
  open('OPEN'),
  inReview('IN_REVIEW'),
  resolved('RESOLVED');

  const AttentionState(this.wire);
  final String wire;

  static AttentionState parse(String? value) {
    for (final s in AttentionState.values) {
      if (s.wire == value) return s;
    }
    return AttentionState.open;
  }
}

/// What a person may legitimately do about one item.
///
/// Deliberately not a generic "resolve": different resolutions have different
/// consequences, and one button meaning five things is how somebody asserts a
/// business fact they never intended.
enum AttentionAction {
  markReviewed('MARK_REVIEWED', 'Mark as seen'),
  dismiss('DISMISS', 'No longer needs me'),
  escalateToOperator('ESCALATE_TO_OPERATOR', 'Ask Orchestrate to look'),
  associateWithRelationship('ASSOCIATE_WITH_RELATIONSHIP', 'Place on a relationship'),
  openRelationship('OPEN_RELATIONSHIP', 'Open the relationship'),
  reviewMessage('REVIEW_MESSAGE', 'Read the message'),
  viewProvenance('VIEW_PROVENANCE', 'How we know this');

  const AttentionAction(this.wire, this.label);
  final String wire;

  /// What the button says. Phrased as what it does, never as a verdict.
  final String label;

  static AttentionAction? parse(String? value) {
    for (final a in AttentionAction.values) {
      if (a.wire == value) return a;
    }
    return null;
  }
}

class AttentionView {
  const AttentionView({required this.items, required this.counts, required this.note});

  final List<AttentionItem> items;

  /// Open work per owner. Useful, and never the headline — a number is not
  /// product meaning, and "you have 24 alerts" is not a home experience.
  final Map<AttentionOwner, int> counts;
  final String note;

  /// Only what this business's own people owe, and only while it is still
  /// theirs. An item they have handed to an operator is no longer waiting on
  /// them — listing it in both places would show one message as two.
  List<AttentionItem> get needsYou => items
      .where((i) => i.owner == AttentionOwner.client && i.state == AttentionState.open)
      .toList(growable: false);

  /// Waiting on Orchestrate: ours to begin with, or handed to us.
  List<AttentionItem> get waitingOnUs => items
      .where((i) =>
          i.state == AttentionState.inReview ||
          (i.state == AttentionState.open &&
              (i.owner == AttentionOwner.operator || i.owner == AttentionOwner.system)))
      .toList(growable: false);

  /// Arrived, and nobody owes work about it.
  ///
  /// Still shown. Mail that reached this business and is simply of no
  /// consequence is not mail to hide — hiding it is the same defect in a
  /// quieter form.
  List<AttentionItem> get observational => items
      .where((i) => i.owner == AttentionOwner.none && i.state == AttentionState.open)
      .toList(growable: false);

  List<AttentionItem> get settled =>
      items.where((i) => i.state == AttentionState.resolved).toList(growable: false);

  static AttentionView fromJson(Map<String, dynamic> json) {
    final rawCounts = Map<String, dynamic>.from(json['counts'] as Map? ?? {});
    return AttentionView(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((i) => AttentionItem.fromJson(Map<String, dynamic>.from(i)))
          .toList(growable: false),
      counts: {
        for (final owner in AttentionOwner.values)
          owner: (rawCounts[owner.wire] as num?)?.toInt() ?? 0,
      },
      note: (json['note'] as String?) ?? '',
    );
  }
}

class AttentionItem {
  const AttentionItem({
    required this.id,
    required this.kind,
    required this.owner,
    required this.severity,
    required this.state,
    required this.title,
    required this.why,
    required this.occurredAt,
    required this.counterparty,
    required this.relationshipId,
    required this.actions,
    required this.resolvedBy,
  });

  final String id;
  final String kind;
  final AttentionOwner owner;
  final String severity;
  final AttentionState state;

  /// The subject line, as it arrived.
  final String title;

  /// Why this cannot proceed without someone. From the backend, verbatim.
  final String why;
  final DateTime? occurredAt;
  final String? counterparty;

  /// Set when this already belongs to a relationship the business holds.
  final String? relationshipId;

  /// Only the legitimate next acts, decided by the backend.
  final List<AttentionAction> actions;
  final String? resolvedBy;

  bool get isMine => owner == AttentionOwner.client;

  static AttentionItem fromJson(Map<String, dynamic> json) => AttentionItem(
        id: (json['id'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? '',
        owner: AttentionOwner.parse(json['owner'] as String?),
        severity: (json['severity'] as String?) ?? 'INFO',
        state: AttentionState.parse(json['state'] as String?),
        title: (json['title'] as String?)?.trim().isEmpty ?? true
            ? '(no subject)'
            : (json['title'] as String).trim(),
        why: (json['why'] as String?) ?? '',
        occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? ''),
        counterparty: (json['counterparty'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['counterparty'] as String).trim(),
        relationshipId: (json['relationshipId'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['relationshipId'] as String).trim(),
        actions: ((json['actions'] as List?) ?? const [])
            .whereType<String>()
            .map(AttentionAction.parse)
            .whereType<AttentionAction>()
            .toList(growable: false),
        resolvedBy: json['resolvedBy'] as String?,
      );
}

/// A message rendered safely: scripts, active content and remote images gone.
///
/// Content unavailable is a real answer, not an empty body. "We recorded that a
/// message existed and its content is gone" is worth saying; a blank screen is
/// not.
class SafeMessage {
  const SafeMessage({
    required this.ok,
    required this.content,
    required this.contentAvailable,
    required this.contentNote,
    required this.wasHtml,
    required this.removedForSafety,
    required this.remoteContentBlocked,
    required this.hasAttachments,
    required this.custodyNote,
    required this.refusalReason,
  });

  final bool ok;
  final String? content;
  final bool contentAvailable;

  /// Why it is or is not there, in the backend's own words.
  final String contentNote;
  final bool wasHtml;
  final List<String> removedForSafety;
  final bool remoteContentBlocked;

  /// Null means nobody has checked. Never rendered as "no attachments".
  final bool? hasAttachments;
  final String custodyNote;
  final String? refusalReason;

  static SafeMessage fromJson(Map<String, dynamic> json) => SafeMessage(
        ok: json['ok'] != false,
        content: json['content'] as String?,
        contentAvailable: json['contentAvailable'] == true,
        contentNote: (json['contentNote'] as String?) ?? '',
        wasHtml: json['wasHtml'] == true,
        removedForSafety:
            ((json['removedForSafety'] as List?) ?? const []).whereType<String>().toList(),
        remoteContentBlocked: json['remoteContentBlocked'] == true,
        hasAttachments: json['hasAttachments'] as bool?,
        custodyNote: (json['custodyNote'] as String?) ?? '',
        refusalReason: json['reason'] as String?,
      );
}
