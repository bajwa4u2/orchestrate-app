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
        final selected = replies.firstWhere(
          (item) => readText(item, 'id') == _selectedId,
          orElse: () =>
              replies.isEmpty ? const <String, dynamic>{} : replies.first,
        );

        return ClientPage(
          eyebrow: 'Replies',
          title: replies.isEmpty
              ? 'No inbound replies are visible yet'
              : '${replies.length} replies from outreach',
          subtitle:
              'Reply intent, review state, original message context, and meeting handoff status come from client-scoped reply records.',
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
                    : [
                        for (final reply in replies)
                          _ReplyListItem(
                            reply: reply,
                            selected: readText(reply, 'id') ==
                                readText(selected, 'id'),
                            onTap: () => setState(
                                () => _selectedId = readText(reply, 'id')),
                          ),
                      ],
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
        ClientInfoRow(
          title: 'Contact',
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
