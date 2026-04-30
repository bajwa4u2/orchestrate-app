import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/data/repositories/client/client_campaign_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientOutreachScreen extends StatefulWidget {
  const ClientOutreachScreen({super.key});

  @override
  State<ClientOutreachScreen> createState() => _ClientOutreachScreenState();
}

class _ClientOutreachScreenState extends State<ClientOutreachScreen> {
  final ClientPortalRepository _repository = ClientPortalRepository();
  final ClientCampaignRepository _campaignRepository =
      ClientCampaignRepository();
  late Future<Map<String, dynamic>> _future;
  bool _starting = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchOutreach();
  }

  void _retry() {
    setState(() => _future = _repository.fetchOutreach());
  }

  Future<void> _runAction(Future<Map<String, dynamic>> Function() action,
      {required bool retry}) async {
    setState(() {
      if (retry) {
        _retrying = true;
      } else {
        _starting = true;
      }
    });
    try {
      final result = await action();
      if (!mounted) return;
      final message = readText(result, 'message',
          fallback: retry
              ? 'Campaign retry has started.'
              : 'Campaign activation has started.');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      _retry();
    } catch (error) {
      if (!mounted) return;
      final message =
          error is ApiException ? error.displayMessage : error.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _retrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading outreach');
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
        final readiness = asMap(data['readiness']);
        final summary = asMap(data['summary']);
        final mailbox = asMap(data['mailbox']);
        final campaigns = asList(data['campaigns']);
        final messages = asList(data['recentMessages']);
        final actions = asMap(data['actions']);
        final blockers = asList(readiness['blockers']);
        final canStart = actions['startCampaign'] != null;
        final canRetry = actions['retryCampaign'] != null;

        return ClientPage(
          eyebrow: 'Outreach',
          title: readiness['mailboxReady'] == true &&
                  readiness['representationAuthorized'] == true
              ? 'Outreach is connected to live campaign state'
              : 'Outreach readiness needs attention',
          subtitle:
              'Campaigns, mailbox readiness, recent sends, replies, meetings, and blockers are read from client-scoped backend records.',
          actions: [
            if (canStart)
              FilledButton.icon(
                onPressed: _starting
                    ? null
                    : () => _runAction(_campaignRepository.startCampaign,
                        retry: false),
                icon: _starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rocket_launch_outlined, size: 18),
                label: Text(_starting ? 'Starting' : 'Start campaign'),
              ),
            if (canRetry)
              OutlinedButton.icon(
                onPressed: _retrying
                    ? null
                    : () => _runAction(_campaignRepository.restartCampaign,
                        retry: true),
                icon: _retrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_retrying ? 'Retrying' : 'Retry campaign'),
              ),
          ],
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Campaigns', '${summary['campaigns'] ?? 0}'),
              ClientMetric('Queued', '${summary['queued'] ?? 0}'),
              ClientMetric('Sent', '${summary['sent'] ?? 0}'),
              ClientMetric('Replies', '${summary['replies'] ?? 0}'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Readiness',
              subtitle:
                  'Actions only appear when backend capability flags allow them.',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ClientBadge(
                        label: readiness['setupComplete'] == true
                            ? 'Setup complete'
                            : 'Setup incomplete'),
                    ClientBadge(
                        label: readiness['representationAuthorized'] == true
                            ? 'Authorized'
                            : 'Authorization needed'),
                    ClientBadge(
                        label: readiness['mailboxReady'] == true
                            ? 'Mailbox ready'
                            : 'Mailbox not ready'),
                  ],
                ),
                const SizedBox(height: 16),
                if (blockers.isEmpty)
                  const ClientEmptyState(
                      message:
                          'No outreach blockers are currently reported for this account.')
                else
                  for (final blocker in blockers)
                    ClientInfoRow(
                      title: readText(asMap(blocker), 'label',
                          fallback: 'Blocked'),
                      primary: readText(asMap(blocker), 'detail'),
                    ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Mailbox state',
              children: [
                ClientInfoRow(
                  title: mailbox['ready'] == true
                      ? 'Mailbox ready'
                      : 'Mailbox unavailable',
                  primary: _mailboxPrimary(mailbox),
                  secondary:
                      'Reconnect is hidden because no client reconnect endpoint is currently exposed.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Campaigns',
              children: campaigns.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'No campaigns are available yet. Start from Campaign once setup and billing are ready.')
                    ]
                  : [
                      for (final item in campaigns)
                        ClientInfoRow(
                          title: readText(asMap(item), 'name',
                              fallback: 'Campaign'),
                          primary:
                              'Status: ${titleCase(readText(asMap(item), 'status'))}',
                          secondary:
                              'Leads: ${asMap(asMap(item)['counts'])['leads'] ?? 0} · Messages: ${asMap(asMap(item)['counts'])['messages'] ?? 0} · Replies: ${asMap(asMap(item)['counts'])['replies'] ?? 0}',
                        ),
                    ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Recent sends',
              children: messages.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'Sent and queued outreach messages will appear after campaign execution creates them.')
                    ]
                  : [
                      for (final item in messages)
                        ClientInfoRow(
                          title: readText(asMap(item), 'subjectLine',
                              fallback: 'Outreach message'),
                          primary:
                              '${titleCase(readText(asMap(item), 'status'))} · ${readText(asMap(asMap(item)['contact']), 'name', fallback: readText(asMap(asMap(item)['contact']), 'email'))}',
                          secondary: dateLabel(asMap(item)['sentAt'] ??
                              asMap(item)['createdAt']),
                        ),
                    ],
            ),
          ],
        );
      },
    );
  }

  String _mailboxPrimary(Map<String, dynamic> mailbox) {
    final primary = asMap(mailbox['primary']);
    if (primary.isEmpty) return 'No mailbox is visible for this client yet.';
    return [
      readText(primary, 'emailAddress'),
      titleCase(readText(primary, 'status')),
      titleCase(readText(primary, 'connectionState')),
      titleCase(readText(primary, 'healthStatus')),
    ].where((item) => item.isNotEmpty).join(' · ');
  }
}
