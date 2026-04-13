import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client/client_billing_repository.dart';
import '../data/repositories/client/client_outreach_repository.dart';
import '../data/repositories/client/client_workspace_repository.dart';

enum ClientSection { workspace, outreach, billing }

class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({super.key, required this.section});

  final ClientSection section;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClientViewData>(
      future: _load(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
            child: Text('This area could not load right now.'),
          );
        }

        final data = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(data: data),
              const SizedBox(height: 18),
              if (data.notice != null) ...[
                _Notice(message: data.notice!),
                const SizedBox(height: 18),
              ],
              if (data.metrics.isNotEmpty) ...[
                _MetricStrip(metrics: data.metrics),
                const SizedBox(height: 18),
              ],
              if (data.cards.isNotEmpty) ...[
                _InsightGrid(cards: data.cards),
                const SizedBox(height: 18),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  final left = _Panel(
                    title: data.primaryTitle,
                    rows: data.primaryRows,
                    emptyLabel: data.primaryEmpty,
                  );
                  final right = _Panel(
                    title: data.secondaryTitle,
                    rows: data.secondaryRows,
                    emptyLabel: data.secondaryEmpty,
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

  Future<_ClientViewData> _load(BuildContext context) async {
    final session = AuthSessionController.instance;

    switch (section) {
      case ClientSection.workspace:
        final workspaceRepo = ClientWorkspaceRepository();
        final overview = await workspaceRepo.fetchOverview();
        final subscription = await workspaceRepo.fetchSubscription();
        final notifications = await workspaceRepo.fetchNotifications();

        final client = _asMap(overview['client']);
        final activity = _asMap(overview['activity']);
        final communications = _asMap(overview['communications']);
        final billing = _asMap(overview['billing']);
        final subscriptionMap = _asMap(subscription);

        final workspaceName = _displayIdentity(client);
        final billingStatus = _title(
          _read(subscriptionMap, 'status', fallback: session.subscriptionStatus),
        );
        final subscriptionPlanName = _resolveSubscriptionPlanName(subscriptionMap);
        final subscriptionTierName = _resolveSubscriptionTierName(subscriptionMap);
        final combinedPlanLabel = _joinNonEmpty([
          subscriptionPlanName,
          subscriptionTierName,
        ]);

        return _ClientViewData(
          eyebrow: 'Workspace',
          title: workspaceName,
          subtitle: session.normalizedSubscriptionStatus == 'active'
              ? 'This is the client home for service standing, recent movement, and direct paths into outreach, meetings, billing, account, and support.'
              : 'This is the client home for setup, billing standing, support, and visible progress before service activation is complete.',
          notice: !session.hasSetupCompleted
              ? 'Setup is still incomplete. Finish setup so outreach, meetings, and billing remain grounded in the right scope.'
              : null,
          metrics: [
            _MetricData(label: 'Account state', value: _accountState(session)),
            _MetricData(
              label: 'Plan',
              value: combinedPlanLabel.isEmpty ? 'Not set' : combinedPlanLabel,
            ),
            _MetricData(
              label: 'Open notices',
              value: _countLabel(communications['openNotifications']),
            ),
          ],
          cards: const [
            _InsightCardData(
              title: 'Client home',
              body:
                  'Workspace should stay the calm overview layer, not a container for every client task.',
            ),
            _InsightCardData(
              title: 'Direct ownership',
              body:
                  'Meetings, billing, account, and help should remain separate client destinations while workspace keeps the overall view coherent.',
            ),
          ],
          primaryTitle: 'Current standing',
          primaryRows: [
            _RowData(
              title: 'Setup and service state',
              primary: _joinNonEmpty([
                session.hasSetupCompleted ? 'Setup completed' : 'Setup incomplete',
                billingStatus,
              ]),
              secondary: _joinNonEmpty([
                _read(client, 'primaryEmail', fallback: session.email),
                _read(client, 'primaryTimezone'),
              ]),
              actionLabel:
                  session.hasSetupCompleted ? null : 'Open setup',
              onTap: session.hasSetupCompleted
                  ? null
                  : () => context.go('/client/setup'),
            ),
            _RowData(
              title: 'Recent outreach movement',
              primary: _joinNonEmpty([
                '${_countValue(activity['replies'])} replies',
                '${_countValue(communications['emailDispatches'])} dispatches',
              ]),
              secondary:
                  'Use outreach for the communication record and recent reply activity.',
              actionLabel: 'Open outreach',
              onTap: () => context.go('/client/outreach'),
            ),
            _RowData(
              title: 'Meetings and outcomes',
              primary:
                  'Scheduled, completed, and missed meetings are tracked separately.',
              secondary:
                  'Use the meetings screen to view outcomes and status.',
              actionLabel: 'Open meetings',
              onTap: () => context.go('/client/meetings'),
            ),
          ],
          primaryEmpty: 'No workspace standing is available yet.',
          secondaryTitle: 'Direct actions',
          secondaryRows: [
            _RowData(
              title: 'Billing and records',
              primary: _joinNonEmpty([
                billingStatus,
                _countValue(billing['invoiceCount']) == 0
                    ? 'No invoices visible yet'
                    : '${_countValue(billing['invoiceCount'])} invoices on record',
              ]),
              secondary:
                  'Billing, invoices, statements, agreements, and reminders stay together in one client destination.',
              actionLabel: 'Open billing',
              onTap: () => context.go('/client/billing'),
            ),
            _RowData(
              title: 'Profile and account control',
              primary: _joinNonEmpty([
                _read(client, 'websiteUrl'),
                _read(client, 'bookingUrl'),
              ]).isEmpty
                  ? 'Profile and account controls are managed under account.'
                  : _joinNonEmpty([
                      _read(client, 'websiteUrl'),
                      _read(client, 'bookingUrl'),
                    ]),
              secondary:
                  'Keep profile editing and account controls separate from the workspace overview.',
              actionLabel: 'Open account',
              onTap: () => context.go('/client/account'),
            ),
            _RowData(
              title: 'Help and support',
              primary: notifications.isEmpty
                  ? 'Support is available whenever you need guidance or intervention.'
                  : '${notifications.length} notices are currently visible across support and communication records.',
              secondary:
                  'Use help for setup guidance, plan questions, billing support, workflow issues, and execution clarity.',
              actionLabel: 'Open help',
              onTap: () => context.go('/client/help'),
            ),
          ],
          secondaryEmpty: 'No direct actions are available yet.',
        );

      case ClientSection.outreach:
        final workspaceRepo = ClientWorkspaceRepository();
        final outreachRepo = ClientOutreachRepository();

        final overview = await workspaceRepo.fetchOverview();
        final replies = await outreachRepo.fetchReplies(limit: 12);
        final dispatches = await outreachRepo.fetchEmailDispatches();
        final notifications = await workspaceRepo.fetchNotifications();

        final activity = _asMap(overview['activity']);
        final communications = _asMap(overview['communications']);
        final billing = _asMap(overview['billing']);
        final hasActivePlan = session.normalizedSubscriptionStatus == 'active';

        return _ClientViewData(
          eyebrow: 'Activity',
          title: hasActivePlan
              ? 'Outreach remains visible from the client side'
              : 'Outreach view is open before activation',
          subtitle: hasActivePlan
              ? 'Replies, delivery activity, and communication records stay in view here.'
              : 'You can still review visible activity and records before service execution is active.',
          notice: !session.hasSetupCompleted
              ? 'Finish setup so outreach configuration is grounded in the right scope.'
              : null,
          metrics: [
            _MetricData(label: 'Replies', value: _countLabel(activity['replies'])),
            _MetricData(
              label: 'Dispatches',
              value: _countLabel(communications['emailDispatches']),
            ),
            _MetricData(
              label: 'Open notices',
              value: _countLabel(communications['openNotifications']),
            ),
            _MetricData(
              label: 'Billing standing',
              value: _title(
                _read(billing, 'status', fallback: session.subscriptionStatus),
              ),
            ),
          ],
          cards: const [
            _InsightCardData(
              title: 'Client-side outreach view',
              body:
                  'This area should show movement and communication truth without drifting into operator controls.',
            ),
            _InsightCardData(
              title: 'Execution gating',
              body:
                  'Execution can remain plan-gated while visibility, setup, and account control stay open.',
            ),
          ],
          primaryTitle: 'Recent replies',
          primaryRows: replies
              .map(
                (item) => _RowData(
                  title: _firstNonEmpty([
                    _read(_asMap(item), 'subjectLine'),
                    _read(_asMap(item), 'fromEmail'),
                    'Reply',
                  ]),
                  primary: _joinNonEmpty([
                    _title(_read(_asMap(item), 'intent')),
                    _title(_read(_asMap(item), 'status')),
                  ]),
                  secondary: _joinNonEmpty([
                    _read(_asMap(item), 'receivedAt'),
                    _read(_asMap(_asMap(item)['lead']), 'companyName'),
                  ]),
                ),
              )
              .toList(),
          primaryEmpty: 'No reply activity is visible yet.',
          secondaryTitle: 'Communication record',
          secondaryRows: [
            ...dispatches.take(8).map(
                  (item) => _RowData(
                    title: _firstNonEmpty([
                      _read(_asMap(item), 'subject'),
                      'Email dispatch',
                    ]),
                    primary: _joinNonEmpty([
                      _title(_read(_asMap(item), 'status')),
                      _read(_asMap(item), 'deliveryChannel'),
                    ]),
                    secondary: _joinNonEmpty([
                      _read(_asMap(item), 'sentAt'),
                      _read(_asMap(item), 'createdAt'),
                    ]),
                  ),
                ),
            ...notifications.take(4).map(
                  (item) => _RowData(
                    title: _firstNonEmpty([
                      _read(_asMap(item), 'title'),
                      'Notice',
                    ]),
                    primary: _joinNonEmpty([
                      _title(_read(_asMap(item), 'status')),
                      _title(_read(_asMap(item), 'severity')),
                    ]),
                    secondary: _read(_asMap(item), 'createdAt'),
                  ),
                ),
          ],
          secondaryEmpty: 'No outreach record is visible yet.',
        );

      case ClientSection.billing:
        final billingRepo = ClientBillingRepository();

        final subscription = await billingRepo.fetchSubscription();
        final invoices = await billingRepo.fetchInvoices();
        final statements = await billingRepo.fetchStatements();
        final agreements = await billingRepo.fetchAgreements();
        final reminders = await billingRepo.fetchReminders();

        final subscriptionMap = _asMap(subscription);
        final subscriptionState = _title(
          _read(subscriptionMap, 'status', fallback: session.subscriptionStatus),
        );
        final subscriptionPlanName = _resolveSubscriptionPlanName(subscriptionMap);
        final subscriptionTierName = _resolveSubscriptionTierName(subscriptionMap);

        return _ClientViewData(
          eyebrow: 'Commercial relationship',
          title: subscription == null
              ? 'Billing record is not active yet'
              : 'Billing, records, and reminders stay together',
          subtitle: subscription == null
              ? 'You can still see the billing section before activation.'
              : 'Invoices, statements, agreements, and reminders are organized here under one billing surface.',
          notice: subscription == null
              ? 'Subscription details will appear here after activation.'
              : null,
          metrics: [
            _MetricData(
              label: 'Service',
              value: subscriptionPlanName,
            ),
            _MetricData(
              label: 'Tier',
              value: subscriptionTierName,
            ),
            _MetricData(label: 'Status', value: subscriptionState),
            _MetricData(label: 'Invoices', value: '${invoices.length}'),
            _MetricData(label: 'Statements', value: '${statements.length}'),
          ],
          cards: const [
            _InsightCardData(
              title: 'One billing destination',
              body:
                  'Billing should hold the full commercial record rather than scatter documents across the shell.',
            ),
            _InsightCardData(
              title: 'Powered by Stripe',
              body:
                  'Subscription actions and portal access stay under the billing layer, not as floating routes.',
            ),
          ],
          primaryTitle: 'Financial records',
          primaryRows: [
            ...invoices.take(8).map(
                  (item) => _RowData(
                    title: _firstNonEmpty([
                      _read(_asMap(item), 'invoiceNumber'),
                      'Invoice',
                    ]),
                    primary: _joinNonEmpty([
                      _title(_read(_asMap(item), 'status')),
                      _read(_asMap(item), 'currencyCode'),
                    ]),
                    secondary: _joinNonEmpty([
                      _read(_asMap(item), 'dueDate'),
                      _read(_asMap(item), 'createdAt'),
                    ]),
                  ),
                ),
            ...statements.take(4).map(
                  (item) => _RowData(
                    title: _firstNonEmpty([
                      _read(_asMap(item), 'statementNumber'),
                      'Statement',
                    ]),
                    primary: _title(_read(_asMap(item), 'status')),
                    secondary: _joinNonEmpty([
                      _read(_asMap(item), 'periodEnd'),
                      _read(_asMap(item), 'createdAt'),
                    ]),
                  ),
                ),
          ],
          primaryEmpty: 'No billing records are available yet.',
          secondaryTitle: 'Agreements and reminders',
          secondaryRows: [
            ...agreements.take(6).map(
                  (item) => _RowData(
                    title: _firstNonEmpty([
                      _read(_asMap(item), 'title'),
                      'Agreement',
                    ]),
                    primary: _title(_read(_asMap(item), 'status')),
                    secondary: _read(_asMap(item), 'updatedAt'),
                  ),
                ),
            ...reminders.take(6).map(
                  (item) => _RowData(
                    title: _firstNonEmpty([
                      _read(_asMap(item), 'title'),
                      'Reminder',
                    ]),
                    primary: _joinNonEmpty([
                      _title(_read(_asMap(item), 'status')),
                      _title(_read(_asMap(item), 'kind')),
                    ]),
                    secondary: _joinNonEmpty([
                      _read(_asMap(item), 'scheduledAt'),
                      _read(_asMap(item), 'createdAt'),
                    ]),
                  ),
                ),
          ],
          secondaryEmpty: 'No agreements or reminders are available yet.',
        );
    }
  }

  Future<void> _openBillingPortal() async {
    final billingRepo = ClientBillingRepository();
    final url = await billingRepo.createBillingPortalSession();
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});

  final _ClientViewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.eyebrow,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            data.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.publicText,
            ),
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: [
              for (int i = 0; i < metrics.length; i++) ...[
                _MetricTile(metric: metrics[i]),
                if (i != metrics.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < metrics.length; i++) ...[
              Expanded(child: _MetricTile(metric: metrics[i])),
              if (i != metrics.length - 1) const SizedBox(width: 12),
            ],
          ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(metric.value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _InsightGrid extends StatelessWidget {
  const _InsightGrid({required this.cards});

  final List<_InsightCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                _InsightCard(card: cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _InsightCard(card: cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.card});

  final _InsightCardData card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(card.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.rows,
    required this.emptyLabel,
  });

  final String title;
  final List<_RowData> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < rows.length; i++) ...[
              _RowTile(row: rows[i]),
              if (i != rows.length - 1) const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final _RowData row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.title, style: Theme.of(context).textTheme.titleLarge),
        if (row.primary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            row.primary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicText,
                ),
          ),
        ],
        if (row.secondary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            row.secondary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
        if (row.actionLabel != null && row.onTap != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: row.onTap, child: Text(row.actionLabel!)),
        ],
      ],
    );
  }
}

class _ClientViewData {
  const _ClientViewData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.notice,
    this.metrics = const [],
    this.cards = const [],
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
  final List<_MetricData> metrics;
  final List<_InsightCardData> cards;
  final String primaryTitle;
  final List<_RowData> primaryRows;
  final String primaryEmpty;
  final String secondaryTitle;
  final List<_RowData> secondaryRows;
  final String secondaryEmpty;
}

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class _InsightCardData {
  const _InsightCardData({required this.title, required this.body});

  final String title;
  final String body;
}

class _RowData {
  const _RowData({
    required this.title,
    this.primary = '',
    this.secondary = '',
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String primary;
  final String secondary;
  final String? actionLabel;
  final VoidCallback? onTap;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String _read(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _title(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return 'Not set';
  return normalized
      .split(RegExp(r'[-_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

String _displayIdentity(Map<String, dynamic> client) {
  return _firstNonEmpty([
    _read(client, 'displayName'),
    _read(client, 'legalName'),
    _read(client, 'brandName'),
    'Client account',
  ]);
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _joinNonEmpty(List<String> values) {
  return values.where((value) => value.trim().isNotEmpty).join(' · ');
}

int _countValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _countLabel(dynamic value) => '${_countValue(value)}';

String _accountState(AuthSessionController session) {
  if (!session.emailVerified) return 'Verification pending';
  if (!session.hasSetupCompleted) return 'Draft';
  if (session.normalizedSubscriptionStatus == 'active') return 'Active';
  return 'Review';
}

String _resolveSubscriptionPlanName(Map<String, dynamic> subscriptionMap) {
  final explicitPlan = _read(subscriptionMap, 'plan');
  if (explicitPlan.isNotEmpty) return _title(explicitPlan);

  final planName = _read(subscriptionMap, 'planName');
  if (planName.isNotEmpty) return _title(planName);

  final lane = _read(subscriptionMap, 'lane');
  if (lane.isNotEmpty) return _title(lane);

  final planCode = _read(subscriptionMap, 'planCode').toUpperCase();
  if (planCode.contains('REVENUE')) return 'Revenue';
  if (planCode.contains('OPPORTUNITY')) return 'Opportunity';

  return 'Not set';
}

String _resolveSubscriptionTierName(Map<String, dynamic> subscriptionMap) {
  final tier = _read(subscriptionMap, 'tier');
  if (tier.isNotEmpty) return _title(tier);

  final planCode = _read(subscriptionMap, 'planCode').toUpperCase();
  if (planCode.contains('PRECISION')) return 'Precision';
  if (planCode.contains('MULTI')) return 'Multi';
  if (planCode.contains('FOCUSED')) return 'Focused';

  return 'Not set';
}
