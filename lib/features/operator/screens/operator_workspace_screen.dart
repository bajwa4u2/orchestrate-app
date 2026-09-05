import 'package:flutter/material.dart';

import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/operator_repository.dart';

// `campaigns` and `clients` are intentionally absent — the legacy
// operator Campaigns / Clients panels were superseded by the
// runtime-backed campaign-lifecycle surface (/ops/continuity/campaigns)
// and their routes already redirect there.
enum OperatorSection {
  command,
  pipeline,
  inquiries,
  replies,
  meetings,
  revenue,
  deliverability,
  communications,
  records,
  activity,
  execution,
  analytics,
  settings,
}

class OperatorWorkspaceScreen extends StatefulWidget {
  const OperatorWorkspaceScreen({super.key, required this.section});

  final OperatorSection section;

  @override
  State<OperatorWorkspaceScreen> createState() =>
      _OperatorWorkspaceScreenState();
}

class _OperatorWorkspaceScreenState extends State<OperatorWorkspaceScreen> {
  late Future<_OperatorData> _future;
  String? _actionMessage;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.section);
  }

  @override
  void didUpdateWidget(covariant OperatorWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _future = _load(widget.section);
      _actionMessage = null;
    }
  }

  Future<void> _refresh() async {
    final next = _load(widget.section);
    setState(() => _future = next);
    await next;
  }

  Future<void> _dispatchDueJobs() async {
    setState(() {
      _actionInFlight = true;
      _actionMessage = null;
    });
    try {
      final result = await OperatorRepository().dispatchDueJobs();
      if (!mounted) return;
      setState(() {
        _actionMessage =
            'Due work dispatch completed. ${_summarizeActionResult(result)}';
      });
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionMessage =
            'Dispatch could not run at the moment. This may require setup or operator permission.';
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OperatorData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _refresh);
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(
              child: Text('This area could not load at the moment.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.runtimeMetrics != null) ...[
                _RuntimeMetricsPanel(metrics: data.runtimeMetrics!),
                const SizedBox(height: 18),
              ],
              _ActionPanel(
                inFlight: _actionInFlight,
                message: _actionMessage,
                onDispatchDue: _dispatchDueJobs,
                onRefresh: _refresh,
                commandMode: widget.section == OperatorSection.command,
              ),
              const SizedBox(height: 18),
              _Metrics(metrics: data.metrics),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < WorkspaceBreakpoints.stacked;
                  final left = _Panel(
                    title: data.primaryTitle,
                    rows: data.primaryRows,
                    empty: data.primaryEmpty,
                  );
                  final right = _Panel(
                    title: data.secondaryTitle,
                    rows: data.secondaryRows,
                    empty: data.secondaryEmpty,
                  );

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
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: right),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_RuntimeMetrics?> _safeRuntimeMetrics(OperatorRepository repo) async {
    try {
      final json = await repo.fetchRuntimeMetrics();
      return _RuntimeMetrics.fromJson(json);
    } catch (_) {
      // Honest: when the operator runtime-metrics endpoint cannot
      // load, we omit the panel rather than rendering placeholder
      // numbers. The rest of the command surface stays available.
      return null;
    }
  }

  Future<_OperatorData> _load(OperatorSection section) async {
    final repo = OperatorRepository();

    switch (section) {
      case OperatorSection.command:
        final workspace = await repo.fetchCommandWorkspace();
        final runtimeMetrics = await _safeRuntimeMetrics(repo);
        final pulse = _asMap(workspace['pulse']);
        final totals = _asMap(pulse['totals']);
        final today = _asMap(pulse['today']);
        final execution = _asMap(pulse['execution']);
        final deliverabilityPulse = _asMap(pulse['deliverability']);
        final health = _asMap(workspace['health']);
        final alerts = _alertsFrom(health['alerts']);
        final attention = _rowsFromList(
          workspace['attention'],
          titleKeys: const ['title', 'label', 'type'],
          primaryKeys: const ['severity', 'status'],
          secondaryKeys: const ['source', 'createdAt'],
        );
        return _OperatorData(
          runtimeMetrics: runtimeMetrics,
          metrics: [
            _Metric('Sent today', _read(today, 'sent', fallback: '0')),
            _Metric('Replies', _read(today, 'replies', fallback: '0')),
            _Metric('Booked', _read(today, 'booked', fallback: '0')),
            _Metric(
                'Failed jobs', _read(execution, 'failedJobs', fallback: '0')),
          ],
          primaryTitle: 'Needs attention',
          primaryRows: attention,
          primaryEmpty: 'Nothing urgent is open at the moment.',
          secondaryTitle: 'System posture',
          secondaryRows: [
            _Row(
              title: 'Organizations in view',
              primary: _read(totals, 'organizations', fallback: '0'),
            ),
            _Row(
              title: 'Clients in view',
              primary: _read(totals, 'clients', fallback: '0'),
            ),
            _Row(
              title: 'Healthy mailboxes',
              primary: _read(
                deliverabilityPulse,
                'healthyMailboxes',
                fallback: _read(health, 'healthyMailboxes', fallback: '0'),
              ),
              secondary:
                  '${_read(deliverabilityPulse, 'degradedMailboxes', fallback: '0')} degraded',
            ),
            _Row(
              title: 'Open alerts',
              primary: '${alerts.open} open',
              secondary: '${alerts.critical} critical',
            ),
          ],
          secondaryEmpty: 'No system posture in this organisation.',
        );

      case OperatorSection.pipeline:
        final leads = await repo.fetchLeads();
        final campaigns = await repo.fetchCampaigns();
        return _OperatorData(
          metrics: [
            _Metric('Leads', '${leads.length}'),
            _Metric('Campaigns', '${campaigns.length}'),
          ],
          primaryTitle: 'Lead queue',
          primaryRows: leads
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['fullName', 'name'],
                  primaryKeys: const ['companyName', 'status'],
                  secondaryKeys: const ['email'],
                ),
              )
              .toList(),
          primaryEmpty: 'No leads in this organisation.',
          secondaryTitle: 'Campaign intake',
          secondaryRows: campaigns
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['name'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['channel', 'createdAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No campaigns in this organisation.',
        );

      case OperatorSection.inquiries:
        final inquiries = await repo.fetchInquiries(limit: 12);
        final items = (inquiries['items'] as List? ?? const []).cast<dynamic>();
        return _OperatorData(
          metrics: [
            _Metric('Open', _countByStatus(items, 'open')),
            _Metric('In progress', _countByStatus(items, 'in_progress')),
            _Metric('Closed', _countByStatus(items, 'closed')),
          ],
          primaryTitle: 'Inquiry queue',
          primaryRows: items
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['subject', 'name'],
                  primaryKeys: const ['status', 'type'],
                  secondaryKeys: const ['email', 'createdAt'],
                ),
              )
              .toList(),
          primaryEmpty: 'No inquiries in this organisation. Inquiries reach the '
              'business they were sent to, and are read there.',
          secondaryTitle: 'Recent contact',
          secondaryRows: items
              .take(6)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['name', 'subject'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['createdAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No recent contact in this organisation.',
        );

      case OperatorSection.replies:
        final replies = await repo.fetchReplies();
        final meetings = await repo.fetchMeetings();
        return _OperatorData(
          metrics: [
            _Metric('Replies', '${replies.length}'),
            _Metric('Meetings', '${meetings.length}'),
          ],
          primaryTitle: 'Reply queue',
          primaryRows: replies
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['subject', 'fromEmail'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['fromEmail', 'receivedAt'],
                ),
              )
              .toList(),
          primaryEmpty: 'No replies in this organisation.',
          secondaryTitle: 'Meeting cues',
          secondaryRows: meetings
              .take(6)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['title'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['scheduledAt', 'timezone'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No meeting cues in this organisation.',
        );

      case OperatorSection.meetings:
        final meetings = await repo.fetchMeetings();
        final clients = await repo.fetchClients();
        return _OperatorData(
          metrics: [
            _Metric('Meetings', '${meetings.length}'),
            _Metric('Clients', '${clients.length}'),
          ],
          primaryTitle: 'Meeting schedule',
          primaryRows: meetings
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['title'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['scheduledAt', 'timezone'],
                ),
              )
              .toList(),
          primaryEmpty: 'No meetings in this organisation.',
          secondaryTitle: 'Client standing',
          secondaryRows: clients
              .take(6)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['displayName', 'legalName'],
                  primaryKeys: const ['subscriptionStatus', 'status'],
                  secondaryKeys: const ['selectedPlan', 'primaryTimezone'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No client standing in this organisation.',
        );

      case OperatorSection.revenue:
        final overview = await repo.fetchRevenueOverview();
        final invoices = await repo.fetchInvoices();
        final subscriptions = await repo.fetchSubscriptions();
        return _OperatorData(
          metrics: [
            _Metric('Invoices', '${invoices.length}'),
            _Metric('Subscriptions', '${subscriptions.length}'),
            _Metric('Outstanding',
                _money(_asMap(overview['totals'])['outstandingCents'])),
          ],
          primaryTitle: 'Invoices',
          primaryRows: invoices
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['invoiceNumber'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['dueDate'],
                ),
              )
              .toList(),
          primaryEmpty: 'No invoices in this organisation.',
          secondaryTitle: 'Subscriptions',
          secondaryRows: subscriptions
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['externalRef'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['createdAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No subscriptions in this organisation.',
        );

      case OperatorSection.deliverability:
        final overview = await repo.fetchDeliverabilityOverview();
        final mailboxes =
            (overview['mailboxes'] as List? ?? const []).cast<dynamic>();
        final healthyMailboxes = mailboxes.where((item) {
          final map = _asMap(item);
          final health = _read(map, 'healthStatus').toUpperCase();
          return health != 'DEGRADED' && health != 'CRITICAL';
        }).length;
        final degradedMailboxes = mailboxes.length - healthyMailboxes;
        return _OperatorData(
          metrics: [
            _Metric('Mailboxes', '${mailboxes.length}'),
            _Metric('Healthy', '$healthyMailboxes'),
            _Metric('Degraded', '$degradedMailboxes'),
          ],
          primaryTitle: 'Mailbox standing',
          primaryRows: mailboxes
              .take(10)
              .map((item) => _mapRow(
                    item,
                    titleKeys: const ['emailAddress', 'email', 'label'],
                    primaryKeys: const [
                      'connectionState',
                      'healthStatus',
                      'status'
                    ],
                    secondaryKeys: const ['provider', 'updatedAt'],
                  ))
              .toList(),
          primaryEmpty: 'No delivery history in this organisation.',
          secondaryTitle: 'Sending posture',
          secondaryRows: [
            _Row(
              title: 'Healthy mailboxes',
              primary: '$healthyMailboxes',
              secondary: '$degradedMailboxes degraded or critical',
            ),
            const _Row(
              title: 'Operator action',
              primary: 'Refresh health or reconnect mailboxes from Ops Debug.',
            ),
          ],
          secondaryEmpty: 'No posture note in this organisation.',
        );

      case OperatorSection.communications:
        final emails = await repo.fetchEmailDispatches();
        final inquiries = await repo.fetchInquiries(limit: 6);
        final inquiryItems =
            (inquiries['items'] as List? ?? const []).cast<dynamic>();
        return _OperatorData(
          metrics: [
            _Metric('Dispatches', '${emails.length}'),
            _Metric('Inquiries', '${inquiryItems.length}'),
          ],
          primaryTitle: 'Dispatch history',
          primaryRows: emails
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['subject'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['sentAt', 'recipientEmail'],
                ),
              )
              .toList(),
          primaryEmpty: 'No dispatches in this organisation.',
          secondaryTitle: 'Recent inquiries',
          secondaryRows: inquiryItems
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['name', 'subject'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['email'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No inquiries in this organisation.',
        );

      case OperatorSection.records:
        final overview = await repo.fetchRecordsOverview();
        final agreements = await repo.fetchAgreements();
        final statements = await repo.fetchStatements();
        return _OperatorData(
          metrics: [
            _Metric('Agreements', '${agreements.length}'),
            _Metric('Statements', '${statements.length}'),
          ],
          primaryTitle: 'Record summary',
          primaryRows: [
            _Row(title: 'Stored agreements', primary: '${agreements.length}'),
            _Row(title: 'Stored statements', primary: '${statements.length}'),
            _Row(
              title: 'Overview note',
              primary: _read(overview, 'summary',
                  fallback: 'Record overview available'),
            ),
          ],
          primaryEmpty: 'No record summary in this organisation.',
          secondaryTitle: 'Recent artifacts',
          secondaryRows: [
            ...agreements.take(4).map(
                  (item) => _mapRow(
                    item,
                    titleKeys: const ['title'],
                    primaryKeys: const ['status'],
                    secondaryKeys: const ['updatedAt'],
                  ),
                ),
            ...statements.take(4).map(
                  (item) => _mapRow(
                    item,
                    titleKeys: const ['statementNumber'],
                    primaryKeys: const ['status'],
                    secondaryKeys: const ['periodEnd'],
                  ),
                ),
          ],
          secondaryEmpty: 'No artifacts in this organisation.',
        );

      case OperatorSection.activity:
        final activity = await repo.fetchActivity(limit: 50);
        final items = (activity['items'] as List? ?? const []).cast<dynamic>();
        final summary = _asMap(activity['summary']);
        final byKind = _asMap(summary['byKind']);
        return _OperatorData(
          metrics: [
            _Metric('Visible events', '${items.length}'),
            _Metric('Messages', _read(byKind, 'MESSAGE_SENT', fallback: '0')),
            _Metric('Replies', _read(byKind, 'REPLY_RECEIVED', fallback: '0')),
          ],
          primaryTitle: 'Recent activity',
          primaryRows: items
              .take(14)
              .map((item) => _mapRow(
                    item,
                    titleKeys: const ['summary', 'kind'],
                    primaryKeys: const ['kind', 'visibility'],
                    secondaryKeys: const [
                      'clientName',
                      'campaignName',
                      'createdAt'
                    ],
                  ))
              .toList(),
          primaryEmpty: 'No activity events in this organisation.',
          secondaryTitle: 'Activity mix',
          secondaryRows: byKind.entries
              .take(10)
              .map((entry) => _Row(title: entry.key, primary: '${entry.value}'))
              .toList(),
          secondaryEmpty: 'No activity mix is available yet.',
        );

      case OperatorSection.execution:
        final execution = await repo.fetchExecutionWorkspace(limit: 50);
        final items = (execution['items'] as List? ?? const []).cast<dynamic>();
        final recentRuns =
            (execution['recentRuns'] as List? ?? const []).cast<dynamic>();
        final summary = _asMap(execution['summary']);
        final byStatus = _asMap(summary['byStatus']);
        return _OperatorData(
          metrics: [
            _Metric('Queued', _read(byStatus, 'QUEUED', fallback: '0')),
            _Metric('Running', _read(byStatus, 'RUNNING', fallback: '0')),
            _Metric('Failed', _read(byStatus, 'FAILED', fallback: '0')),
          ],
          primaryTitle: 'Recent jobs',
          primaryRows: items
              .take(14)
              .map((item) => _mapRow(
                    item,
                    titleKeys: const ['type', 'id'],
                    primaryKeys: const ['status', 'queueName'],
                    secondaryKeys: const [
                      'clientName',
                      'campaignName',
                      'updatedAt'
                    ],
                  ))
              .toList(),
          primaryEmpty: 'No jobs are visible.',
          secondaryTitle: 'Recent worker runs',
          secondaryRows: recentRuns
              .take(10)
              .map((item) => _mapRow(
                    item,
                    titleKeys: const ['type', 'jobId'],
                    primaryKeys: const ['status', 'queueName'],
                    secondaryKeys: const ['campaignName', 'startedAt'],
                  ))
              .toList(),
          secondaryEmpty: 'No worker runs are visible.',
        );

      case OperatorSection.analytics:
        final campaigns = await repo.fetchCampaigns();
        final emails = await repo.fetchEmailDispatches();
        final replies = await repo.fetchReplies();
        final meetings = await repo.fetchMeetings();
        final revenue = await repo.fetchRevenueOverview();
        final sent = emails.where((item) {
          final status = _read(_asMap(item), 'status').toUpperCase();
          return status == 'SENT';
        }).length;
        final failed = emails.where((item) {
          final status = _read(_asMap(item), 'status').toUpperCase();
          return status == 'FAILED' || status == 'BOUNCED';
        }).length;
        return _OperatorData(
          metrics: [
            _Metric('Campaigns', '${campaigns.length}'),
            _Metric('Sent', '$sent'),
            _Metric('Replies', '${replies.length}'),
            _Metric('Meetings', '${meetings.length}'),
          ],
          primaryTitle: 'Campaign performance cues',
          primaryRows: [
            _Row(title: 'Dispatches sent', primary: '$sent'),
            _Row(title: 'Dispatch failures', primary: '$failed'),
            _Row(
              title: 'Reply to meeting signal',
              primary: replies.isEmpty
                  ? 'No replies yet'
                  : '${meetings.length} meetings from ${replies.length} replies',
            ),
            _Row(
              title: 'Outstanding revenue',
              primary: _money(_asMap(revenue['totals'])['outstandingCents']),
            ),
          ],
          primaryEmpty: 'No analytics signals in this organisation.',
          secondaryTitle: 'Active campaigns',
          secondaryRows: campaigns
              .take(10)
              .map((item) => _mapRow(
                    item,
                    titleKeys: const ['name'],
                    primaryKeys: const ['status'],
                    secondaryKeys: const ['updatedAt', 'createdAt'],
                  ))
              .toList(),
          secondaryEmpty: 'No campaign analytics in this organisation.',
        );

      case OperatorSection.settings:
        final auth = await repo.fetchAuthContext();
        return _OperatorData(
          metrics: [
            _Metric('Workspace', _read(auth, 'surface', fallback: 'operator'))
          ],
          primaryTitle: 'Access context',
          primaryRows: [
            _Row(
              title: 'Workspace',
              primary: _read(auth, 'surface', fallback: 'operator'),
            ),
            _Row(title: 'Organization', primary: _read(auth, 'organizationId')),
          ],
          primaryEmpty: 'No access context in this organisation.',
          secondaryTitle: 'Posture',
          secondaryRows: const [
            _Row(
              title: 'Note',
              primary:
                  'Keep operator changes controlled, visible, and tied to the live system.',
            ),
          ],
          secondaryEmpty: 'No notes in this organisation.',
        );
    }
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A ROW OF THREE THAT BECAME A COLUMN OF THREE NARROW BOXES.
        //
        // The old rule was all-in-a-row above 880 and stacked below it, and the
        // stacked branch never stretched — so at the console's own width the
        // counts rendered as a ragged left-hand column of small tiles with the
        // rest of the surface empty beside them. Wrapping into as many even
        // columns as the width holds fits every width, including the one the
        // shell actually has.
        const gap = 12.0;
        final width = constraints.maxWidth;
        final columns = width >= 780
            ? metrics.length
            : width >= 520
                ? 2
                : 1;
        final cell = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(width: cell, child: _MetricCard(metric: metric)),
          ],
        );
      },
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.inFlight,
    required this.message,
    required this.onDispatchDue,
    required this.onRefresh,
    required this.commandMode,
  });

  final bool inFlight;
  final String? message;
  final VoidCallback onDispatchDue;
  final VoidCallback onRefresh;
  final bool commandMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < WorkspaceBreakpoints.compact;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operator controls',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                message ??
                    (commandMode
                        ? 'Recovery controls. Each one says what it did, and '
                            'says so plainly when it could not do it.'
                        : 'Counts are read fresh each time this is refreshed. '
                            'Nothing here changes anything on its own.'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.subdued),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (commandMode)
                FilledButton.icon(
                  onPressed: inFlight ? null : onDispatchDue,
                  icon: inFlight
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_outlined),
                  label: const Text('Dispatch due work'),
                ),
              OutlinedButton.icon(
                onPressed: inFlight ? null : onRefresh,
                icon: const Icon(Icons.refresh_outlined),
                label: Text(commandMode ? 'Refresh command' : 'Refresh view'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 14), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(metric.value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _RuntimeMetricsPanel extends StatelessWidget {
  const _RuntimeMetricsPanel({required this.metrics});

  final _RuntimeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Runtime metrics',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Per-client execution state across the org. "Ready" is not "dispatching". Categories below come from the same runtime model the client home uses.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.subdued),
          ),
          const SizedBox(height: 14),
          _runtimeGrid(context),
          const SizedBox(height: 14),
          _activityRow(context),
        ],
      ),
    );
  }

  Widget _runtimeGrid(BuildContext context) {
    final cards = <_RuntimeStateCard>[
      _RuntimeStateCard(
        label: 'Actively dispatching',
        value: metrics.dispatching,
        hint: 'Queue activity within the last hour',
        tone: _Tone.positive,
      ),
      _RuntimeStateCard(
        label: 'Ready, idle',
        value: metrics.readyIdle,
        hint: 'Eligible but no in-flight messages',
        tone: _Tone.neutral,
      ),
      _RuntimeStateCard(
        label: 'Awaiting workload',
        value: metrics.awaitingWorkload,
        hint: 'Active campaign, no qualified leads',
        tone: _Tone.neutral,
      ),
      _RuntimeStateCard(
        label: 'Awaiting campaign',
        value: metrics.awaitingApproval,
        hint: 'Readiness passed, no ACTIVE campaign',
        tone: _Tone.neutral,
      ),
      _RuntimeStateCard(
        label: 'Degraded',
        value: metrics.degraded,
        hint: 'Recent failures dominate sends',
        tone: _Tone.critical,
      ),
      _RuntimeStateCard(
        label: 'Recovering',
        value: metrics.recovering,
        hint: 'Queued, no recent sends',
        tone: _Tone.cautious,
      ),
      _RuntimeStateCard(
        label: 'Governance-blocked',
        value: metrics.governanceBlocked,
        hint: 'All recent dispatch held by review',
        tone: _Tone.cautious,
      ),
      _RuntimeStateCard(
        label: 'Rate-limited',
        value: metrics.rateLimited,
        hint: 'Send-policy cap reached',
        tone: _Tone.cautious,
      ),
      _RuntimeStateCard(
        label: 'Provider-blocked',
        value: metrics.providerBlocked,
        hint: 'Mailbox auth missing/expired',
        tone: _Tone.cautious,
      ),
      _RuntimeStateCard(
        label: 'Paused (subscription)',
        value: metrics.paused,
        hint: 'Billing gates new dispatch',
        tone: _Tone.cautious,
      ),
      _RuntimeStateCard(
        label: 'Not ready',
        value: metrics.notReady,
        hint: 'Readiness layer has not verified',
        tone: _Tone.critical,
      ),
      _RuntimeStateCard(
        label: 'Unknown / insufficient data',
        value: metrics.unknown,
        hint: 'No readiness snapshot available',
        tone: _Tone.neutral,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 720 ? 2 : (constraints.maxWidth < 1200 ? 3 : 4);
        final rows = <Widget>[];
        for (int i = 0; i < cards.length; i += columns) {
          final row = <Widget>[];
          for (int c = 0; c < columns; c++) {
            if (i + c >= cards.length) {
              row.add(const Expanded(child: SizedBox.shrink()));
            } else {
              row.add(Expanded(child: _RuntimeStateTile(card: cards[i + c])));
            }
            if (c != columns - 1) row.add(const SizedBox(width: 10));
          }
          rows.add(Row(children: row));
          if (i + columns < cards.length) rows.add(const SizedBox(height: 10));
        }
        return Column(children: rows);
      },
    );
  }

  Widget _activityRow(BuildContext context) {
    final pieces = <String>[
      '${metrics.totalClients} client${metrics.totalClients == 1 ? '' : 's'} in scope',
      '${metrics.recentSent} sent (last hour)',
      '${metrics.recentFailed} failed (last hour)',
      '${metrics.queueDepth} in queue right now',
      '${metrics.governanceReviewQueue} in operator review',
    ];
    return Text(
      pieces.join('  ·  '),
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppTheme.subdued),
    );
  }
}

enum _Tone { positive, neutral, cautious, critical }

class _RuntimeStateCard {
  const _RuntimeStateCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.tone,
  });

  final String label;
  final int value;
  final String hint;
  final _Tone tone;
}

class _RuntimeStateTile extends StatelessWidget {
  const _RuntimeStateTile({required this.card});

  final _RuntimeStateCard card;

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    switch (card.tone) {
      case _Tone.positive:
        borderColor = Colors.green.shade400;
        break;
      case _Tone.cautious:
        borderColor = Colors.orange.shade400;
        break;
      case _Tone.critical:
        borderColor = Colors.red.shade400;
        break;
      case _Tone.neutral:
        borderColor = AppTheme.lineSoft;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.subdued,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${card.value}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            card.hint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.subdued),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).displayMessage
        : 'This area could not load at the moment.';
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operational data unavailable',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.subdued),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.rows, required this.empty});

  final String title;
  final List<_Row> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(empty, style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < rows.length; i++) ...[
              _RowTile(row: rows[i]),
              if (i != rows.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panelRaised,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(row.primary, style: Theme.of(context).textTheme.bodyLarge),
          if (row.secondary != null && row.secondary!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              row.secondary!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.subdued),
            ),
          ],
        ],
      ),
    );
  }
}

class _OperatorData {
  const _OperatorData({
    required this.metrics,
    required this.primaryTitle,
    required this.primaryRows,
    required this.primaryEmpty,
    required this.secondaryTitle,
    required this.secondaryRows,
    required this.secondaryEmpty,
    this.runtimeMetrics,
  });

  final List<_Metric> metrics;
  final String primaryTitle;
  final List<_Row> primaryRows;
  final String primaryEmpty;
  final String secondaryTitle;
  final List<_Row> secondaryRows;
  final String secondaryEmpty;
  final _RuntimeMetrics? runtimeMetrics;
}

/// Operator runtime metrics returned by /operator/runtime-metrics.
/// Counts are runtime-derived (per closed-enum ExecutionState).
class _RuntimeMetrics {
  const _RuntimeMetrics({
    required this.totalClients,
    required this.byState,
    required this.recentSent,
    required this.recentFailed,
    required this.queueDepth,
    required this.governanceReviewQueue,
  });

  factory _RuntimeMetrics.fromJson(Map<String, dynamic> json) {
    final byState = _asMap(json['byState']);
    final activity = _asMap(json['activity']);
    final counts = <String, int>{};
    byState.forEach((key, value) {
      final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      counts[key.toString()] = n;
    });
    int readInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return _RuntimeMetrics(
      totalClients: readInt(json['totalClients']),
      byState: counts,
      recentSent: readInt(activity['recentSent']),
      recentFailed: readInt(activity['recentFailed']),
      queueDepth: readInt(activity['queueDepth']),
      governanceReviewQueue: readInt(json['governanceReviewQueue']),
    );
  }

  final int totalClients;
  final Map<String, int> byState;
  final int recentSent;
  final int recentFailed;
  final int queueDepth;
  final int governanceReviewQueue;

  int countOf(String state) => byState[state] ?? 0;

  int get readyIdle => countOf('READY_IDLE');
  int get awaitingWorkload => countOf('READY_AWAITING_WORKLOAD');
  int get awaitingApproval => countOf('READY_AWAITING_APPROVAL');
  int get dispatching => countOf('DISPATCHING');
  int get degraded => countOf('DEGRADED');
  int get recovering => countOf('RECOVERING');
  int get notReady => countOf('NOT_READY');
  int get paused => countOf('PAUSED');
  int get providerBlocked => countOf('PROVIDER_BLOCKED');
  int get governanceBlocked => countOf('GOVERNANCE_BLOCKED');
  int get rateLimited => countOf('RATE_LIMITED');
  int get unknown => countOf('UNKNOWN');
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}

class _Row {
  const _Row({required this.title, required this.primary, this.secondary});

  final String title;
  final String primary;
  final String? secondary;
}

_Row _mapRow(
  dynamic raw, {
  required List<String> titleKeys,
  List<String> primaryKeys = const [],
  List<String> secondaryKeys = const [],
}) {
  final map = _asMap(raw);
  final title = _firstValue(map, titleKeys, fallback: 'Untitled');
  final primary = _joinKeys(map, primaryKeys, fallback: 'No detail');
  final secondary = _joinKeys(map, secondaryKeys);
  return _Row(title: title, primary: primary, secondary: secondary);
}

List<_Row> _rowsFromList(
  dynamic raw, {
  required List<String> titleKeys,
  List<String> primaryKeys = const [],
  List<String> secondaryKeys = const [],
}) {
  return (raw as List? ?? const [])
      .take(8)
      .map((item) => _mapRow(
            item,
            titleKeys: titleKeys,
            primaryKeys: primaryKeys,
            secondaryKeys: secondaryKeys,
          ))
      .toList();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

String _joinKeys(
  Map<String, dynamic> map,
  List<String> keys, {
  String? fallback,
}) {
  final values = keys
      .map((key) => _read(map, key))
      .where((value) => value.trim().isNotEmpty)
      .toList();

  if (values.isEmpty) return fallback ?? '';
  return values.join(' · ');
}

String _firstValue(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _read(map, key);
    if (value.trim().isNotEmpty) return value;
  }
  return fallback;
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
    return trimmed.isEmpty ? fallback : humaniseEnum(trimmed);
  }
  return '$value';
}

/// Acronyms that are already how a person would write them.
const _acronyms = {
  'DNS', 'SPF', 'DKIM', 'DMARC', 'API', 'URL', 'ID', 'AI', 'MX', 'TLS',
  'SMTP', 'IMAP', 'CSV', 'PDF', 'UTC', 'SLA', 'VAT', 'ETA', 'HTML',
};

/// ACKNOWLEDGED reaches the screen as ACKNOWLEDGED.
///
/// These are database values, and a person reading an inquiry queue is not
/// reading a database. Shouting a status at them in a font size chosen for
/// calm text is the smallest kind of drift and the most visible: every list
/// in the console carries one. Names, sentences and numbers pass through
/// untouched — only a value that is entirely upper case is a value that came
/// from an enum.
String humaniseEnum(String value) {
  if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(value)) return value;
  if (_acronyms.contains(value)) return value;
  final words = value.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return value;
  return [
    for (int i = 0; i < words.length; i++)
      if (i == 0 || _acronyms.contains(words[i]))
        (_acronyms.contains(words[i])
            ? words[i]
            : words[i][0] + words[i].substring(1).toLowerCase())
      else
        words[i].toLowerCase(),
  ].join(' ');
}

_AlertSummary _alertsFrom(dynamic raw) {
  if (raw is Map) {
    final map = _asMap(raw);
    return _AlertSummary(
      open: _read(map, 'open', fallback: '0'),
      critical: _read(map, 'critical', fallback: '0'),
    );
  }

  if (raw is List) {
    int open = 0;
    int critical = 0;
    for (final item in raw) {
      final map = _asMap(item);
      final resolved = _read(map, 'resolved').toLowerCase();
      final severity = _read(map, 'severity').toLowerCase();
      if (resolved != 'true') open += 1;
      if (severity == 'critical') critical += 1;
    }
    return _AlertSummary(open: '$open', critical: '$critical');
  }

  return const _AlertSummary(open: '0', critical: '0');
}

class _AlertSummary {
  const _AlertSummary({required this.open, required this.critical});

  final String open;
  final String critical;
}

String _money(dynamic cents) {
  if (cents is num) {
    final dollars = cents / 100;
    return '\$${dollars.toStringAsFixed(2)}';
  }
  return '\$0.00';
}

String _countByStatus(List<dynamic> items, String status) {
  final count = items.where((item) {
    final map = _asMap(item);
    return _read(map, 'status').toLowerCase() == status.toLowerCase();
  }).length;
  return '$count';
}

String _summarizeActionResult(Map<String, dynamic> result) {
  final parts = <String>[];
  for (final key in const [
    'processed',
    'queued',
    'ran',
    'completed',
    'failed'
  ]) {
    final value = result[key];
    if (value == null) continue;
    parts.add('$key: $value');
  }
  if (parts.isEmpty) return 'The system accepted the request.';
  return parts.join(' · ');
}
