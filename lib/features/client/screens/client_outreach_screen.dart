import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/data/repositories/client/client_campaign_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_mailbox_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_workflow_state_repository.dart';
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
  final ClientMailboxRepository _mailboxRepository = ClientMailboxRepository();
  final ClientWorkflowStateRepository _workflowRepository =
      ClientWorkflowStateRepository();
  late Future<List<Map<String, dynamic>>> _futures;
  bool _starting = false;
  bool _retrying = false;
  bool _activatingMailbox = false;

  @override
  void initState() {
    super.initState();
    _futures = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => Future.wait([
        _repository.fetchOutreach(),
        _workflowRepository.fetchWorkflowState().catchError((_) => const <String, dynamic>{}),
      ]);

  void _retry() {
    setState(() => _futures = _load());
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
      final message = _campaignActionMessage(result, retry: retry);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      _retry();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ClientErrorView.classifyError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _retrying = false;
        });
      }
    }
  }

  String _campaignActionMessage(
    Map<String, dynamic> result, {
    required bool retry,
  }) {
    // Backend signals already-active via either `alreadyActive: true` or
    // `status: 'active'` on the idempotent path. Treat that as a calm
    // confirmation, not a noisy "your action has started" message that
    // contradicts what the page is about to show after refresh.
    final alreadyActive = result['alreadyActive'] == true ||
        '${result['status'] ?? ''}'.toLowerCase() == 'active';
    if (alreadyActive) {
      return 'Campaign is already running — outreach will keep moving without further action.';
    }
    final success = result['success'] != false;
    if (!success) {
      final backendMessage = readText(result, 'message');
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Campaign action is not available right now. Refresh outreach for the latest state.';
    }
    final backendMessage = readText(result, 'message');
    if (backendMessage.isNotEmpty) return backendMessage;
    return retry
        ? 'Campaign retry has started.'
        : 'Campaign activation has started.';
  }

  Future<void> _activateMailbox() async {
    setState(() => _activatingMailbox = true);
    try {
      final result = await _mailboxRepository.activateMailbox();
      if (!mounted) return;
      final ready = result['ready'] == true;
      final blockers = asList(result['blockers']);
      final blocker = blockers.isEmpty ? '' : readText(asMap(blockers.first), 'message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ready
              ? 'Mailbox is ready.'
              : blocker.isNotEmpty
                  ? blocker
                  : 'Mailbox activation is still blocked.'),
        ),
      );
      _retry();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ClientErrorView.classifyError(error))));
    } finally {
      if (mounted) setState(() => _activatingMailbox = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futures,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading outreach');
        }
        if (snapshot.hasError) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Outreach is temporarily unavailable',
            onRetry: _retry,
          );
        }

        final data = snapshot.data?[0] ?? const <String, dynamic>{};
        final workflowState = snapshot.data?[1] ?? const <String, dynamic>{};
        final readiness = asMap(data['readiness']);
        final summary = asMap(data['summary']);
        final mailbox = asMap(data['mailbox']);
        final campaigns = asList(data['campaigns']);
        final messages = asList(data['recentMessages']);
        final actions = asMap(data['actions']);
        final capabilities = asMap(workflowState['capabilities']);
        final blockers = _mergeBlockers(readiness, workflowState);
        final canStart = actions['startCampaign'] != null;
        final canRetry = actions['retryCampaign'] != null;
        final canActivateMailbox =
            workflowState['overallState'] == 'MAILBOX_BLOCKED' &&
                capabilities['canActivateMailbox'] == true;
        final queued = _intValue(summary['queued']);
        final sent = _intValue(summary['sent']);
        final replies = _intValue(summary['replies']);
        final meetings = _intValue(summary['meetings']);
        final wfMetrics = asMap(workflowState['metrics']);
        final retryableFailed = _intValue(wfMetrics['retryableFailed']);
        final primaryStatus =
            readText(readiness, 'primaryCampaignStatus').toUpperCase();
        final status = _outreachStatus(
          blockers: blockers,
          canStart: canStart,
          canRetry: canRetry,
          sent: sent,
          replies: replies,
          primaryCampaignStatus: primaryStatus,
        );
        final attention = _attentionItems(
          blockers: blockers,
          summary: summary,
          campaigns: campaigns,
          retryableFailed: retryableFailed,
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
            // Defense in depth: even if the action payload still carries a
            // stale `startCampaign` flag, never expose the Start button when
            // the authoritative campaign status says ACTIVE. Same for retry.
            if (canStart && blockers.isEmpty && primaryStatus != 'ACTIVE')
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
            if (canRetry && blockers.isEmpty && primaryStatus != 'ACTIVE')
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
            if (!canStart && !canRetry && blockers.isNotEmpty && canActivateMailbox)
              FilledButton.icon(
                onPressed: _activatingMailbox ? null : _activateMailbox,
                icon: _activatingMailbox
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.outgoing_mail, size: 18),
                label: Text(_activatingMailbox ? 'Activating' : 'Activate mailbox'),
              ),
            if (!canStart && !canRetry && blockers.isNotEmpty)
              OutlinedButton.icon(
                onPressed: canActivateMailbox ? () => context.go('/app/mailbox') : null,
                icon: const Icon(Icons.block_outlined, size: 18),
                label: Text(canActivateMailbox ? 'View mailbox' : _firstBlockerAction(blockers)),
              ),
          ],
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Campaigns', '${summary['campaigns'] ?? 0}'),
              ClientMetric('Queued', '$queued'),
              ClientMetric('Sent', '$sent'),
              if (retryableFailed > 0)
                ClientMetric('Retry needed', '$retryableFailed'),
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
                    ClientBadge(
                        label: readiness['outboundEmailReady'] == true
                            ? 'Outbound email ready'
                            : 'Outbound ${titleCase(readText(readiness, 'outboundEmailStatus', fallback: 'blocked'))}'),
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
  String primaryCampaignStatus = '',
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

  // The authoritative campaign status takes precedence over derived
  // action flags. If the backend says the primary campaign is ACTIVE,
  // never tell the operator "campaign can move now" — even if a stale
  // canStart/canRetry flag slipped through.
  if (primaryCampaignStatus == 'ACTIVE') {
    if (sent > 0 && replies == 0) {
      return const _OutreachStatus(
        title: 'Outreach is running',
        bannerTitle: 'Sends are out, waiting for replies',
        bannerMessage:
            'Your campaign is active. No replies are visible yet — keep watching reply volume and mailbox readiness.',
        tone: ClientBannerTone.info,
      );
    }
    return const _OutreachStatus(
      title: 'Outreach is running',
      bannerTitle: 'Campaign is active',
      bannerMessage:
          'Discovery, qualification, and outreach are running automatically. Review replies and meetings as they arrive.',
      tone: ClientBannerTone.success,
    );
  }

  if (canStart || canRetry) {
    return _OutreachStatus(
      title: canRetry
          ? 'Outreach needs a retry'
          : 'Outreach is ready to start',
      bannerTitle:
          canRetry ? 'Campaign needs a retry' : 'Campaign is ready to start',
      bannerMessage: canRetry
          ? 'Use Retry campaign to re-queue failed work. Discovery and qualification stay paused until you do.'
          : 'Use Start campaign when you are ready. Discovery and qualification will begin once activation completes.',
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

List<dynamic> _mergeBlockers(
  Map<String, dynamic> readiness,
  Map<String, dynamic> workflowState,
) {
  final existing = asList(readiness['blockers']);
  final primaryBlocker = asMap(workflowState['primaryBlocker']);
  if (primaryBlocker.isEmpty) return existing;
  final primaryCode = readText(primaryBlocker, 'code');
  final alreadyPresent = existing.any((b) => readText(asMap(b), 'code') == primaryCode);
  if (alreadyPresent || primaryCode.isEmpty) return existing;
  final extra = {
    'code': primaryCode,
    'label': readText(primaryBlocker, 'message').split('.').first,
    'detail': readText(primaryBlocker, 'message'),
  };
  return [extra, ...existing];
}

List<_AttentionItem> _attentionItems({
  required List<dynamic> blockers,
  required Map<String, dynamic> summary,
  required List<dynamic> campaigns,
  int retryableFailed = 0,
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
  if (retryableFailed > 0) {
    items.add(_AttentionItem(
      'Sends need retry',
      '$retryableFailed message(s) failed and can be retried.',
      'Use the retry campaign action to re-queue failed sends.',
    ));
  }
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
