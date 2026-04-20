import 'package:flutter/material.dart';

import '../data/repositories/operator_repository.dart';

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  late final OperatorRepository _repo;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _repo = OperatorRepository();
    _future = _repo.fetchCommandWorkspace();
  }

  Future<void> _refresh() async {
    final next = _repo.fetchCommandWorkspace();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    await action();
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _dispatchDueJobs() async {
    await _runAction(() async {
      await _repo.dispatchDueJobs();
    });
  }

  Future<void> _resolveAlert(String alertId) async {
    await _runAction(() async {
      await _repo.resolveAlert(alertId);
    });
  }

  Future<void> _activateCampaign(String campaignId) async {
    await _runAction(() async {
      await _repo.activateCampaign(campaignId);
    });
  }

  Future<void> _runJob(String jobId) async {
    await _runAction(() async {
      await _repo.runJob(jobId: jobId, force: true);
    });
  }

  Future<void> _refreshMailbox(String mailboxId) async {
    await _runAction(() async {
      await _repo.refreshMailboxHealth(mailboxId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Command could not load right now.',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final pulse = _asMap(data['pulse']);
        final totals = _asMap(pulse['totals']);
        final today = _asMap(pulse['today']);
        final executionPulse = _asMap(pulse['execution']);
        final deliverabilityPulse = _asMap(pulse['deliverability']);
        final health = _asMap(data['health']);
        final healthSummary = _asMap(health['summary']);
        final deliverability = _asMap(health['deliverability']);
        final execution = _asMap(data['execution']);

        final attention = _asList(data['attention']);
        final dispatches = _asList(execution['emailDispatches']);
        final failedJobs = _asList(execution['failedJobs']);
        final campaigns = _asList(_asMap(data['outreach'])['campaigns']);
        final clients = _asList(_asMap(data['clients'])['items']);
        final inquiries = _asList(_asMap(data['conversations'])['inquiries']);
        final mailboxes = _asList(deliverability['mailboxes']);

        final summary = _CommandSummary(
          sentToday: _read(today, 'sent', fallback: '0'),
          repliesToday: _read(today, 'replies', fallback: '0'),
          bookedToday: _read(today, 'booked', fallback: '0'),
          failedJobs: _read(executionPulse, 'failedJobs', fallback: '0'),
          healthyMailboxes: _read(
            deliverabilityPulse,
            'healthyMailboxes',
            fallback: _read(deliverability, 'healthyMailboxes', fallback: '0'),
          ),
          degradedMailboxes: _read(
            deliverabilityPulse,
            'degradedMailboxes',
            fallback: _read(deliverability, 'degradedMailboxes', fallback: '0'),
          ),
          totalClients: _read(totals, 'clients', fallback: '${clients.length}'),
          totalCampaigns: _read(totals, 'campaigns', fallback: '${campaigns.length}'),
          openAlerts: _read(healthSummary, 'open', fallback: '${_asList(health['alerts']).length}'),
        );

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommandHero(
                  title: _read(data, 'title', fallback: 'Operator command'),
                  subtitle: _read(
                    data,
                    'subtitle',
                    fallback:
                        'One place to see pressure, movement, and what needs operator attention before the rest of the workspace.',
                  ),
                  summary: summary,
                ),
                const SizedBox(height: 18),
                _TopActions(
                  onRefresh: _refresh,
                  onDispatchDueJobs: _dispatchDueJobs,
                ),
                const SizedBox(height: 18),
                _MetricGrid(
                  metrics: [
                    _MetricData(label: 'Sent today', value: summary.sentToday),
                    _MetricData(label: 'Replies today', value: summary.repliesToday),
                    _MetricData(label: 'Booked today', value: summary.bookedToday),
                    _MetricData(label: 'Failed jobs', value: summary.failedJobs),
                    _MetricData(label: 'Healthy mailboxes', value: summary.healthyMailboxes),
                    _MetricData(label: 'Open alerts', value: summary.openAlerts),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1180;

                    final mainColumn = Column(
                      children: [
                        _CardSection(
                          title: 'Needs attention now',
                          subtitle:
                              'The first queue to review before leaving command. Keep urgency, failure, and pending work visible.',
                          child: _AttentionList(
                            items: attention,
                            onResolveAlert: _resolveAlert,
                            onActivateCampaign: _activateCampaign,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _DualCardRow(
                          stacked: constraints.maxWidth < 860,
                          left: _CardSection(
                            title: 'Dispatch pressure',
                            subtitle:
                                'Recent outbound movement, failures, and evidence that campaigns are actually pushing work.',
                            child: _DispatchList(items: dispatches),
                          ),
                          right: _CardSection(
                            title: 'Inbound pressure',
                            subtitle:
                                'Recent contact stays visible from the same surface so operator does not bounce between worlds.',
                            child: _InquiryList(items: inquiries),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _DualCardRow(
                          stacked: constraints.maxWidth < 860,
                          left: _CardSection(
                            title: 'Failed jobs',
                            subtitle:
                                'Anything that failed should be runnable from here without leaving command.',
                            child: _FailedJobList(
                              items: failedJobs,
                              onRunJob: _runJob,
                            ),
                          ),
                          right: _CardSection(
                            title: 'Mailbox health',
                            subtitle:
                                'Mailbox health should stay actionable from command when delivery posture slips.',
                            child: _MailboxList(
                              items: mailboxes,
                              onRefreshMailbox: _refreshMailbox,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CardSection(
                          title: 'Campaign pressure',
                          subtitle:
                              'Campaigns should show state, timing, and signs of movement, not just existence.',
                          child: _CampaignList(
                            items: campaigns,
                            onActivateCampaign: _activateCampaign,
                          ),
                        ),
                      ],
                    );

                    final sideColumn = Column(
                      children: [
                        _CardSection(
                          title: 'Workspace posture',
                          subtitle:
                              'A compact read on client standing, campaign footprint, and mailbox health.',
                          child: _WorkspacePosture(summary: summary),
                        ),
                        const SizedBox(height: 18),
                        _CardSection(
                          title: 'Clients needing visibility',
                          subtitle:
                              'Client state should remain visible here so operator can sense who is live, stalled, or under-served.',
                          child: _ClientList(items: clients),
                        ),
                        const SizedBox(height: 18),
                        _CardSection(
                          title: 'System health',
                          subtitle:
                              'Mailbox and deliverability posture from the backend.',
                          child: _HealthSummary(
                            totals: totals,
                            deliverability: deliverability,
                            deliverabilityPulse: deliverabilityPulse,
                          ),
                        ),
                      ],
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          mainColumn,
                          const SizedBox(height: 18),
                          sideColumn,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: mainColumn),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: sideColumn),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommandHero extends StatelessWidget {
  const _CommandHero({
    required this.title,
    required this.subtitle,
    required this.summary,
  });

  final String title;
  final String subtitle;
  final _CommandSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.18),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Command', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          );

          final status = _HeroStatus(summary: summary);

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                status,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: intro),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: status),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.summary});

  final _CommandSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.24),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operator read', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _HeroLine(
            title: 'Today',
            value:
                '${summary.sentToday} sent · ${summary.repliesToday} replies · ${summary.bookedToday} booked',
          ),
          _HeroLine(
            title: 'Pressure',
            value:
                '${summary.failedJobs} failed jobs · ${summary.openAlerts} open alerts',
          ),
          _HeroLine(
            title: 'Mailboxes',
            value:
                '${summary.healthyMailboxes} healthy · ${summary.degradedMailboxes} degraded',
          ),
          _HeroLine(
            title: 'Footprint',
            value:
                '${summary.totalClients} clients · ${summary.totalCampaigns} campaigns',
          ),
        ],
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$title  ',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}


class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.onRefresh,
    required this.onDispatchDueJobs,
  });

  final Future<void> Function() onRefresh;
  final Future<void> Function() onDispatchDueJobs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton(
          onPressed: onDispatchDueJobs,
          child: const Text('Dispatch due jobs'),
        ),
        OutlinedButton(
          onPressed: onRefresh,
          child: const Text('Refresh command'),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200 ? 6 : width >= 820 ? 3 : 2;

        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: width >= 820 ? 1.6 : 1.45,
          ),
          itemBuilder: (context, index) => _MetricTile(metric: metrics[index]),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(metric.value, style: theme.textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _DualCardRow extends StatelessWidget {
  const _DualCardRow({
    required this.stacked,
    required this.left,
    required this.right,
  });

  final bool stacked;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        children: [
          left,
          const SizedBox(height: 18),
          right,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 18),
        Expanded(child: right),
      ],
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AttentionList extends StatelessWidget {
  const _AttentionList({
    required this.items,
    required this.onResolveAlert,
    required this.onActivateCampaign,
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function(String alertId) onResolveAlert;
  final Future<void> Function(String campaignId) onActivateCampaign;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'Nothing urgent is open right now.');
    }

    return Column(
      children: items.take(10).map((item) {
        final kind = _read(item, 'kind');
        final id = _read(item, 'id');
        final status = _read(item, 'severity');
        final actions = <Widget>[];

        if (kind == 'alert' && id.isNotEmpty) {
          actions.add(
            TextButton(
              onPressed: () => onResolveAlert(id),
              child: const Text('Resolve'),
            ),
          );
        }

        if (kind == 'campaign' && id.isNotEmpty && _read(item, 'status') != 'ACTIVE') {
          actions.add(
            TextButton(
              onPressed: () => onActivateCampaign(id),
              child: const Text('Activate'),
            ),
          );
        }

        return _ActionRow(
          title: _firstNonEmpty([
            _read(item, 'title'),
            _read(item, 'label'),
            _read(item, 'type'),
          ], fallback: 'Needs review'),
          status: status,
          subtitle: _joinNonEmpty([
            _read(item, 'status'),
            _read(item, 'source'),
            _read(item, 'createdAt'),
          ]),
          actions: actions,
        );
      }).toList(),
    );
  }
}

class _DispatchList extends StatelessWidget {
  const _DispatchList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No dispatch activity is visible.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _firstNonEmpty([
                  _read(item, 'subject'),
                  _read(item, 'templateName'),
                ], fallback: 'Dispatch'),
                subtitle: _joinNonEmpty([
                  _read(item, 'status'),
                  _read(item, 'recipientEmail'),
                  _read(item, 'createdAt'),
                  _read(item, 'sentAt'),
                ]),
              ))
          .toList(),
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({
    required this.items,
    required this.onActivateCampaign,
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function(String campaignId) onActivateCampaign;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No campaigns are available.');
    }

    return Column(
      children: items.take(8).map((item) {
        final id = _read(item, 'id');
        final status = _read(item, 'status');
        return _StatusRow(
          title: _read(item, 'name', fallback: 'Campaign'),
          subtitle: _joinNonEmpty([
            status,
            _read(item, 'channel'),
            _read(item, 'createdAt'),
          ]),
          actions: [
            if (id.isNotEmpty && status != 'ACTIVE')
              TextButton(
                onPressed: () => onActivateCampaign(id),
                child: const Text('Activate'),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _FailedJobList extends StatelessWidget {
  const _FailedJobList({
    required this.items,
    required this.onRunJob,
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function(String jobId) onRunJob;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No failed jobs are visible.');
    }

    return Column(
      children: items.take(8).map((item) {
        final id = _read(item, 'id');
        return _StatusRow(
          title: _read(item, 'type', fallback: 'Failed job'),
          subtitle: _joinNonEmpty([
            _read(item, 'status'),
            _read(item, 'error'),
            _read(item, 'updatedAt'),
          ]),
          actions: [
            if (id.isNotEmpty)
              TextButton(
                onPressed: () => onRunJob(id),
                child: const Text('Run now'),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _MailboxList extends StatelessWidget {
  const _MailboxList({
    required this.items,
    required this.onRefreshMailbox,
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function(String mailboxId) onRefreshMailbox;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No mailboxes are visible.');
    }

    return Column(
      children: items.take(8).map((item) {
        final id = _read(item, 'id');
        return _StatusRow(
          title: _firstNonEmpty([
            _read(item, 'emailAddress'),
            _read(item, 'label'),
          ], fallback: 'Mailbox'),
          subtitle: _joinNonEmpty([
            _read(item, 'healthStatus'),
            _read(item, 'status'),
            _read(item, 'provider'),
          ]),
          actions: [
            if (id.isNotEmpty)
              TextButton(
                onPressed: () => onRefreshMailbox(id),
                child: const Text('Refresh'),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _ClientList extends StatelessWidget {
  const _ClientList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No clients are available.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _firstNonEmpty([
                  _read(item, 'displayName'),
                  _read(item, 'legalName'),
                ], fallback: 'Client'),
                subtitle: _joinNonEmpty([
                  _read(item, 'status'),
                  _read(item, 'subscriptionStatus'),
                  _read(item, 'selectedPlan'),
                  _read(item, 'industry'),
                ]),
              ))
          .toList(),
    );
  }
}

class _InquiryList extends StatelessWidget {
  const _InquiryList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(message: 'No open inquiries are visible.');
    }

    return Column(
      children: items
          .take(8)
          .map((item) => _StatusRow(
                title: _firstNonEmpty([
                  _read(item, 'subject'),
                  _read(item, 'name'),
                ], fallback: 'Inquiry'),
                subtitle: _joinNonEmpty([
                  _read(item, 'status'),
                  _read(item, 'email'),
                  _read(item, 'createdAt'),
                ]),
              ))
          .toList(),
    );
  }
}

class _WorkspacePosture extends StatelessWidget {
  const _WorkspacePosture({required this.summary});

  final _CommandSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(
          title: 'Client footprint',
          subtitle: '${summary.totalClients} clients in view',
        ),
        _StatusRow(
          title: 'Campaign footprint',
          subtitle: '${summary.totalCampaigns} campaigns in view',
        ),
        _StatusRow(
          title: 'Failure pressure',
          subtitle: '${summary.failedJobs} failed jobs and ${summary.openAlerts} open alerts',
        ),
        _StatusRow(
          title: 'Mailbox posture',
          subtitle:
              '${summary.healthyMailboxes} healthy and ${summary.degradedMailboxes} degraded',
        ),
      ],
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({
    required this.totals,
    required this.deliverability,
    required this.deliverabilityPulse,
  });

  final Map<String, dynamic> totals;
  final Map<String, dynamic> deliverability;
  final Map<String, dynamic> deliverabilityPulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(
          title: 'Organizations in view',
          subtitle: _read(totals, 'organizations', fallback: '0'),
        ),
        _StatusRow(
          title: 'Clients in system',
          subtitle: _read(totals, 'clients', fallback: '0'),
        ),
        _StatusRow(
          title: 'Campaigns in system',
          subtitle: _read(totals, 'campaigns', fallback: '0'),
        ),
        _StatusRow(
          title: 'Healthy mailboxes',
          subtitle: _read(
            deliverabilityPulse,
            'healthyMailboxes',
            fallback: _read(deliverability, 'healthyMailboxes', fallback: '0'),
          ),
        ),
        _StatusRow(
          title: 'Degraded mailboxes',
          subtitle: _read(
            deliverabilityPulse,
            'degradedMailboxes',
            fallback: _read(deliverability, 'degradedMailboxes', fallback: '0'),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.status,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String status;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _statusTone(theme, status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tone.pill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle.isEmpty ? 'No detail available.' : subtitle,
            style: theme.textTheme.bodyMedium,
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _StatusTone {
  const _StatusTone({
    required this.background,
    required this.border,
    required this.pill,
  });

  final Color background;
  final Color border;
  final Color pill;
}

_StatusTone _statusTone(ThemeData theme, String status) {
  final value = status.toLowerCase();
  if (value.contains('critical') || value.contains('failed')) {
    final base = theme.colorScheme.error;
    return _StatusTone(
      background: base.withOpacity(0.10),
      border: base.withOpacity(0.28),
      pill: base.withOpacity(0.18),
    );
  }
  if (value.contains('warning') || value.contains('degraded')) {
    final base = theme.colorScheme.tertiary;
    return _StatusTone(
      background: base.withOpacity(0.10),
      border: base.withOpacity(0.24),
      pill: base.withOpacity(0.18),
    );
  }
  final base = theme.colorScheme.primary;
  return _StatusTone(
    background: base.withOpacity(0.08),
    border: base.withOpacity(0.18),
    pill: base.withOpacity(0.16),
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle.isEmpty ? 'No detail available.' : subtitle,
            style: theme.textTheme.bodyMedium,
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(message),
    );
  }
}

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class _CommandSummary {
  const _CommandSummary({
    required this.sentToday,
    required this.repliesToday,
    required this.bookedToday,
    required this.failedJobs,
    required this.healthyMailboxes,
    required this.degradedMailboxes,
    required this.totalClients,
    required this.totalCampaigns,
    required this.openAlerts,
  });

  final String sentToday;
  final String repliesToday;
  final String bookedToday;
  final String failedJobs;
  final String healthyMailboxes;
  final String degradedMailboxes;
  final String totalClients;
  final String totalCampaigns;
  final String openAlerts;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _read(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final value = map[key];
  if (value == null) return fallback;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  return '$value';
}

String _joinNonEmpty(List<String> parts) {
  return parts.where((item) => item.trim().isNotEmpty).join(' • ');
}

String _firstNonEmpty(List<String> parts, {String fallback = ''}) {
  for (final part in parts) {
    if (part.trim().isNotEmpty) return part;
  }
  return fallback;
}
