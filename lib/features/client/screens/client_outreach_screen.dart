import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        final queued = _intValue(summary['queued']);
        final sent = _intValue(summary['sent']);
        final replies = _intValue(summary['replies']);
        final meetings = _intValue(summary['meetings']);
        final status = _outreachStatus(
          blockers: blockers,
          canStart: canStart,
          canRetry: canRetry,
          sent: sent,
          replies: replies,
        );
        final attention = _attentionItems(
          blockers: blockers,
          summary: summary,
          campaigns: campaigns,
        );

        return ClientPage(
          eyebrow: 'Outreach',
          title: status.title,
          subtitle:
              'Use this control center to understand whether outreach is running, blocked, or waiting on recipient response.',
          banner: ClientStatusBanner(
            tone: status.tone,
            title: status.bannerTitle,
            message: status.bannerMessage,
          ),
          actions: [
            if (canStart && blockers.isEmpty)
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
            if (canRetry && blockers.isEmpty)
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
            if (!canStart && !canRetry && blockers.isEmpty && replies > 0)
              FilledButton.icon(
                onPressed: () => context.go('/client/replies'),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Review replies'),
              ),
            if (!canStart && !canRetry && blockers.isNotEmpty)
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.block_outlined, size: 18),
                label: Text(_firstBlockerAction(blockers)),
              ),
          ],
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Campaigns', '${summary['campaigns'] ?? 0}'),
              ClientMetric('Queued', '$queued'),
              ClientMetric('Replies', '$replies'),
              ClientMetric('Meetings', '$meetings'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'What needs attention',
              subtitle:
                  'This is the next operational question to resolve before outreach can improve.',
              children: attention.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'No immediate outreach attention items. If no replies arrive, keep watching reply volume and meetings as sends continue.')
                    ]
                  : [
                      for (final item in attention)
                        ClientInfoRow(
                          title: item.title,
                          primary: item.primary,
                          secondary: item.secondary,
                        ),
                    ],
            ),
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
                              'Status: ${titleCase(readText(asMap(item), 'status'))} · Last activity: ${relativeDateLabel(asMap(item)['updatedAt'])}',
                          secondary:
                              'Leads: ${asMap(asMap(item)['counts'])['leads'] ?? 0} · Messages: ${asMap(asMap(item)['counts'])['messages'] ?? 0} · Replies: ${asMap(asMap(item)['counts'])['replies'] ?? 0} · Meetings: ${asMap(asMap(item)['counts'])['meetings'] ?? 0}',
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

class _OutreachStatus {
  const _OutreachStatus({
    required this.title,
    required this.bannerTitle,
    required this.bannerMessage,
    required this.tone,
  });

  final String title;
  final String bannerTitle;
  final String bannerMessage;
  final ClientBannerTone tone;
}

class _AttentionItem {
  const _AttentionItem(this.title, this.primary, this.secondary);

  final String title;
  final String primary;
  final String secondary;
}

_OutreachStatus _outreachStatus({
  required List<dynamic> blockers,
  required bool canStart,
  required bool canRetry,
  required int sent,
  required int replies,
}) {
  if (blockers.isNotEmpty) {
    return _OutreachStatus(
      title: 'Outreach is blocked',
      bannerTitle: _firstBlockerAction(blockers),
      bannerMessage:
          'Fix the blocking item before campaign execution can reliably move forward. If nothing changes, sends and replies may stay stalled.',
      tone: ClientBannerTone.blocked,
    );
  }
  if (canStart || canRetry) {
    return const _OutreachStatus(
      title: 'Outreach is ready for action',
      bannerTitle: 'Campaign can move now',
      bannerMessage:
          'Use the available campaign action when you are ready. If you do nothing, outreach remains in its current state.',
      tone: ClientBannerTone.warning,
    );
  }
  if (sent > 0 && replies == 0) {
    return const _OutreachStatus(
      title: 'Outreach is waiting for replies',
      bannerTitle: 'Messages have been sent',
      bannerMessage:
          'No replies are visible yet. If nothing changes, continue monitoring replies and mailbox readiness.',
      tone: ClientBannerTone.info,
    );
  }
  return const _OutreachStatus(
    title: 'Outreach is running',
    bannerTitle: 'Campaign activity is visible',
    bannerMessage:
        'Review replies and meetings as they arrive. If you do nothing, the current backend workflow continues.',
    tone: ClientBannerTone.success,
  );
}

List<_AttentionItem> _attentionItems({
  required List<dynamic> blockers,
  required Map<String, dynamic> summary,
  required List<dynamic> campaigns,
}) {
  if (blockers.isNotEmpty) {
    return blockers
        .map((item) => _AttentionItem(
              readText(asMap(item), 'label', fallback: 'Blocked'),
              readText(asMap(item), 'detail'),
              'Resolve this before expecting new outreach movement.',
            ))
        .toList();
  }
  final items = <_AttentionItem>[];
  final campaignIdle = campaigns.any((item) {
    final status = readText(asMap(item), 'status').toUpperCase();
    return status == 'PAUSED' || status == 'DRAFT' || status == 'READY';
  });
  if (campaignIdle) {
    items.add(const _AttentionItem(
      'Campaign idle',
      'At least one campaign is not actively running.',
      'Review campaign state before expecting new sends.',
    ));
  }
  if (_intValue(summary['queued']) == 0 && _intValue(summary['sent']) == 0) {
    items.add(const _AttentionItem(
      'No sends yet',
      'No queued or sent outreach is visible.',
      'If setup is complete, review campaign activation and lead readiness.',
    ));
  }
  if (_intValue(summary['replies']) > 0) {
    items.add(const _AttentionItem(
      'Replies available',
      'Prospects have responded to outreach.',
      'Review Replies so interested responses are not missed.',
    ));
  }
  return items;
}

String _firstBlockerAction(List<dynamic> blockers) {
  final first =
      blockers.isEmpty ? const <String, dynamic>{} : asMap(blockers.first);
  final code = readText(first, 'code').toUpperCase();
  if (code.contains('MAILBOX')) return 'Fix mailbox readiness';
  if (code.contains('AUTH')) return 'Complete authorization';
  if (code.contains('SETUP')) return 'Complete setup';
  return readText(first, 'label', fallback: 'Fix blockers');
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
