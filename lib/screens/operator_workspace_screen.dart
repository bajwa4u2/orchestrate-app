import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/surface.dart';
import '../data/repositories/operator_repository.dart';

enum OperatorSection {
  command,
  pipeline,
  execution,
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
    final repository = OperatorRepository();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 16),
        child: AsyncSurface<_OperatorViewData>(
          future: _load(repository),
          builder: (context, data) {
            final view = data ?? _OperatorViewData.empty(section);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: view.title,
                  subtitle: view.subtitle,
                  trailing: view.trailingLabel == null ? null : _Badge(label: view.trailingLabel!),
                ),
                const SizedBox(height: 24),
                if (view.notice != null) ...[
                  _InfoPanel(message: view.notice!),
                  const SizedBox(height: 20),
                ],
                if (view.heroStats.isNotEmpty) ...[
                  _StatsGrid(stats: view.heroStats),
                  const SizedBox(height: 20),
                ],
                if (view.primaryRows.isNotEmpty || view.primaryTitle != null) ...[
                  _DataPanel(
                    title: view.primaryTitle ?? 'Overview',
                    subtitle: view.primarySubtitle,
                    rows: view.primaryRows,
                    emptyLabel: view.primaryEmptyLabel,
                  ),
                  const SizedBox(height: 20),
                ],
                if (view.secondaryRows.isNotEmpty || view.secondaryTitle != null) ...[
                  _DataPanel(
                    title: view.secondaryTitle ?? 'Records',
                    subtitle: view.secondarySubtitle,
                    rows: view.secondaryRows,
                    emptyLabel: view.secondaryEmptyLabel,
                  ),
                  const SizedBox(height: 20),
                ],
                if (view.tertiaryRows.isNotEmpty || view.tertiaryTitle != null) ...[
                  _DataPanel(
                    title: view.tertiaryTitle ?? 'Activity',
                    subtitle: view.tertiarySubtitle,
                    rows: view.tertiaryRows,
                    emptyLabel: view.tertiaryEmptyLabel,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_OperatorViewData> _load(OperatorRepository repository) async {
    switch (section) {
      case OperatorSection.command:
        final results = await Future.wait([
          repository.fetchCommandOverview(),
          repository.fetchPublicInquiries(limit: 8),
        ]);
        final overview = _asMap(results[0]);
        final inquiries = _asMap(results[1]);
        final totals = _asMap(overview['totals']);
        final today = _asMap(overview['today']);
        final execution = _asMap(overview['execution']);
        final deliverability = _asMap(overview['deliverability']);
        final alerts = _asMap(overview['alerts']);
        final inquirySummary = _asMap(inquiries['summary']);
        final inquiryItems = _list(inquiries['items']);
        return _OperatorViewData(
          title: 'Command',
          subtitle: 'Today, pressure, delivery, and unresolved work in one frame.',
          trailingLabel: _stringPath(overview, ['system', 'phase']),
          heroStats: [
            _Stat('Sent today', _num(today['sent'])),
            _Stat('Replies', _num(today['replies'])),
            _Stat('Booked', _num(today['booked'])),
            _Stat('Open alerts', _num(alerts['open']), tone: AppTheme.rose),
            _Stat('Open inquiries', _num(inquirySummary['totalOpen']), tone: AppTheme.amber),
            _Stat('Degraded mailboxes', _num(deliverability['degradedMailboxes']), tone: AppTheme.amber),
          ],
          primaryTitle: 'System posture',
          primaryRows: [
            _RowData(
              title: _stringPath(overview, ['system', 'posture'], fallback: 'Live'),
              primary: '${_num(totals['clients'])} clients · ${_num(totals['campaigns'])} campaigns · ${_num(totals['leads'])} leads',
              secondary: '${_num(totals['messages'])} messages · ${_num(totals['replies'])} replies · ${_num(totals['meetings'])} meetings',
            ),
          ],
          secondaryTitle: 'Pressure',
          secondaryRows: [
            _RowData(
              title: 'Execution queue',
              primary: '${_num(execution['queuedJobs'])} queued',
              secondary: '${_num(execution['failedJobs'])} failed',
            ),
            _RowData(
              title: 'Deliverability',
              primary: '${_num(deliverability['activeMailboxes'])} active mailboxes',
              secondary: '${_num(deliverability['degradedMailboxes'])} degraded',
            ),
            _RowData(
              title: 'Inquiries',
              primary: '${_num(inquirySummary['received'])} new · ${_num(inquirySummary['acknowledged'])} acknowledged',
              secondary: '${_num(inquirySummary['notified'])} notified · ${_num(inquirySummary['closed'])} closed',
            ),
            _RowData(
              title: 'Alerts',
              primary: '${_num(alerts['open'])} open',
              secondary: _num(alerts['open']) == '0' ? 'No unresolved alert pressure' : 'Review required',
            ),
          ],
          tertiaryTitle: 'Recent inquiries',
          tertiarySubtitle: 'Public contact intake now visible inside operator command.',
          tertiaryRows: inquiryItems.take(8).map(_publicInquiryRow).toList(),
          tertiaryEmptyLabel: 'No public inquiries are available.',
        );

      case OperatorSection.pipeline:
        final leads = await repository.fetchLeads();
        return _OperatorViewData(
          title: 'Pipeline',
          subtitle: 'Lead readiness, qualification, and routing into live work.',
          heroStats: [
            _Stat('Leads', leads.length),
            _Stat('Ready', _countBy(leads, (item) => _read(item, 'status') == 'READY')),
            _Stat('Queued', _countBy(leads, (item) => _read(item, 'status') == 'QUEUED')),
            _Stat('Booked', _countBy(leads, (item) => _read(item, 'status') == 'BOOKED'), tone: AppTheme.emerald),
          ],
          primaryTitle: 'Leads',
          primaryRows: leads.take(12).map(_leadRow).toList(),
          primaryEmptyLabel: 'No leads are available.',
        );

      case OperatorSection.execution:
        final results = await Future.wait([
          repository.fetchCampaigns(),
          repository.fetchReplies(),
          repository.fetchMeetings(),
        ]);
        final campaigns = results[0];
        final replies = results[1];
        final meetings = results[2];
        return _OperatorViewData(
          title: 'Execution',
          subtitle: 'Campaign movement, reply handling, and meeting conversion.',
          heroStats: [
            _Stat('Campaigns', campaigns.length),
            _Stat('Replies', replies.length),
            _Stat('Meetings', meetings.length),
            _Stat('Booked', _countBy(meetings, (item) => _read(item, 'status') == 'BOOKED'), tone: AppTheme.emerald),
          ],
          primaryTitle: 'Campaigns',
          primaryRows: campaigns.take(8).map(_campaignRow).toList(),
          primaryEmptyLabel: 'No campaigns are available.',
          secondaryTitle: 'Replies',
          secondaryRows: replies.take(8).map(_replyRow).toList(),
          secondaryEmptyLabel: 'No replies are available.',
          tertiaryTitle: 'Meetings',
          tertiaryRows: meetings.take(8).map(_meetingRow).toList(),
          tertiaryEmptyLabel: 'No meetings are available.',
        );

      case OperatorSection.clients:
        final clients = await repository.fetchClients();
        return _OperatorViewData(
          title: 'Clients',
          subtitle: 'Account standing, service scope, and current commercial posture.',
          heroStats: [
            _Stat('Accounts', clients.length),
            _Stat('Active', _countBy(clients, (item) => _read(item, 'status') == 'ACTIVE'), tone: AppTheme.emerald),
            _Stat('Draft', _countBy(clients, (item) => _read(item, 'status') == 'DRAFT')),
            _Stat('Paused', _countBy(clients, (item) => _read(item, 'status') == 'PAUSED'), tone: AppTheme.amber),
          ],
          primaryTitle: 'Client accounts',
          primaryRows: clients.take(12).map(_clientRow).toList(),
          primaryEmptyLabel: 'No client accounts are available.',
        );

      case OperatorSection.revenue:
        final results = await Future.wait<dynamic>([
          repository.fetchRevenueOverview(),
          repository.fetchInvoices(),
          repository.fetchAgreements(),
          repository.fetchStatements(),
          repository.fetchSubscriptions(),
        ]);
        final overview = _asMap(results[0]);
        final invoices = _list(results[1]);
        final agreements = _list(results[2]);
        final statements = _list(results[3]);
        final subscriptions = _list(results[4]);
        return _OperatorViewData(
          title: 'Revenue',
          subtitle: 'Invoices, payment standing, agreements, and recurring service footing.',
          heroStats: [
            _Stat('Outstanding', _money(overview['outstandingCents']), tone: AppTheme.amber),
            _Stat('Overdue', _money(overview['overdueCents']), tone: AppTheme.rose),
            _Stat('Collected', _money(overview['collectedCents']), tone: AppTheme.emerald),
            _Stat('Invoices', _num(overview['invoiceCount'])),
          ],
          primaryTitle: 'Invoices',
          primaryRows: invoices.take(10).map(_invoiceRow).toList(),
          primaryEmptyLabel: 'No invoices are available.',
          secondaryTitle: 'Agreements',
          secondaryRows: agreements.take(8).map(_agreementRow).toList(),
          secondaryEmptyLabel: 'No agreements are available.',
          tertiaryTitle: 'Statements and subscriptions',
          tertiaryRows: [
            ...statements.take(4).map(_statementRow),
            ...subscriptions.take(4).map(_subscriptionRow),
          ],
          tertiaryEmptyLabel: 'No statements or subscriptions are available.',
        );

      case OperatorSection.deliverability:
        final overview = await repository.fetchDeliverabilityOverview();
        final domains = _list(overview['domains']);
        final mailboxes = _list(overview['mailboxes']);
        final suppressions = _list(overview['suppressions']);
        return _OperatorViewData(
          title: 'Deliverability',
          subtitle: 'Sending condition, mailbox health, and suppression pressure.',
          heroStats: [
            _Stat('Domains', domains.length),
            _Stat('Mailboxes', mailboxes.length),
            _Stat('Active', _countBy(mailboxes, (item) => _read(item, 'status') == 'ACTIVE'), tone: AppTheme.emerald),
            _Stat('Suppressed', suppressions.length, tone: AppTheme.amber),
          ],
          primaryTitle: 'Sending domains',
          primaryRows: domains.take(8).map(_domainRow).toList(),
          primaryEmptyLabel: 'No sending domains are available.',
          secondaryTitle: 'Mailboxes',
          secondaryRows: mailboxes.take(10).map(_mailboxRow).toList(),
          secondaryEmptyLabel: 'No mailboxes are available.',
          tertiaryTitle: 'Suppression list',
          tertiaryRows: suppressions.take(6).map(_suppressionRow).toList(),
          tertiaryEmptyLabel: 'No suppression entries are available.',
        );

      case OperatorSection.communications:
        final results = await Future.wait<dynamic>([
          repository.fetchTemplates(),
          repository.fetchEmailDispatches(),
          repository.fetchAlerts(),
          repository.fetchReminders(),
        ]);
        final templates = _list(results[0]);
        final dispatches = _list(results[1]);
        final alerts = _list(results[2]);
        final reminders = _list(results[3]);
        return _OperatorViewData(
          title: 'Communications',
          subtitle: 'Templates, email dispatches, reminders, and account alerts.',
          heroStats: [
            _Stat('Templates', templates.length),
            _Stat('Dispatches', dispatches.length),
            _Stat('Alerts', alerts.length, tone: AppTheme.rose),
            _Stat('Reminders', reminders.length),
          ],
          primaryTitle: 'Templates',
          primaryRows: templates.take(8).map(_templateRow).toList(),
          primaryEmptyLabel: 'No templates are available.',
          secondaryTitle: 'Email dispatches',
          secondaryRows: dispatches.take(8).map(_dispatchRow).toList(),
          secondaryEmptyLabel: 'No email dispatches are available.',
          tertiaryTitle: 'Alerts and reminders',
          tertiaryRows: [
            ...alerts.take(4).map(_alertRow),
            ...reminders.take(4).map(_reminderRow),
          ],
          tertiaryEmptyLabel: 'No alerts or reminders are available.',
        );

      case OperatorSection.records:
        final results = await Future.wait<dynamic>([
          repository.fetchRecordsOverview(),
          repository.fetchStatements(),
          repository.fetchAgreements(),
        ]);
        final overview = _asMap(results[0]);
        final statements = _list(results[1]);
        final agreements = _list(results[2]);
        return _OperatorViewData(
          title: 'Records',
          subtitle: 'Documented service history, financial records, and carry-forward artifacts.',
          heroStats: [
            _Stat('Statements', _num(overview['statements'])),
            _Stat('Agreements', _num(overview['agreements'])),
            _Stat('Reminders', _num(overview['reminders'])),
            _Stat('Dispatches', _num(overview['emailDispatches'])),
          ],
          primaryTitle: 'Record volumes',
          primaryRows: [
            _RowData(
              title: 'Core objects',
              primary: '${_num(overview['clients'])} clients · ${_num(overview['campaigns'])} campaigns · ${_num(overview['leads'])} leads',
              secondary: '${_num(overview['replies'])} replies · ${_num(overview['meetings'])} meetings',
            ),
            _RowData(
              title: 'Document layer',
              primary: '${_num(overview['agreements'])} agreements · ${_num(overview['statements'])} statements',
              secondary: '${_num(overview['reminders'])} reminders · ${_num(overview['templates'])} templates',
            ),
          ],
          secondaryTitle: 'Statements',
          secondaryRows: statements.take(8).map(_statementRow).toList(),
          secondaryEmptyLabel: 'No statements are available.',
          tertiaryTitle: 'Agreements',
          tertiaryRows: agreements.take(8).map(_agreementRow).toList(),
          tertiaryEmptyLabel: 'No agreements are available.',
        );

      case OperatorSection.settings:
        final context = await repository.fetchAuthContext();
        final memberRole = _read(context, 'memberRole', fallback: 'Unassigned');
        final organizationId = _read(context, 'organizationId', fallback: 'Unavailable');
        final email = _read(context, 'email', fallback: 'Unavailable');
        return _OperatorViewData(
          title: 'Settings',
          subtitle: 'Workspace identity, access footing, and runtime context.',
          notice: AppConfig.hasOperatorAccess
              ? 'Operator access is active for this session.'
              : 'Operator access headers have not been provided for this session.',
          heroStats: [
            _Stat('Role', memberRole),
            _Stat('Surface', _read(context, 'surface', fallback: 'system')),
            _Stat('Organization', organizationId.isEmpty ? 'Unavailable' : 'Linked'),
          ],
          primaryTitle: 'Access context',
          primaryRows: [
            _RowData(title: 'Organization', primary: organizationId, secondary: 'Active workspace'),
            _RowData(title: 'Member role', primary: memberRole, secondary: email),
            _RowData(
              title: 'Runtime',
              primary: AppConfig.apiBaseUrl,
              secondary: 'API base URL',
            ),
          ],
        );
    }
  }
}

class _OperatorViewData {
  const _OperatorViewData({
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.notice,
    this.heroStats = const [],
    this.primaryTitle,
    this.primarySubtitle,
    this.primaryRows = const [],
    this.primaryEmptyLabel = 'Nothing is available.',
    this.secondaryTitle,
    this.secondarySubtitle,
    this.secondaryRows = const [],
    this.secondaryEmptyLabel = 'Nothing is available.',
    this.tertiaryTitle,
    this.tertiarySubtitle,
    this.tertiaryRows = const [],
    this.tertiaryEmptyLabel = 'Nothing is available.',
  });

  final String title;
  final String subtitle;
  final String? trailingLabel;
  final String? notice;
  final List<_Stat> heroStats;
  final String? primaryTitle;
  final String? primarySubtitle;
  final List<_RowData> primaryRows;
  final String primaryEmptyLabel;
  final String? secondaryTitle;
  final String? secondarySubtitle;
  final List<_RowData> secondaryRows;
  final String secondaryEmptyLabel;
  final String? tertiaryTitle;
  final String? tertiarySubtitle;
  final List<_RowData> tertiaryRows;
  final String tertiaryEmptyLabel;

  factory _OperatorViewData.empty(OperatorSection section) => _OperatorViewData(
        title: section.name[0].toUpperCase() + section.name.substring(1),
        subtitle: '',
      );
}

class _Stat {
  const _Stat(this.label, this.value, {this.tone});

  final String label;
  final Object value;
  final Color? tone;
}

class _RowData {
  const _RowData({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondary;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final stat in stats)
          SizedBox(
            width: 220,
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${stat.value}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: stat.tone ?? AppTheme.text,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.title,
    this.subtitle,
    required this.rows,
    required this.emptyLabel,
  });

  final String title;
  final String? subtitle;
  final List<_RowData> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.muted))
          else
            Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _DataRow(row: rows[index]),
                  if (index != rows.length - 1) const Divider(height: 26),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.row});

  final _RowData row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(row.title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          flex: 3,
          child: Text(row.primary, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Expanded(
          flex: 4,
          child: Text(
            row.secondary.isEmpty ? '—' : row.secondary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}


_RowData _publicInquiryRow(dynamic source) {
  final inquiryType = _read(source, 'inquiryType');
  final company = _read(source, 'company');
  final email = _read(source, 'email');
  final status = _humanizeEnum(_read(source, 'status'));
  final submittedAt = _read(source, 'submittedAt');
  final submittedLabel = _formatIsoDateTime(submittedAt);
  final message = _read(source, 'message').replaceAll('
', ' ').trim();
  final preview = message.length > 84 ? '${message.substring(0, 84)}…' : message;

  return _RowData(
    title: _read(source, 'name', fallback: 'Inquiry'),
    primary: '${_humanizeEnum(inquiryType)}${company.isEmpty ? '' : ' · $company'}',
    secondary: '${email.isEmpty ? 'No email' : email} · $status${submittedLabel.isEmpty ? '' : ' · $submittedLabel'}${preview.isEmpty ? '' : ' · $preview'}',
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Surface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Surface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.rose, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) => value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : const [];
String _num(dynamic value) => ((value as num?) ?? 0).toString();
String _money(dynamic cents) {
  final amount = ((cents as num?) ?? 0) / 100;
  return '\$${amount.toStringAsFixed(2)}';
}
String _read(dynamic source, String key, {String fallback = ''}) {
  if (source is Map && source[key] != null) return '${source[key]}';
  return fallback;
}
String _stringPath(Map<String, dynamic> source, List<String> path, {String fallback = ''}) {
  dynamic current = source;
  for (final segment in path) {
    if (current is Map && current.containsKey(segment)) {
      current = current[segment];
    } else {
      return fallback;
    }
  }
  return current == null ? fallback : '$current';
}
int _countBy(List<dynamic> items, bool Function(Map<String, dynamic> item) test) {
  var count = 0;
  for (final item in items) {
    final map = _asMap(item);
    if (test(map)) count += 1;
  }
  return count;
}
_RowData _clientRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'displayName', fallback: _read(item, 'legalName', fallback: 'Client')),
    primary: [_read(item, 'status'), _read(item, 'industry')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'websiteUrl'), _read(item, 'primaryTimezone')].where((e) => e.isNotEmpty).join(' · '),
  );
}
_RowData _campaignRow(dynamic raw) {
  final item = _asMap(raw);
  final client = _asMap(item['client']);
  return _RowData(
    title: _read(item, 'name', fallback: 'Campaign'),
    primary: [_read(item, 'status'), _read(item, 'channel')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(client, 'displayName'), _read(item, 'objective')].where((e) => e.isNotEmpty).join(' · '),
  );
}
_RowData _leadRow(dynamic raw) {
  final item = _asMap(raw);
  final contact = _asMap(item['contact']);
  final account = _asMap(item['account']);
  return _RowData(
    title: _read(contact, 'fullName', fallback: _read(account, 'companyName', fallback: 'Lead')),
    primary: [_read(item, 'status'), _read(contact, 'email')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(account, 'companyName'), _read(contact, 'title')].where((e) => e.isNotEmpty).join(' · '),
  );
}
_RowData _replyRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'subjectLine', fallback: 'Reply'),
    primary: [_read(item, 'intent'), _read(item, 'fromEmail')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bodyText'),
  );
}
_RowData _meetingRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'title', fallback: 'Meeting'),
    primary: [_read(item, 'status'), _read(item, 'scheduledAt')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bookingUrl'),
  );
}
_RowData _invoiceRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'invoiceNumber', fallback: 'Invoice'),
    primary: [_read(item, 'status'), _money(item['totalCents'])].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'dueAt'), _read(_asMap(item['client']), 'displayName')].where((e) => e.isNotEmpty).join(' · '),
  );
}
_RowData _agreementRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'title', fallback: _read(item, 'agreementNumber', fallback: 'Agreement')),
    primary: [_read(item, 'status'), _read(item, 'agreementNumber')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'effectiveStartAt'), _read(item, 'effectiveEndAt')].where((e) => e.isNotEmpty).join(' · '),
  );
}
_RowData _statementRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'statementNumber', fallback: _read(item, 'label', fallback: 'Statement')),
    primary: [_read(item, 'status'), _money(item['balanceCents'])].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'periodStart'), _read(item, 'periodEnd')].where((e) => e.isNotEmpty).join(' → '),
  );
}
_RowData _subscriptionRow(dynamic raw) {
  final item = _asMap(raw);
  final plan = _asMap(item['plan']);
  return _RowData(
    title: _read(plan, 'name', fallback: 'Subscription'),
    primary: [_read(item, 'status'), _read(_asMap(item['client']), 'displayName')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'currentPeriodEnd'),
  );
}
_RowData _domainRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'domain', fallback: 'Domain'),
    primary: [_read(item, 'status'), _read(item, 'provider')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'spfStatus'), _read(item, 'dkimStatus'), _read(item, 'dmarcStatus')].where((e) => e.isNotEmpty).join(' · '),
  );
}
_RowData _mailboxRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'emailAddress', fallback: 'Mailbox'),
    primary: [_read(item, 'status'), _read(item, 'healthStatus')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'dailySendCap'), _read(item, 'warmupStatus')].where((e) => e.isNotEmpty).join(' · '),
  );
}
_RowData _suppressionRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'value', fallback: 'Suppression entry'),
    primary: [_read(item, 'type'), _read(item, 'status')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'reasonText'),
  );
}
_RowData _templateRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'name', fallback: 'Template'),
    primary: [_read(item, 'type'), _read(item, 'isActive') == 'true' ? 'Active' : 'Inactive'].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'subjectTemplate'),
  );
}
_RowData _dispatchRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'subjectLine', fallback: 'Dispatch'),
    primary: [_read(item, 'status'), _read(item, 'recipientEmail')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'createdAt'),
  );
}
_RowData _alertRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'title', fallback: 'Alert'),
    primary: [_read(item, 'severity'), _read(item, 'status')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bodyText'),
  );
}
_RowData _reminderRow(dynamic raw) {
  final item = _asMap(raw);
  return _RowData(
    title: _read(item, 'subjectLine', fallback: 'Reminder'),
    primary: [_read(item, 'status'), _read(item, 'scheduledAt')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bodyText'),
  );
}
String _humanizeError(Object error) {
  final raw = '$error';
  if (raw.contains('401') || raw.contains('Unauthorized')) {
    return 'This workspace could not load because access headers are missing or not accepted by the API.';
  }
  return 'This surface could not load right now.';
}


String _humanizeEnum(String value) {
  if (value.isEmpty) return '';
  final normalized = value.toLowerCase().split('_').where((part) => part.isNotEmpty).toList();
  return normalized.map((part) => part[0].toUpperCase() + part.substring(1)).join(' ');
}

String _formatIsoDateTime(String value) {
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final month = _monthLabel(local.month);
  final hour24 = local.hour;
  final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year} · $hour12:$minute $suffix';
}

String _monthLabel(int month) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}
