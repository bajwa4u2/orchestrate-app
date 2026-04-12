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
        final overview = await repo.fetchCommandOverview();
        final today = _asMap(overview['today']);
        final execution = _asMap(overview['execution']);
        final deliverability = _asMap(overview['deliverability']);
        final alerts = _asMap(overview['alerts']);
        return _OperatorData(
          eyebrow: 'Command',
          title: 'System posture and immediate pressure',
          subtitle:
              'See what needs attention across execution, deliverability, and alerts.',
          metrics: [
            _Metric('Sent today', _read(today, 'sent', fallback: '0')),
            _Metric('Replies', _read(today, 'replies', fallback: '0')),
            _Metric('Booked', _read(today, 'booked', fallback: '0')),
            _Metric('Failed jobs', _read(execution, 'failedJobs', fallback: '0')),
          ],
          primaryTitle: 'Operational posture',
          primaryRows: [
            _Row(
              title: 'System posture',
              primary: _read(overview, 'systemPosture', fallback: 'Live'),
              secondary: _read(overview, 'systemPhase'),
            ),
            _Row(
              title: 'Deliverability',
              primary:
                  '${_read(deliverability, 'healthyMailboxes', fallback: '0')} healthy',
              secondary:
                  '${_read(deliverability, 'degradedMailboxes', fallback: '0')} degraded',
            ),
            _Row(
              title: 'Alerts',
              primary: '${_read(alerts, 'open', fallback: '0')} open',
              secondary: '${_read(alerts, 'critical', fallback: '0')} critical',
            ),
          ],
          primaryEmpty: 'No command detail is available.',
          secondaryTitle: 'Today',
          secondaryRows: [
            _Row(
              title: 'Outbound movement',
              primary: '${_read(today, 'sent', fallback: '0')} sent',
              secondary: '${_read(today, 'replies', fallback: '0')} replies',
            ),
            _Row(
              title: 'Meeting conversion',
              primary: '${_read(today, 'booked', fallback: '0')} booked',
              secondary: '${_read(today, 'followUps', fallback: '0')} follow-ups',
            ),
          ],
          secondaryEmpty: 'No daily movement is available.',
        );

      case OperatorSection.pipeline:
        final leads = await repo.fetchLeads();
        final campaigns = await repo.fetchCampaigns();
        return _OperatorData(
          eyebrow: 'Pipeline',
          title: 'Lead and campaign movement',
          subtitle: 'View the raw prospecting flow that feeds execution.',
          metrics: [
            _Metric('Leads', '${leads.length}'),
            _Metric('Campaigns', '${campaigns.length}'),
          ],
          primaryTitle: 'Leads',
          primaryRows: leads
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'fullName',
                  primaryKeys: const ['companyName', 'status'],
                  secondaryKeys: const ['email'],
                ),
              )
              .toList(),
          primaryEmpty: 'No leads are available.',
          secondaryTitle: 'Campaigns feeding execution',
          secondaryRows: campaigns
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'name',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['channel'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No campaigns are available.',
        );

      case OperatorSection.inquiries:
        final inquiries = await repo.fetchInquiries(limit: 12);
        final items = (inquiries['items'] as List? ?? const []).cast<dynamic>();
        return _OperatorData(
          eyebrow: 'Inquiries',
          title: 'Inbound contact and handling queue',
          subtitle: 'Keep new contact, ownership, and response posture visible together.',
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
                  titleKey: 'name',
                  primaryKeys: const ['status', 'type'],
                  secondaryKeys: const ['email'],
                ),
              )
              .toList(),
          primaryEmpty: 'No inquiries are available.',
          secondaryTitle: 'Handling notes',
          secondaryRows: items
              .take(6)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'subject',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['createdAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No inquiry notes are available.',
        );

      case OperatorSection.campaigns:
        final campaigns = await repo.fetchCampaigns();
        final leads = await repo.fetchLeads();
        return _OperatorData(
          eyebrow: 'Campaigns',
          title: 'Outbound campaigns and source movement',
          subtitle: 'Campaign work should remain visible without being folded into a generic screen.',
          metrics: [
            _Metric('Campaigns', '${campaigns.length}'),
            _Metric('Live leads', '${leads.length}'),
          ],
          primaryTitle: 'Campaign list',
          primaryRows: campaigns
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'name',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['channel', 'createdAt'],
                ),
              )
              .toList(),
          primaryEmpty: 'No campaigns are available.',
          secondaryTitle: 'Recent prospects',
          secondaryRows: leads
              .take(8)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'fullName',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['companyName'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No prospects are available.',
        );

      case OperatorSection.replies:
        final replies = await repo.fetchReplies();
        final meetings = await repo.fetchMeetings();
        return _OperatorData(
          eyebrow: 'Replies',
          title: 'Reply handling and conversion pressure',
          subtitle: 'Response movement needs its own surface before it becomes meeting work.',
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
                  titleKey: 'subject',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['fromEmail', 'receivedAt'],
                ),
              )
              .toList(),
          primaryEmpty: 'No replies are available.',
          secondaryTitle: 'Next meeting cues',
          secondaryRows: meetings
              .take(6)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'title',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['scheduledAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No meeting cues are available.',
        );

      case OperatorSection.meetings:
        final meetings = await repo.fetchMeetings();
        final clients = await repo.fetchClients();
        return _OperatorData(
          eyebrow: 'Meetings',
          title: 'Booked calls and client handoff readiness',
          subtitle: 'Meeting work should stand on its own instead of hiding inside execution.',
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
                  titleKey: 'title',
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
                  titleKey: 'displayName',
                  primaryKeys: const ['subscriptionStatus'],
                  secondaryKeys: const ['selectedPlan'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No client standing is available.',
        );

      case OperatorSection.clients:
        final clients = await repo.fetchClients();
        return _OperatorData(
          eyebrow: 'Clients',
          title: 'Client accounts and standing',
          subtitle: 'The commercial side and the live side should remain visible together.',
          metrics: [_Metric('Clients', '${clients.length}')],
          primaryTitle: 'Accounts',
          primaryRows: clients
              .take(10)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'displayName',
                  primaryKeys: const ['status', 'selectedPlan'],
                  secondaryKeys: const ['websiteUrl'],
                ),
              )
              .toList(),
          primaryEmpty: 'No clients are available.',
          secondaryTitle: 'Readiness cues',
          secondaryRows: clients
              .take(6)
              .map(
                (item) => _mapRow(
                  item,
                  titleKey: 'displayName',
                  primaryKeys: const ['subscriptionStatus'],
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
          eyebrow: 'Revenue',
          title: 'Billing continuity and subscription view',
          subtitle: 'Financial movement remains visible without leaving the operator surface.',
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
                  titleKey: 'invoiceNumber',
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
                  titleKey: 'externalRef',
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
          eyebrow: 'Deliverability',
          title: 'Mailboxes and sending posture',
          subtitle: 'Healthy sending posture protects the rest of the execution chain.',
          metrics: [
            _Metric('Healthy', _read(overview, 'healthyMailboxes', fallback: '0')),
            _Metric('Degraded', _read(overview, 'degradedMailboxes', fallback: '0')),
          ],
          primaryTitle: 'Mailbox status',
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
          secondaryTitle: 'Posture',
          secondaryRows: const [
            _Row(
              title: 'Note',
              primary: 'Review degraded mailboxes before scaling send volume.',
            ),
          ],
          secondaryEmpty: 'No posture note is available.',
        );

      case OperatorSection.communications:
        final emails = await repo.fetchEmailDispatches();
        final inquiries = await repo.fetchInquiries(limit: 6);
        final inquiryItems = (inquiries['items'] as List? ?? const []).cast<dynamic>();
        return _OperatorData(
          eyebrow: 'Communications',
          title: 'Outbound dispatch and inbound intake',
          subtitle: 'Keep the communication record tied to operational handling.',
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
                  titleKey: 'subject',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['sentAt'],
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
                  titleKey: 'name',
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
          eyebrow: 'Records',
          title: 'Agreements, statements, and formal record flow',
          subtitle: 'Documents remain first-class operational records, not detached files.',
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
                    titleKey: 'title',
                    primaryKeys: const ['status'],
                    secondaryKeys: const ['updatedAt'],
                  ),
                ),
            ...statements.take(4).map(
                  (item) => _mapRow(
                    item,
                    titleKey: 'statementNumber',
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
          eyebrow: 'Settings',
          title: 'Workspace context and access',
          subtitle: 'Basic operator context and surface resolution.',
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
          secondaryTitle: 'Notes',
          secondaryRows: const [
            _Row(
              title: 'Posture',
              primary: 'Keep operator changes controlled and visible.',
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
  required String titleKey,
  List<String> primaryKeys = const [],
  List<String> secondaryKeys = const [],
}) {
  final map = _asMap(raw);
  final title = _read(map, titleKey, fallback: 'Untitled');
  final primary = _joinKeys(map, primaryKeys, fallback: 'No detail');
  final secondary = _joinKeys(map, secondaryKeys);
  return _Row(title: title, primary: primary, secondary: secondary);
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
