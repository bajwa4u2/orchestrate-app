import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client_portal_repository.dart';

enum ClientSection { overview, billing, agreements, statements, account }

class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({super.key, required this.section});

  final ClientSection section;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClientSectionData>(
      future: _load(section),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('This area could not load right now.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(data: data),
              const SizedBox(height: 18),
              if (data.notice != null) ...[
                _Notice(message: data.notice!),
                const SizedBox(height: 18),
              ],
              _Metrics(metrics: data.metrics),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  final left = _Panel(title: data.primaryTitle, rows: data.primaryRows, empty: data.primaryEmpty);
                  final right = _Panel(title: data.secondaryTitle, rows: data.secondaryRows, empty: data.secondaryEmpty);
                  if (stacked) {
                    return Column(children: [left, const SizedBox(height: 18), right]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: left), const SizedBox(width: 18), Expanded(flex: 5, child: right)]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_ClientSectionData> _load(ClientSection section) async {
    final repo = ClientPortalRepository();
    final session = AuthSessionController.instance;

    switch (section) {
      case ClientSection.billing:
        final invoices = await repo.fetchInvoices();
        final subscription = await repo.fetchSubscription();
        final reminders = await repo.fetchReminders();
        return _ClientSectionData(
          eyebrow: 'Billing standing',
          title: 'Payment and subscription footing',
          subtitle: 'Review invoices, reminders, and the current subscription record.',
          notice: subscription == null ? 'No active subscription record is available yet.' : null,
          metrics: [
            _Metric('Invoices', '${invoices.length}'),
            _Metric('Reminders', '${reminders.length}'),
            _Metric('Status', _read(subscription, 'status', fallback: session.subscriptionStatus.toUpperCase())),
          ],
          primaryTitle: 'Invoices',
          primaryRows: invoices.map((item) => _rowFromMap(item, titleKey: 'invoiceNumber', primaryKeys: const ['status'], secondaryKeys: const ['dueDate', 'currencyCode'])).toList(),
          primaryEmpty: 'No invoices are available yet.',
          secondaryTitle: 'Subscription',
          secondaryRows: [if (subscription != null) _rowFromMap(subscription, titleKey: 'planName', primaryKeys: const ['status', 'interval'], secondaryKeys: const ['currentPeriodEnd'])],
          secondaryEmpty: 'Subscription details will appear here after activation.',
        );
      case ClientSection.agreements:
        final agreements = await repo.fetchAgreements();
        final notifications = await repo.fetchNotifications();
        return _ClientSectionData(
          eyebrow: 'Service footing',
          title: 'Agreements and service record',
          subtitle: 'Keep the formal service layer and notices visible from one place.',
          metrics: [
            _Metric('Agreements', '${agreements.length}'),
            _Metric('Notices', '${notifications.length}'),
          ],
          primaryTitle: 'Agreements',
          primaryRows: agreements.map((item) => _rowFromMap(item, titleKey: 'title', primaryKeys: const ['status'], secondaryKeys: const ['updatedAt'])).toList(),
          primaryEmpty: 'No agreements are available yet.',
          secondaryTitle: 'Notifications',
          secondaryRows: notifications.map((item) => _rowFromMap(item, titleKey: 'title', primaryKeys: const ['kind'], secondaryKeys: const ['createdAt'])).toList(),
          secondaryEmpty: 'No notices are available right now.',
        );
      case ClientSection.statements:
        final statements = await repo.fetchStatements();
        final emails = await repo.fetchEmailDispatches();
        return _ClientSectionData(
          eyebrow: 'Recorded summaries',
          title: 'Statements and dispatch history',
          subtitle: 'Review formal summaries and what has already been sent from the system.',
          metrics: [
            _Metric('Statements', '${statements.length}'),
            _Metric('Dispatches', '${emails.length}'),
          ],
          primaryTitle: 'Statements',
          primaryRows: statements.map((item) => _rowFromMap(item, titleKey: 'statementNumber', primaryKeys: const ['status'], secondaryKeys: const ['periodEnd'])).toList(),
          primaryEmpty: 'No statements are available yet.',
          secondaryTitle: 'Email dispatch history',
          secondaryRows: emails.map((item) => _rowFromMap(item, titleKey: 'subject', primaryKeys: const ['status'], secondaryKeys: const ['sentAt'])).toList(),
          secondaryEmpty: 'No dispatches are available yet.',
        );
      case ClientSection.account:
        final profile = await repo.fetchClientProfile();
        final client = _asMap(profile['client']);
        return _ClientSectionData(
          eyebrow: 'Account',
          title: 'Account profile and identity',
          subtitle: 'Keep the commercial identity behind the workspace current and usable.',
          metrics: [
            _Metric('Plan', _read(client, 'selectedPlan', fallback: session.selectedPlan?.toUpperCase() ?? 'N/A')),
            _Metric('Timezone', _read(client, 'primaryTimezone', fallback: 'Not set')),
            _Metric('Currency', _read(client, 'currencyCode', fallback: 'USD')),
          ],
          primaryTitle: 'Profile',
          primaryRows: [
            _DataRow(title: _read(client, 'displayName', fallback: 'Client account'), primary: _read(client, 'legalName'), secondary: _read(client, 'websiteUrl')),
            _DataRow(title: 'Contact and routing', primary: _read(client, 'primaryEmail', fallback: session.email), secondary: _read(client, 'bookingUrl')),
          ],
          primaryEmpty: 'No profile details are available.',
          secondaryTitle: 'Workspace state',
          secondaryRows: [
            _DataRow(title: 'Email verification', primary: session.emailVerified ? 'Verified' : 'Pending', secondary: session.email),
            _DataRow(title: 'Setup completion', primary: session.hasSetupCompleted ? 'Complete' : 'Pending', secondary: session.selectedPlan ?? ''),
            _DataRow(title: 'Subscription state', primary: session.subscriptionStatus.toUpperCase(), secondary: session.selectedTier ?? 'focused'),
          ],
          secondaryEmpty: 'No account state is available.',
        );
      case ClientSection.overview:
      default:
        final overview = await repo.fetchOverview();
        final billing = _asMap(overview['billing']);
        final activity = _asMap(overview['activity']);
        final communications = _asMap(overview['communications']);
        final client = _asMap(overview['client']);
        return _ClientSectionData(
          eyebrow: 'Client workspace',
          title: 'Current standing at a glance',
          subtitle: 'See where the account sits now across service, billing, communication, and live movement.',
          notice: 'Workspace state reflects your current setup, plan selection, and subscription standing.',
          metrics: [
            _Metric('Outstanding', _money(billing['outstandingCents'])),
            _Metric('Replies', _number(activity['replies'])),
            _Metric('Meetings', _number(activity['meetings'])),
            _Metric('Open notices', _number(communications['openNotifications'])),
          ],
          primaryTitle: 'Account view',
          primaryRows: [
            _DataRow(
              title: _read(client, 'displayName', fallback: 'Client account'),
              primary: [_read(client, 'status'), _read(client, 'industry')].where((e) => e.isNotEmpty).join(' · '),
              secondary: [_read(client, 'websiteUrl'), _read(client, 'primaryTimezone')].where((e) => e.isNotEmpty).join(' · '),
            ),
            _DataRow(
              title: 'Coverage and service',
              primary: [_read(client, 'selectedPlan'), _read(client, 'selectedTier')].where((e) => e.isNotEmpty).join(' · '),
              secondary: 'Review account to refine identity, booking links, and profile details.',
            ),
          ],
          primaryEmpty: 'No account summary is available.',
          secondaryTitle: 'Billing and movement',
          secondaryRows: [
            _DataRow(title: 'Invoices', primary: _number(billing['invoiceCount']), secondary: '${_money(billing['collectedCents'])} collected'),
            _DataRow(title: 'Payments due', primary: _money(billing['outstandingCents']), secondary: '${_number(activity['campaigns'])} campaigns in view'),
            _DataRow(title: 'Communications', primary: _number(communications['emailDispatches']), secondary: '${_number(communications['openNotifications'])} open notices'),
          ],
          secondaryEmpty: 'No live movement is available.',
        );
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});
  final _ClientSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data.eyebrow, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 10),
        Text(data.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(data.subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.publicSurfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.publicLine)),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
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
          return Column(children: [for (int i = 0; i < metrics.length; i++) ...[
            _MetricCard(metric: metrics[i]),
            if (i != metrics.length - 1) const SizedBox(height: 12),
          ]]);
        }
        return Row(children: [for (int i = 0; i < metrics.length; i++) ...[
          Expanded(child: _MetricCard(metric: metrics[i])),
          if (i != metrics.length - 1) const SizedBox(width: 12),
        ]]);
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(metric.label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Text(metric.value, style: Theme.of(context).textTheme.headlineMedium),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.rows, required this.empty});
  final String title;
  final List<_DataRow> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          Text(empty, style: Theme.of(context).textTheme.bodyMedium)
        else
          for (int i = 0; i < rows.length; i++) ...[
            _RowTile(row: rows[i]),
            if (i != rows.length - 1) const Divider(height: 22),
          ],
      ]),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});
  final _DataRow row;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(row.title, style: Theme.of(context).textTheme.titleLarge),
      if (row.primary.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(row.primary, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicText)),
      ],
      if (row.secondary.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(row.secondary, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ]);
  }
}

class _ClientSectionData {
  const _ClientSectionData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.notice,
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
  final String? notice;
  final List<_Metric> metrics;
  final String primaryTitle;
  final List<_DataRow> primaryRows;
  final String primaryEmpty;
  final String secondaryTitle;
  final List<_DataRow> secondaryRows;
  final String secondaryEmpty;
}

class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
}

class _DataRow {
  const _DataRow({required this.title, this.primary = '', this.secondary = ''});
  final String title;
  final String primary;
  final String secondary;
}

_DataRow _rowFromMap(dynamic raw, {required String titleKey, List<String> primaryKeys = const [], List<String> secondaryKeys = const []}) {
  final map = _asMap(raw);
  return _DataRow(
    title: _read(map, titleKey, fallback: 'Record'),
    primary: primaryKeys.map((key) => _read(map, key)).where((value) => value.isNotEmpty).join(' · '),
    secondary: secondaryKeys.map((key) => _read(map, key)).where((value) => value.isNotEmpty).join(' · '),
  );
}

Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : const {};
String _read(dynamic source, String key, {String fallback = ''}) {
  final map = _asMap(source);
  final value = map[key];
  if (value == null) return fallback;
  return value.toString();
}
String _number(dynamic value) => value == null ? '0' : value.toString();
String _money(dynamic cents) {
  final amount = cents is num ? cents / 100 : 0;
  return '\$${amount.toStringAsFixed(2)}';
}

Future<void> openExternalUrl(String? url) async {
  final uri = Uri.tryParse(url ?? '');
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
