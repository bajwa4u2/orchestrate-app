import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientRepliesScreen extends StatefulWidget {
  const ClientRepliesScreen({super.key});

  @override
  State<ClientRepliesScreen> createState() => _ClientRepliesScreenState();
}

class _ClientRepliesScreenState extends State<ClientRepliesScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  late Future<Map<String, dynamic>> _future;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchReplies();
  }

  void _retry() {
    setState(() => _future = _repository.fetchReplies());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading replies');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ClientErrorView(
            message:
                error is ApiException ? error.displayMessage : error.toString(),
            onRetry: _retry,
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final summary = asMap(data['summary']);
        final replies = asList(data['items']).map(asMap).toList();
        final needsReview = replies
            .where((item) => item['requiresHumanReview'] == true)
            .toList();
        final unread = replies
            .where((item) => readText(item, 'handledAt').isEmpty)
            .toList();
        final handled = replies
            .where((item) => readText(item, 'handledAt').isNotEmpty)
            .toList();
        final selected = replies.firstWhere(
          (item) => readText(item, 'id') == _selectedId,
          orElse: () =>
              replies.isEmpty ? const <String, dynamic>{} : replies.first,
        );
        final banner = _replyBanner(replies, needsReview, unread);

        return ClientPage(
          eyebrow: 'Replies',
          title: replies.isEmpty
              ? 'No inbound replies are visible yet'
              : '${replies.length} replies from outreach',
          subtitle:
              'Use this inbox to decide which replies need review, which have meetings, and which require no action.',
          banner: banner,
          actions: [
            if (needsReview.isNotEmpty)
              FilledButton.icon(
                onPressed: () => setState(
                    () => _selectedId = readText(needsReview.first, 'id')),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Review new replies'),
              ),
          ],
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Total', '${summary['total'] ?? replies.length}'),
              ClientMetric('Needs review', '${summary['needsReview'] ?? 0}'),
              ClientMetric('Interested', '${summary['interested'] ?? 0}'),
              ClientMetric('Meetings', '${summary['meetings'] ?? 0}'),
            ]),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;
              final list = ClientPanel(
                title: 'Reply inbox',
                children: replies.isEmpty
                    ? const [
                        ClientEmptyState(
                            message:
                                'Replies appear here after prospects respond to sent outreach.')
                      ]
                    : _groupedReplyItems(
                        selected: selected,
                        unread: unread,
                        needsReview: needsReview,
                        handled: handled,
                        onSelect: (reply) =>
                            setState(() => _selectedId = readText(reply, 'id')),
                      ),
              );
              final detail = _ReplyDetail(reply: selected);
              if (stacked) {
                return Column(
                  children: [
                    list,
                    const SizedBox(height: 18),
                    detail,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: list),
                  const SizedBox(width: 18),
                  Expanded(flex: 6, child: detail),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}

class _ReplyListItem extends StatelessWidget {
  const _ReplyListItem({
    required this.reply,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> reply;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contact = asMap(reply['contact']);
    return Material(
      color: selected ? Colors.black.withOpacity(0.04) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ClientBadge(label: titleCase(readText(reply, 'intent'))),
                  if (reply['requiresHumanReview'] == true)
                    const ClientBadge(label: 'Needs review'),
                  if (reply['meeting'] != null)
                    const ClientBadge(label: 'Meeting linked'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                readText(reply, 'subjectLine', fallback: 'Reply'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                [
                  readText(contact, 'name',
                      fallback: readText(reply, 'fromEmail')),
                  readText(contact, 'company'),
                  dateLabel(reply['receivedAt']),
                ].where((item) => item.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Divider(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyDetail extends StatelessWidget {
  const _ReplyDetail({required this.reply});

  final Map<String, dynamic> reply;

  @override
  Widget build(BuildContext context) {
    if (reply.isEmpty) {
      return const ClientPanel(
        title: 'Reply detail',
        children: [
          ClientEmptyState(
              message:
                  'Select a reply to review the contact, campaign, original outreach, and message body.')
        ],
      );
    }
    final contact = asMap(reply['contact']);
    final campaign = asMap(reply['campaign']);
    final message = asMap(reply['message']);
    final meeting = asMap(reply['meeting']);
    final confidence = reply['confidence'];

    return ClientPanel(
      title: 'Reply detail',
      subtitle: readText(reply, 'subjectLine', fallback: 'Inbound reply'),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ClientBadge(
                label: 'Intent: ${titleCase(readText(reply, 'intent'))}'),
            if (confidence != null)
              ClientBadge(label: 'Confidence: $confidence'),
            ClientBadge(
                label: reply['requiresHumanReview'] == true
                    ? 'Human review needed'
                    : 'No review flag'),
          ],
        ),
        const SizedBox(height: 16),
        ClientStatusBanner(
          tone: _intentTone(readText(reply, 'intent')),
          title: _nextStepTitle(reply),
          message: _nextStepMessage(reply),
        ),
        const SizedBox(height: 16),
        ClientInfoRow(
          title: 'From',
          primary: [
            readText(contact, 'name'),
            readText(contact, 'email'),
            readText(contact, 'company'),
          ].where((item) => item.isNotEmpty).join(' · '),
          secondary: readText(contact, 'title'),
        ),
        ClientInfoRow(
          title: 'Campaign',
          primary: readText(campaign, 'name', fallback: 'No campaign linked'),
          secondary: titleCase(readText(campaign, 'status')),
        ),
        ClientInfoRow(
          title: 'Original outreach',
          primary: readText(message, 'subjectLine',
              fallback: 'No original outreach message linked'),
          secondary: [
            titleCase(readText(message, 'status')),
            dateLabel(message['sentAt']),
          ].where((item) => item.isNotEmpty).join(' · '),
        ),
        ClientInfoRow(
          title: 'Meeting handoff',
          primary: meeting.isEmpty
              ? 'No meeting is linked to this reply.'
              : titleCase(readText(meeting, 'status')),
          secondary: meeting.isEmpty
              ? ''
              : [
                  readText(meeting, 'title'),
                  dateLabel(meeting['scheduledAt']),
                  readText(meeting, 'bookingUrl'),
                ].where((item) => item.isNotEmpty).join(' · '),
        ),
        const SizedBox(height: 8),
        Text(readText(reply, 'bodyText', fallback: 'No reply body is stored.'),
            style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

ClientStatusBanner _replyBanner(
  List<Map<String, dynamic>> replies,
  List<Map<String, dynamic>> needsReview,
  List<Map<String, dynamic>> unread,
) {
  if (replies.isEmpty) {
    return const ClientStatusBanner(
      tone: ClientBannerTone.info,
      title: 'Replies will appear when recipients respond',
      message:
          'No reply records are visible yet. If nothing changes, keep monitoring outreach volume and mailbox readiness.',
    );
  }
  if (needsReview.isNotEmpty) {
    return ClientStatusBanner(
      tone: ClientBannerTone.warning,
      title: '${needsReview.length} replies need review',
      message:
          'Start with replies flagged for human review. If you do nothing, interested or unclear responses may wait unresolved.',
    );
  }
  if (unread.isNotEmpty) {
    return ClientStatusBanner(
      tone: ClientBannerTone.info,
      title: '${unread.length} replies are unhandled',
      message:
          'Review unhandled replies for intent and meeting handoff status. If you do nothing, the inbox remains untriaged.',
    );
  }
  return const ClientStatusBanner(
    tone: ClientBannerTone.success,
    title: 'Reply inbox is handled',
    message:
        'No visible replies require review right now. Keep watching for new inbound replies.',
  );
}

List<Widget> _groupedReplyItems({
  required Map<String, dynamic> selected,
  required List<Map<String, dynamic>> unread,
  required List<Map<String, dynamic>> needsReview,
  required List<Map<String, dynamic>> handled,
  required ValueChanged<Map<String, dynamic>> onSelect,
}) {
  final reviewIds = needsReview.map((item) => readText(item, 'id')).toSet();
  final unreviewed = unread
      .where((item) => !reviewIds.contains(readText(item, 'id')))
      .toList();
  return [
    if (needsReview.isNotEmpty) ...[
      const _GroupLabel('Needs attention'),
      for (final reply in needsReview)
        _ReplyListItem(
          reply: reply,
          selected: readText(reply, 'id') == readText(selected, 'id'),
          onTap: () => onSelect(reply),
        ),
    ],
    if (unreviewed.isNotEmpty) ...[
      const _GroupLabel('Unread'),
      for (final reply in unreviewed)
        _ReplyListItem(
          reply: reply,
          selected: readText(reply, 'id') == readText(selected, 'id'),
          onTap: () => onSelect(reply),
        ),
    ],
    if (handled.isNotEmpty) ...[
      const _GroupLabel('Handled'),
      for (final reply in handled)
        _ReplyListItem(
          reply: reply,
          selected: readText(reply, 'id') == readText(selected, 'id'),
          onTap: () => onSelect(reply),
        ),
    ],
  ];
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: AppTheme.publicMuted),
      ),
    );
  }
}

ClientBannerTone _intentTone(String intent) {
  final normalized = intent.toUpperCase();
  if (normalized == 'INTERESTED' || normalized == 'REFERRAL') {
    return ClientBannerTone.success;
  }
  if (normalized == 'UNCLEAR' || normalized == 'NOT_NOW') {
    return ClientBannerTone.warning;
  }
  return ClientBannerTone.info;
}

String _nextStepTitle(Map<String, dynamic> reply) {
  if (reply['meeting'] != null) return 'Meeting scheduled';
  if (reply['requiresHumanReview'] == true) return 'Follow up needed';
  final intent = readText(reply, 'intent').toUpperCase();
  if (intent == 'INTERESTED' || intent == 'REFERRAL') {
    return 'Interested reply needs attention';
  }
  return 'No immediate action needed';
}

String _nextStepMessage(Map<String, dynamic> reply) {
  if (reply['meeting'] != null) {
    return 'A meeting is linked to this reply. If you do nothing, the meeting remains on record without additional client-side action.';
  }
  if (reply['requiresHumanReview'] == true) {
    return 'This reply is flagged for review. If you do nothing, the conversation may remain unresolved.';
  }
  final intent = readText(reply, 'intent').toUpperCase();
  if (intent == 'INTERESTED' || intent == 'REFERRAL') {
    return 'This reply may create a meeting opportunity. Review the context before assuming the handoff is complete.';
  }
  return 'The backend has no review or meeting flag on this reply. Keep it for context and watch for future replies.';
}
