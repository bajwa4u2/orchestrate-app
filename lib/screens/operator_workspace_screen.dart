import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/operator_repository.dart';

enum OperatorSection {
  command,
  pipeline,
  inquiries,
  campaigns,
  replies,
  meetings,
  clients,
  revenue,
  deliverability,
  communications,
  records,
  settings,
}

class OperatorWorkspaceScreen extends StatelessWidget {
  const OperatorWorkspaceScreen({super.key, required this.section});

  final OperatorSection section;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OperatorData>(
      future: _load(section),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'This area could not load right now.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('This area could not load right now.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(data: data),
              const SizedBox(height: 18),
              _Metrics(metrics: data.metrics),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
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

  Future<_OperatorData> _load(OperatorSection section) async {
    final repo = OperatorRepository();

    switch (section) {
      case OperatorSection.command:
        final workspace = await repo.fetchCommandWorkspace();
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
          eyebrow: 'Command',
          title: 'System pressure and operator visibility',
          subtitle:
              'Command is now the center of the workspace. Pressure, health, and movement stay visible from one surface.',
          metrics: [
            _Metric('Sent today', _read(today, 'sent', fallback: '0')),
            _Metric('Replies', _read(today, 'replies', fallback: '0')),
            _Metric('Booked', _read(today, 'booked', fallback: '0')),
            _Metric('Failed jobs', _read(execution, 'failedJobs', fallback: '0')),
          ],
          primaryTitle: 'Needs attention',
          primaryRows: attention,
          primaryEmpty: 'Nothing urgent is open right now.',
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
              secondary: '${_read(deliverabilityPulse, 'degradedMailboxes', fallback: '0')} degraded',
            ),
            _Row(
              title: 'Open alerts',
              primary: '${alerts.open} open',
              secondary: '${alerts.critical} critical',
            ),
          ],
          secondaryEmpty: 'No system posture is available.',
        );

      case OperatorSection.pipeline:
        final leads = await repo.fetchLeads();
        final campaigns = await repo.fetchCampaigns();
        return _OperatorData(
          eyebrow: 'Flow',
          title: 'Lead intake and campaign supply',
          subtitle:
              'This is the raw movement feeding execution. It should show what is entering the system and where it is pointed.',
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
          primaryEmpty: 'No leads are available.',
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
          secondaryEmpty: 'No campaigns are available.',
        );

      case OperatorSection.inquiries:
        final inquiries = await repo.fetchInquiries(limit: 12);
        final items = (inquiries['items'] as List? ?? const []).cast<dynamic>();
        return _OperatorData(
          eyebrow: 'Conversations',
          title: 'Inbound contact and handling queue',
          subtitle:
              'New contact should remain visible as active operator work, not as a detached inbox.',
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
          primaryEmpty: 'No inquiries are available.',
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
          secondaryEmpty: 'No recent contact is available.',
        );

      case OperatorSection.campaigns:
        final campaigns = await repo.fetchCampaigns();
        final dispatches = await repo.fetchEmailDispatches();
        return _OperatorData(
          eyebrow: 'Flow',
          title: 'Campaign movement and outbound pressure',
          subtitle:
              'Campaign work should show both state and evidence of movement, not just a static list.',
          metrics: [
            _Metric('Campaigns', '${campaigns.length}'),
            _Metric('Dispatches', '${dispatches.length}'),
          ],
          primaryTitle: 'Campaign list',
          primaryRows: campaigns
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['name'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['channel', 'createdAt'],
                ),
              )
              .toList(),
          primaryEmpty: 'No campaigns are available.',
          secondaryTitle: 'Recent dispatch movement',
          secondaryRows: dispatches
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['subject'],
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['recipientEmail', 'createdAt', 'sentAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No dispatch movement is available.',
        );

      case OperatorSection.replies:
        final replies = await repo.fetchReplies();
        final meetings = await repo.fetchMeetings();
        return _OperatorData(
          eyebrow: 'Conversations',
          title: 'Replies and handoff pressure',
          subtitle:
              'Reply work belongs close to handoff readiness so operator can judge when conversation becomes meeting work.',
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
          primaryEmpty: 'No replies are available.',
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
          secondaryEmpty: 'No meeting cues are available.',
        );

      case OperatorSection.meetings:
        final meetings = await repo.fetchMeetings();
        final clients = await repo.fetchClients();
        return _OperatorData(
          eyebrow: 'Conversations',
          title: 'Meetings and client readiness',
          subtitle:
              'Booked calls should stay tied to who is arriving and what standing they have in the system.',
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
          primaryEmpty: 'No meetings are available.',
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
          secondaryEmpty: 'No client standing is available.',
        );

      case OperatorSection.clients:
        final clients = await repo.fetchClients();
        final campaigns = await repo.fetchCampaigns();
        return _OperatorData(
          eyebrow: 'Flow',
          title: 'Clients and live standing',
          subtitle:
              'Client work should show both commercial state and whether the client is actually moving through the live system.',
          metrics: [
            _Metric('Clients', '${clients.length}'),
            _Metric('Campaigns', '${campaigns.length}'),
          ],
          primaryTitle: 'Accounts',
          primaryRows: clients
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['displayName', 'legalName'],
                  primaryKeys: const ['status', 'selectedPlan'],
                  secondaryKeys: const ['websiteUrl'],
                ),
              )
              .toList(),
          primaryEmpty: 'No clients are available.',
          secondaryTitle: 'Live readiness',
          secondaryRows: clients
              .take(6)
              .map(
                (item) => _mapRow(
                  item,
                  titleKeys: const ['displayName', 'legalName'],
                  primaryKeys: const ['subscriptionStatus', 'status'],
                  secondaryKeys: const ['primaryTimezone'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No readiness cues are available.',
        );

      case OperatorSection.revenue:
        final overview = await repo.fetchRevenueOverview();
        final invoices = await repo.fetchInvoices();
        final subscriptions = await repo.fetchSubscriptions();
        return _OperatorData(
          eyebrow: 'System',
          title: 'Revenue continuity and subscription standing',
          subtitle:
              'Money movement should remain visible from the same operator environment without becoming a detached admin area.',
          metrics: [
            _Metric('Invoices', '${invoices.length}'),
            _Metric('Subscriptions', '${subscriptions.length}'),
            _Metric('Outstanding', _money(_asMap(overview['totals'])['outstandingCents'])),
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
          primaryEmpty: 'No invoices are available.',
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
          secondaryEmpty: 'No subscriptions are available.',
        );

      case OperatorSection.deliverability:
        final overview = await repo.fetchDeliverabilityOverview();
        return _OperatorData(
          eyebrow: 'System',
          title: 'Mailboxes and sending posture',
          subtitle:
              'Healthy mailbox posture protects the rest of the operator chain. This area should stay close to execution reality.',
          metrics: [
            _Metric('Healthy', _read(overview, 'healthyMailboxes', fallback: '0')),
            _Metric('Degraded', _read(overview, 'degradedMailboxes', fallback: '0')),
          ],
          primaryTitle: 'Mailbox standing',
          primaryRows: [
            _Row(
              title: 'Healthy mailboxes',
              primary: _read(overview, 'healthyMailboxes', fallback: '0'),
            ),
            _Row(
              title: 'Degraded mailboxes',
              primary: _read(overview, 'degradedMailboxes', fallback: '0'),
            ),
          ],
          primaryEmpty: 'No deliverability data is available.',
          secondaryTitle: 'Operator note',
          secondaryRows: const [
            _Row(
              title: 'Posture',
              primary: 'Review degraded mailboxes before scaling outbound volume.',
            ),
          ],
          secondaryEmpty: 'No posture note is available.',
        );

      case OperatorSection.communications:
        final emails = await repo.fetchEmailDispatches();
        final inquiries = await repo.fetchInquiries(limit: 6);
        final inquiryItems = (inquiries['items'] as List? ?? const []).cast<dynamic>();
        return _OperatorData(
          eyebrow: 'Conversations',
          title: 'Outbound and inbound communication record',
          subtitle:
              'Dispatch history and inbound intake should stay visible together so communication does not split into separate worlds.',
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
          primaryEmpty: 'No dispatches are available.',
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
          secondaryEmpty: 'No inquiries are available.',
        );

      case OperatorSection.records:
        final overview = await repo.fetchRecordsOverview();
        final agreements = await repo.fetchAgreements();
        final statements = await repo.fetchStatements();
        return _OperatorData(
          eyebrow: 'System',
          title: 'Agreements, statements, and formal records',
          subtitle:
              'Formal records should stay inside the operator environment, not become detached back-office files.',
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
              primary: _read(overview, 'summary', fallback: 'Record overview available'),
            ),
          ],
          primaryEmpty: 'No record summary is available.',
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
          secondaryEmpty: 'No artifacts are available.',
        );

      case OperatorSection.settings:
        final auth = await repo.fetchAuthContext();
        return _OperatorData(
          eyebrow: 'System',
          title: 'Workspace context and access',
          subtitle:
              'Operator access stays visible here without pretending this area is a product feature of its own.',
          metrics: [_Metric('Surface', _read(auth, 'surface', fallback: 'operator'))],
          primaryTitle: 'Access context',
          primaryRows: [
            _Row(
              title: 'Surface',
              primary: _read(auth, 'surface', fallback: 'operator'),
            ),
            _Row(title: 'Organization', primary: _read(auth, 'organizationId')),
          ],
          primaryEmpty: 'No access context is available.',
          secondaryTitle: 'Posture',
          secondaryRows: const [
            _Row(
              title: 'Note',
              primary: 'Keep operator changes controlled, visible, and tied to the live system.',
            ),
          ],
          secondaryEmpty: 'No notes are available.',
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final _OperatorData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.eyebrow,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.subdued),
          ),
          const SizedBox(height: 8),
          Text(data.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(data.subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < metrics.length; i++) ...[
                _MetricCard(metric: metrics[i]),
                if (i != metrics.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < metrics.length; i++) ...[
              Expanded(child: _MetricCard(metric: metrics[i])),
              if (i != metrics.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
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
        borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(18),
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
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.primaryTitle,
    required this.primaryRows,
    required this.primaryEmpty,
    required this.secondaryTitle,
    required this.secondaryRows,
    required this.secondaryEmpty,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<_Metric> metrics;
  final String primaryTitle;
  final List<_Row> primaryRows;
  final String primaryEmpty;
  final String secondaryTitle;
  final List<_Row> secondaryRows;
  final String secondaryEmpty;
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
  if (value is String) return value.trim().isEmpty ? fallback : value.trim();
  return '$value';
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
