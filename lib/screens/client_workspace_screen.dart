import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/surface.dart';
import '../data/repositories/client_portal_repository.dart';

enum ClientSection {
  overview,
  billing,
  agreements,
  statements,
  requests,
  notifications,
  account,
}

class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({super.key, required this.section});

  final ClientSection section;

  @override
  Widget build(BuildContext context) {
    final repository = ClientPortalRepository();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 16),
        child: AsyncSurface<_ClientViewData>(
          future: _load(repository),
          builder: (context, data) {
            final view = data ?? _ClientViewData.empty(section);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: view.title, subtitle: view.subtitle),
                const SizedBox(height: 24),
                if (view.notice != null) ...[
                  _Banner(message: view.notice!, isError: false),
                  const SizedBox(height: 20),
                ],
                if (view.stats.isNotEmpty) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final stat in view.stats)
                        SizedBox(
                          width: 220,
                          child: Surface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stat.label, style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 14),
                                Text(
                                  stat.value,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: stat.tone ?? AppTheme.text,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                _Panel(title: view.primaryTitle, rows: view.primaryRows, emptyLabel: view.primaryEmpty),
                if (view.secondaryTitle != null) ...[
                  const SizedBox(height: 20),
                  _Panel(title: view.secondaryTitle!, rows: view.secondaryRows, emptyLabel: view.secondaryEmpty),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_ClientViewData> _load(ClientPortalRepository repository) async {
    switch (section) {
      case ClientSection.overview:
        final overview = await repository.fetchOverview();
        final billing = _asMap(overview['billing']);
        final activity = _asMap(overview['activity']);
        final communications = _asMap(overview['communications']);
        final client = _asMap(overview['client']);
        return _ClientViewData(
          title: 'Overview',
          subtitle: 'Account standing, active work, billing posture, and open items.',
          notice: AppConfig.hasClientAccess
              ? 'Client access is active for this session.'
              : 'Client access headers have not been provided for this session.',
          stats: [
            _ClientStat('Outstanding', _money(billing['outstandingCents']), tone: AppTheme.amber),
            _ClientStat('Open notifications', _num(communications['openNotifications']), tone: AppTheme.rose),
            _ClientStat('Replies', _num(activity['replies'])),
            _ClientStat('Meetings', _num(activity['meetings']), tone: AppTheme.emerald),
          ],
          primaryTitle: 'Account',
          primaryRows: [
            _ClientRow(
              title: _read(client, 'displayName', fallback: _read(client, 'legalName', fallback: 'Client account')),
              primary: [_read(client, 'status'), _read(client, 'industry')].where((e) => e.isNotEmpty).join(' · '),
              secondary: [_read(client, 'websiteUrl'), _read(client, 'primaryTimezone')].where((e) => e.isNotEmpty).join(' · '),
            ),
            _ClientRow(
              title: 'Portal',
              primary: _read(communications, 'portalUrl'),
              secondary: '${_num(communications['emailDispatches'])} email dispatches',
            ),
          ],
          secondaryTitle: 'Billing standing',
          secondaryRows: [
            _ClientRow(
              title: 'Invoices',
              primary: _num(billing['invoiceCount']),
              secondary: '${_money(billing['collectedCents'])} collected',
            ),
            _ClientRow(
              title: 'Balance',
              primary: _money(billing['outstandingCents']),
              secondary: '${_money(billing['overdueCents'])} overdue',
            ),
          ],
        );

      case ClientSection.billing:
        final invoices = await repository.fetchInvoices();
        return _ClientViewData(
          title: 'Billing',
          subtitle: 'Invoices, receipts, and current payment standing.',
          stats: [
            _ClientStat('Invoices', '${invoices.length}'),
            _ClientStat('Paid', '${_countBy(invoices, (item) => _read(item, 'status') == 'PAID')}', tone: AppTheme.emerald),
            _ClientStat('Open', '${_countBy(invoices, (item) => _read(item, 'status') == 'OPEN')}', tone: AppTheme.amber),
          ],
          primaryTitle: 'Invoices',
          primaryRows: invoices.take(12).map(_invoiceRow).toList(),
          primaryEmpty: 'No invoices are available.',
        );

      case ClientSection.agreements:
        final agreements = await repository.fetchAgreements();
        return _ClientViewData(
          title: 'Agreements',
          subtitle: 'Service agreements and current renewal footing.',
          primaryTitle: 'Agreements',
          primaryRows: agreements.take(12).map(_agreementRow).toList(),
          primaryEmpty: 'No agreements are available.',
        );

      case ClientSection.statements:
        final statements = await repository.fetchStatements();
        return _ClientViewData(
          title: 'Statements',
          subtitle: 'Quarterly, half-year, and annual record summaries.',
          primaryTitle: 'Statements',
          primaryRows: statements.take(12).map(_statementRow).toList(),
          primaryEmpty: 'No statements are available.',
        );

      case ClientSection.requests:
        final reminders = await repository.fetchReminders();
        return _ClientViewData(
          title: 'Requests',
          subtitle: 'Items that require attention, response, or scheduled follow-through.',
          primaryTitle: 'Requests',
          primaryRows: reminders.take(12).map(_reminderRow).toList(),
          primaryEmpty: 'No requests are available.',
        );

      case ClientSection.notifications:
        final results = await Future.wait([
          repository.fetchNotifications(),
          repository.fetchEmailDispatches(),
        ]);
        final notifications = results[0];
        final dispatches = results[1];
        return _ClientViewData(
          title: 'Notifications',
          subtitle: 'Account alerts and delivered communications.',
          primaryTitle: 'Notifications',
          primaryRows: notifications.take(8).map(_notificationRow).toList(),
          primaryEmpty: 'No notifications are available.',
          secondaryTitle: 'Delivered emails',
          secondaryRows: dispatches.take(8).map(_dispatchRow).toList(),
          secondaryEmpty: 'No delivered emails are available.',
        );

      case ClientSection.account:
        final overview = await repository.fetchOverview();
        final client = _asMap(overview['client']);
        final communications = _asMap(overview['communications']);
        return _ClientViewData(
          title: 'Account',
          subtitle: 'Profile, access footing, and communication path.',
          primaryTitle: 'Profile',
          primaryRows: [
            _ClientRow(title: 'Display name', primary: _read(client, 'displayName'), secondary: _read(client, 'legalName')),
            _ClientRow(title: 'Website', primary: _read(client, 'websiteUrl'), secondary: _read(client, 'industry')),
            _ClientRow(title: 'Timezone', primary: _read(client, 'primaryTimezone'), secondary: _read(client, 'currencyCode')),
            _ClientRow(title: 'Portal', primary: _read(communications, 'portalUrl'), secondary: 'Secure access'),
          ],
          primaryEmpty: 'Account details are not available.',
        );
    }
  }
}

class _ClientViewData {
  const _ClientViewData({
    required this.title,
    required this.subtitle,
    this.notice,
    this.stats = const [],
    required this.primaryTitle,
    this.primaryRows = const [],
    this.primaryEmpty = 'Nothing is available.',
    this.secondaryTitle,
    this.secondaryRows = const [],
    this.secondaryEmpty = 'Nothing is available.',
  });

  final String title;
  final String subtitle;
  final String? notice;
  final List<_ClientStat> stats;
  final String primaryTitle;
  final List<_ClientRow> primaryRows;
  final String primaryEmpty;
  final String? secondaryTitle;
  final List<_ClientRow> secondaryRows;
  final String secondaryEmpty;

  factory _ClientViewData.empty(ClientSection section) => _ClientViewData(
        title: section.name[0].toUpperCase() + section.name.substring(1),
        subtitle: '',
        primaryTitle: 'Overview',
      );
}

class _ClientStat {
  const _ClientStat(this.label, this.value, {this.tone});

  final String label;
  final String value;
  final Color? tone;
}

class _ClientRow {
  const _ClientRow({required this.title, required this.primary, required this.secondary});

  final String title;
  final String primary;
  final String secondary;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.rows, required this.emptyLabel});

  final String title;
  final List<_ClientRow> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.muted))
          else
            Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _PanelRow(row: rows[index]),
                  if (index != rows.length - 1) const Divider(height: 26),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({required this.row});

  final _ClientRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: Text(row.title, style: Theme.of(context).textTheme.titleMedium)),
        Expanded(flex: 4, child: Text(row.primary, style: Theme.of(context).textTheme.bodyLarge)),
        Expanded(flex: 4, child: Text(row.secondary, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Surface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 18,
              color: isError ? AppTheme.rose : AppTheme.accent,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) => value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
String _num(dynamic value) => ((value as num?) ?? 0).toString();
String _money(dynamic cents) {
  final amount = ((cents as num?) ?? 0) / 100;
  return '\$${amount.toStringAsFixed(2)}';
}
String _read(dynamic source, String key, {String fallback = ''}) {
  if (source is Map && source[key] != null) return '${source[key]}';
  return fallback;
}
int _countBy(List<dynamic> items, bool Function(Map<String, dynamic>) test) {
  var count = 0;
  for (final item in items) {
    final map = _asMap(item);
    if (test(map)) count += 1;
  }
  return count;
}
_ClientRow _invoiceRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'invoiceNumber', fallback: 'Invoice'),
    primary: [_read(item, 'status'), _money(item['totalCents'])].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'dueAt'),
  );
}
_ClientRow _agreementRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'title', fallback: _read(item, 'agreementNumber', fallback: 'Agreement')),
    primary: [_read(item, 'status'), _read(item, 'agreementNumber')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'effectiveStartAt'), _read(item, 'effectiveEndAt')].where((e) => e.isNotEmpty).join(' → '),
  );
}
_ClientRow _statementRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'statementNumber', fallback: 'Statement'),
    primary: [_read(item, 'status'), _money(item['balanceCents'])].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'periodStart'), _read(item, 'periodEnd')].where((e) => e.isNotEmpty).join(' → '),
  );
}
_ClientRow _reminderRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'subjectLine', fallback: 'Request'),
    primary: [_read(item, 'status'), _read(item, 'scheduledAt')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bodyText'),
  );
}
_ClientRow _notificationRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'title', fallback: 'Notification'),
    primary: [_read(item, 'severity'), _read(item, 'status')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bodyText'),
  );
}
_ClientRow _dispatchRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'subjectLine', fallback: 'Email'),
    primary: [_read(item, 'status'), _read(item, 'recipientEmail')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'createdAt'),
  );
}
String _humanizeError(Object error) {
  final raw = '$error';
  if (raw.contains('401') || raw.contains('Unauthorized')) {
    return 'This portal could not load because account access is not active for the current session.';
  }
  return 'This account surface could not load right now.';
}
