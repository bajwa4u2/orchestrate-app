import '../../../core/network/api_client.dart';

/// WHAT TODAY IS BUILT FROM.
///
/// Today is not a new backend surface. It composes what already exists into
/// the three questions a person actually has: what needs me, what is underway,
/// what moved.
///
/// The old overview endpoint returns counts — leads, contacts, channels,
/// replies, meetings. Those are not what this asks for. A count is only
/// allowed to appear here when it is the subject of an action.
class ClientTodayRepository {
  ClientTodayRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<TodayState> load() async {
    // Fetched together, and individually survivable. One unavailable source
    // must not blank the operational home — a person still needs to see the
    // rest of their morning.
    final results = await Future.wait([
      _safeList('/client/notifications'),
      _safeMap('/client/workflow-state'),
      _safeMap('/client/execution-eligibility'),
      _safeList('/client/messages/recent'),
      _safeList('/client/replies'),
    ]);

    return TodayState(
      alerts: results[0] as List<Map<String, dynamic>>,
      workflow: results[1] as Map<String, dynamic>,
      eligibility: results[2] as Map<String, dynamic>,
      recentMessages: results[3] as List<Map<String, dynamic>>,
      replies: results[4] as List<Map<String, dynamic>>,
    );
  }

  Future<List<Map<String, dynamic>>> _safeList(String path) async {
    try {
      final json = await _apiClient.getJson(path, surface: ApiSurface.client);
      final raw = json is Map
          ? (json['items'] ?? json['data'] ?? json['records'] ?? const [])
          : json;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _safeMap(String path) async {
    try {
      final json = await _apiClient.getJson(path, surface: ApiSurface.client);
      return json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

class TodayState {
  const TodayState({
    required this.alerts,
    required this.workflow,
    required this.eligibility,
    required this.recentMessages,
    required this.replies,
  });

  final List<Map<String, dynamic>> alerts;
  final Map<String, dynamic> workflow;
  final Map<String, dynamic> eligibility;
  final List<Map<String, dynamic>> recentMessages;
  final List<Map<String, dynamic>> replies;

  /// Things a person has to decide or do.
  ///
  /// Only OPEN alerts, and only blockers that name what would resolve them. A
  /// blocker nobody can act on belongs in flight, not here.
  List<TodayItem> get needsYou {
    final items = <TodayItem>[];

    for (final a in alerts) {
      if ((a['status']?.toString() ?? 'OPEN') != 'OPEN') continue;
      items.add(TodayItem(
        title: a['title']?.toString() ?? 'Something needs attention',
        detail: a['bodyText']?.toString(),
        meta: _ago(a['createdAt']),
        severity: a['severity']?.toString(),
        category: a['category']?.toString(),
      ));
    }

    // Execution blockers, phrased as the thing that would unblock them.
    final blockers = eligibility['blockers'];
    if (blockers is List) {
      for (final b in blockers.whereType<Map>()) {
        final reason = b['reason']?.toString() ?? b['message']?.toString();
        if (reason == null || reason.isEmpty) continue;
        items.add(TodayItem(
          title: b['title']?.toString() ?? 'Sending is held',
          // AN INTERNAL ERROR IS NOT AN ATTENTION ITEM.
          //
          // A blocker reason is normally written for the person who has to
          // act on it. When the backend hits its own defect the reason is a
          // stack trace instead, and rendering that verbatim shows a client
          // our source paths and tells them nothing they can do. The item
          // still appears — something IS held — but it says so honestly and
          // names who resolves it.
          detail: _looksInternal(reason)
              ? 'Sending is held by a fault on our side. Nothing is wrong with '
                  'your setup, and it needs us rather than you.'
              : reason,
          severity: 'WARNING',
          category: 'execution',
        ));
      }
    }

    return items;
  }

  /// Underway, or waiting on someone else. Never a metric.
  List<TodayItem> get inFlight {
    final items = <TodayItem>[];

    // A message that has left but has no delivery evidence yet is genuinely
    // in flight — and saying so is the honest alternative to treating sent as
    // delivered.
    final awaiting = recentMessages.where((m) {
      final state = (m['deliveryState'] ?? m['status'])?.toString().toUpperCase();
      return state == 'SENT' || state == 'DISPATCHED';
    }).length;
    if (awaiting > 0) {
      items.add(TodayItem(
        title: '$awaiting message${awaiting == 1 ? '' : 's'} awaiting delivery evidence',
        detail: 'Sent. Nothing has come back yet, either way.',
        category: 'delivery',
      ));
    }

    final running = workflow['activeRuns'] ?? workflow['running'];
    if (running is List && running.isNotEmpty) {
      items.add(TodayItem(
        title: 'Discovery is running',
        detail: '${running.length} in progress',
        category: 'discovery',
      ));
    }

    return items;
  }

  /// Movement worth reading, as events rather than counters.
  List<TodayItem> get changed {
    final items = <TodayItem>[];

    for (final r in replies.take(6)) {
      final from = r['fromEmail']?.toString() ?? 'Someone';
      final intent = r['intent']?.toString();
      items.add(TodayItem(
        title: 'Reply from $from',
        detail: _intentLine(intent),
        meta: _ago(r['receivedAt'] ?? r['createdAt']),
        category: 'reply',
        intent: intent,
      ));
    }

    for (final m in recentMessages) {
      final state = (m['deliveryState'] ?? m['status'])?.toString().toUpperCase();
      final delivery = m['delivery'] as Map<String, dynamic>?;
      final recipientImplicated = delivery?['recipientImplicated'] == true;
      final senderSide = delivery != null && !recipientImplicated;

      // A sender-side rejection is not the recipient's doing. Naming them
      // points the business at a contact that did nothing wrong and hides the
      // thing that actually needs fixing — the sending identity. Three of the
      // four failures on this estate were exactly that: a receiving server
      // refusing the sending domain, not a bad address.
      if (senderSide) {
        final by = delivery['reportedBy']?.toString();
        items.add(TodayItem(
          title: 'A receiving server refused your message',
          detail: [
            m['failureReason']?.toString(),
            if (by != null && by.isNotEmpty) 'Reported by $by.',
            'This is about your sending identity, not the person you wrote to.',
          ].whereType<String>().where((t) => t.isNotEmpty).join(' '),
          meta: _ago(m['updatedAt'] ?? m['sentAt']),
          severity: 'WARNING',
          category: 'delivery',
        ));
        continue;
      }

      if (state == 'BOUNCED' || state == 'FAILED') {
        items.add(TodayItem(
          title: 'Delivery failed to ${m['toEmail'] ?? 'a recipient'}',
          detail: m['failureReason']?.toString(),
          meta: _ago(m['updatedAt'] ?? m['sentAt']),
          severity: 'WARNING',
          category: 'delivery',
        ));
      }
    }

    return items;
  }

  /// Does this read like our failure rather than the client's situation?
  static bool _looksInternal(String reason) {
    const fingerprints = [
      'invocation in', 'prisma.', 'at Object.', '.ts:', '.dart:',
      'Traceback', 'stack', 'Unhandled', 'internal error', 'Exception:',
    ];
    final lower = reason.toLowerCase();
    return reason.contains('\n') ||
        reason.length > 400 ||
        fingerprints.any((f) => lower.contains(f.toLowerCase()));
  }

  static String? _intentLine(String? intent) => switch (intent) {
        'INTERESTED' => 'Positive interest',
        'UNSUBSCRIBE' => 'Asked not to be contacted',
        'REFERRAL' => 'Referred someone else',
        'NOT_INTERESTED' => 'Declined',
        'OUT_OF_OFFICE' => 'Out of office',
        'AUTOMATED' => 'Automated response',
        'QUESTION' => 'Asked a question',
        'UNCLEAR' => 'Needs reading',
        _ => null,
      };

  static String? _ago(Object? iso) {
    final parsed = DateTime.tryParse(iso?.toString() ?? '');
    if (parsed == null) return null;
    final d = DateTime.now().difference(parsed);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${parsed.day}/${parsed.month}';
  }
}

class TodayItem {
  const TodayItem({
    required this.title,
    this.detail,
    this.meta,
    this.severity,
    this.category,
    this.intent,
  });

  final String title;
  final String? detail;
  final String? meta;
  final String? severity;
  final String? category;
  final String? intent;
}
