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
      // A meeting is the most time-bound thing this product holds, and Today
      // is the only surface organised by time. Without it a business could
      // have a meeting in an hour and read its whole morning without meeting
      // it anywhere.
      _safeList('/client/meetings'),
    ]);

    return TodayState(
      alerts: results[0] as List<Map<String, dynamic>>,
      workflow: results[1] as Map<String, dynamic>,
      eligibility: results[2] as Map<String, dynamic>,
      recentMessages: results[3] as List<Map<String, dynamic>>,
      replies: results[4] as List<Map<String, dynamic>>,
      meetings: results[5] as List<Map<String, dynamic>>,
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
    this.meetings = const [],
  });

  final List<Map<String, dynamic>> alerts;
  final Map<String, dynamic> workflow;
  final Map<String, dynamic> eligibility;
  final List<Map<String, dynamic>> recentMessages;
  final List<Map<String, dynamic>> replies;
  final List<Map<String, dynamic>> meetings;

  /// A meeting that is still ahead and that the provider actually holds.
  ///
  /// Both halves matter. A settled meeting is not upcoming, and a meeting the
  /// provider never confirmed was offered to nobody — telling somebody to
  /// prepare for it would be inventing an appointment.
  static bool _isAhead(Map<String, dynamic> m) {
    const settled = {'COMPLETED', 'CANCELED', 'NO_SHOW'};
    final status = (m['status'] ?? '').toString().toUpperCase();
    if (settled.contains(status)) return false;
    if ((m['handoffStage'] ?? '').toString() == 'NEVER_REACHED_PROVIDER') {
      return false;
    }
    final at = DateTime.tryParse('${m['scheduledAt'] ?? ''}');
    return at != null && at.isAfter(DateTime.now());
  }

  static String _who(Map<String, dynamic> m) {
    final contact = m['contact'];
    if (contact is Map) {
      final name = (contact['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      final email = (contact['email'] ?? '').toString().trim();
      if (email.isNotEmpty) return email;
    }
    return '';
  }

  /// Things a person has to decide or do.
  ///
  /// Only OPEN alerts, and only blockers that name what would resolve them. A
  /// blocker nobody can act on belongs in flight, not here.
  List<TodayItem> get needsYou {
    final items = <TodayItem>[];

    // MEETINGS FIRST, BECAUSE THEY ARE THE ONLY THING HERE WITH A CLOCK.
    //
    // Everything else on this screen keeps. A meeting does not: it happens at
    // a time whether or not anybody read about it, and being told afterwards
    // is worth nothing. Ordered soonest first for the same reason.
    final ahead = meetings.where(_isAhead).toList()
      ..sort((a, b) => '${a['scheduledAt']}'.compareTo('${b['scheduledAt']}'));

    for (final m in ahead.take(5)) {
      final who = _who(m);
      final at = DateTime.tryParse('${m['scheduledAt'] ?? ''}');
      items.add(TodayItem(
        title: who.isEmpty
            ? '${m['title'] ?? 'Meeting'}'
            : '${m['title'] ?? 'Meeting'} with $who',
        // The entrance, so the thing a person does about a meeting is on the
        // same line as being told about it.
        detail: (m['bookingUrl'] ?? '').toString().isEmpty
            ? 'No joining link was issued for this meeting.'
            : m['bookingUrl'].toString(),
        meta: at == null ? null : _whenReadable(at),
        // Not a warning. A meeting going ahead is the product working.
        severity: 'INFO',
        category: 'meeting',
      ));
    }

    // A meeting nobody was invited to. This one IS ours to fix, and it will
    // not resolve on its own — nothing will ever arrive for a meeting the
    // provider does not hold.
    for (final m in meetings.where(
        (m) => (m['handoffStage'] ?? '').toString() == 'NEVER_REACHED_PROVIDER')) {
      items.add(TodayItem(
        title: 'A meeting was never created: ${m['title'] ?? 'Meeting'}',
        detail: 'It was prepared here and the meeting provider never confirmed '
            'it, so nobody was invited. Offer it again to create it.',
        meta: _ago(m['updatedAt'] ?? m['createdAt']),
        severity: 'WARNING',
        category: 'meeting',
      ));
    }

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
      final stage = m['deliveryStage']?.toString().toUpperCase();
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

      // A refusal Orchestrate made is not a delivery failure, and the status
      // column cannot tell them apart: these rows say BOUNCED while nothing
      // ever left the building. Reported as a bounce it tells a business its
      // mail is failing and sends it looking at a mail server; reported as what
      // it is, it says the product declined to write to something that was
      // never a prospect, which is the thing it was bought to do.
      if (stage == 'REFUSED_BEFORE_DISPATCH') {
        items.add(TodayItem(
          title: 'Not sent to ${m['toEmail'] ?? 'a recipient'}',
          detail: _refusalInPlainWords(m['failureReason']?.toString()),
          meta: _ago(m['updatedAt'] ?? m['sentAt']),
          // Not a warning. Nothing went wrong, and a row of amber flags across
          // the first screen of the day says otherwise.
          severity: 'INFO',
          category: 'governed',
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

  /// When a meeting is, said the way a person would say it.
  ///
  /// A meeting today is a time; a meeting later this week is a day. Rendering
  /// "in 47 hours" makes somebody do arithmetic about their own calendar.
  static String _whenReadable(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    final sameDay = local.year == now.year
        && local.month == now.month
        && local.day == now.day;
    if (sameDay) return 'today at $hh:$mm';

    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = local.year == tomorrow.year
        && local.month == tomorrow.month
        && local.day == tomorrow.day;
    if (isTomorrow) return 'tomorrow at $hh:$mm';

    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} at $hh:$mm';
  }

  /// Say why we declined, in words a business can act on.
  ///
  /// The guard writes for an operator: `representation blocked (SIGNAL_SOURCE):
  /// signal-source/news domain "techcrunch.com" is not a prospect`. That string
  /// is correct and it is not addressed to the person reading it, who is
  /// running a business rather than reading a policy engine. It also puts an
  /// internal code on the first screen of their day.
  ///
  /// Unrecognised reasons keep their original text rather than being replaced
  /// by something vaguer. A sentence nobody wrote for this audience is still
  /// better than a reassurance that says nothing.
  static String _refusalInPlainWords(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return 'Orchestrate declined to send this.';

    final code = RegExp(r'representation blocked \(([A-Z_/ ]+)\)')
        .firstMatch(text)
        ?.group(1)
        ?.trim();

    switch (code) {
      case 'SIGNAL_SOURCE':
      case 'SOURCE_NOT_PROSPECT':
        return 'This address belongs to a news or signal source rather than a '
            'company you could sell to, so nothing was sent.';
      case 'SYNTHETIC_TARGET':
        return 'This address was constructed from a pattern rather than '
            'observed, so nothing was sent.';
      case 'REPRESENTATION_AUTHORITY_ABSENT':
        return 'Nobody has authorised Orchestrate to write on your behalf yet, '
            'so nothing was sent.';
      case 'REPRESENTATION_AUTHORITY_EXPIRED':
        return 'The authorisation to write on your behalf has expired, so '
            'nothing was sent.';
      case 'REPRESENTATION_AUTHORITY_REVOKED':
        return 'The authorisation to write on your behalf was withdrawn, so '
            'nothing was sent.';
      case 'REPRESENTATION_SCOPE_NOT_GRANTED':
        return 'Writing to this counterparty is outside what Orchestrate was '
            'authorised to do, so nothing was sent.';
      case 'REPRESENTATION_ACCEPTOR_UNIDENTIFIED':
        return 'Orchestrate could not establish who authorised this, so '
            'nothing was sent.';
    }

    // Strip the operator prefix at least, so an unmapped reason still reads as
    // a sentence rather than as a log line.
    final withoutPrefix =
        text.replaceFirst(RegExp(r'^representation blocked \([^)]*\):\s*', caseSensitive: false), '');
    return withoutPrefix.isEmpty ? text : '${withoutPrefix[0].toUpperCase()}${withoutPrefix.substring(1)}';
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
