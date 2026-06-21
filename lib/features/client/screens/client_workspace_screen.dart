import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/theme/app_theme.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_workspace_repository.dart';
import 'package:orchestrate_app/features/client/models/client_experience.dart';
import 'package:orchestrate_app/features/client/widgets/client_charts.dart';
import 'package:orchestrate_app/features/client/widgets/client_experience_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

enum ClientSection { home, billing }

/// Client Home — a managed business-growth experience.
///
/// Home leads with outcome confidence: where the client's growth is
/// right now, what Orchestrate has operating for them, and the one
/// step (if any) they genuinely own. It renders the client-safe
/// experience surface — never runtime, readiness, governance, or
/// diagnostic semantics. That truth lives in the operator workspace.
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key, required this.section});
  final ClientSection section;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(
            eyebrow: 'Workspace home',
            label: 'Loading your workspace',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Workspace home is temporarily unavailable',
          );
        }
        final data = snapshot.data!;
        final experience = data.experience;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section == ClientSection.home && experience != null) ...[
                ClientMomentumCard(
                  experience: experience,
                  eyebrow: data.title,
                  onAction: experience.clientAction == null
                      ? null
                      : () => context.go(experience.clientAction!.route),
                ),
                const SizedBox(height: 18),
                _MetricRow(metrics: data.metrics),
                const SizedBox(height: 18),
                ClientConfidencePanel(
                    signals: experience.confidenceSignals),
                const SizedBox(height: 18),
              ] else ...[
                _MetricRow(metrics: data.metrics),
                const SizedBox(height: 18),
              ],
              if (section == ClientSection.home) ...[
                _HomeFunnel(summary: data.summary),
                const SizedBox(height: 18),
              ],
              LayoutBuilder(builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < WorkspaceBreakpoints.stacked;
                final left = _Panel(
                    title: data.primaryTitle,
                    rows: data.primaryRows,
                    emptyLabel: data.primaryEmpty);
                final right = _Panel(
                    title: data.secondaryTitle,
                    rows: data.secondaryRows,
                    emptyLabel: data.secondaryEmpty);
                if (stacked) {
                  return Column(
                      children: [left, const SizedBox(height: 18), right]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: right)
                    ]);
              }),
            ],
          ),
        );
      },
    );
  }

  Future<_ViewData> _load() async {
    final session = AuthSessionController.instance;
    final workspaceRepo = ClientWorkspaceRepository();
    final billingRepo = ClientBillingRepository();
    final portalRepo = ClientPortalRepository();
    final overview = await workspaceRepo.fetchOverview();
    final notifications = await workspaceRepo.fetchNotifications();
    final subscription = await workspaceRepo.fetchSubscription();
    final invoices = await billingRepo.fetchInvoices();
    final experience = section == ClientSection.home
        ? await _safeFetchExperience(portalRepo)
        : null;
    // Precise, DB-backed qualification buckets for the home funnel + cards.
    final summary = section == ClientSection.home
        ? await _safeFetchSummary(portalRepo)
        : const <String, dynamic>{};
    final byQualification = _asMap(summary['byQualification']);

    final client = _asMap(overview['client']);
    final activity = _asMap(overview['activity']);
    final communications = _asMap(overview['communications']);
    final billing = _asMap(overview['billing']);
    final title = _firstNonEmpty([
      _read(client, 'displayName'),
      session.workspaceName,
      session.fullName,
      'Client workspace'
    ]);

    if (section == ClientSection.billing) {
      return _ViewData(
        title: 'Billing and service standing',
        subtitle:
            'Service standing and account billing.',
        subscription: subscription ?? const {},
        metrics: [
          _Metric(
              'Status',
              _title(_read(subscription ?? const {}, 'status',
                  fallback: session.subscriptionStatus))),
          _Metric('Invoices', '${invoices.length}'),
          _Metric('Agreements',
              _countLabel(billing['agreementCount'] ?? billing['agreements'])),
        ],
        primaryTitle: 'Billing record',
        primaryRows: invoices.take(12).map((item) {
          final map = _asMap(item);
          return _Row(
            title: _firstNonEmpty(
                [_read(map, 'invoiceNumber'), _read(map, 'title'), 'Invoice']),
            primary: _join([
              _title(_read(map, 'status')),
              _read(map, 'amountFormatted'),
              _read(map, 'currency')
            ]),
            secondary: _join([_read(map, 'issuedAt'), _read(map, 'dueAt')]),
          );
        }).toList(),
        primaryEmpty: 'No invoices are visible yet.',
        secondaryTitle: 'Direct actions',
        secondaryRows: [
          _Row(
              title: 'Representation scope',
              primary:
                  'Business identity, ICP, voice, and authorization.',
              secondary:
                  'This scope is how Orchestrate represents you across every outreach.',
              actionLabel: 'Open representation',
              route: '/client/representation'),
          _Row(
              title: 'Contacts and intelligence',
              primary:
                  'Sourced contacts and reach are tracked separately from billing.',
              secondary:
                  'Use contacts to review sourced records and engagement.',
              actionLabel: 'Open contacts',
              route: '/app/contacts'),
        ],
        secondaryEmpty: 'No direct actions are available.',
      );
    }

    return _ViewData(
      title: title,
      subtitle:
          'Representation, outreach, and engagement in one place.',
      subscription: subscription ?? const {},
      experience: experience,
      // Precise, DB-backed operating buckets read from
      // /client/opportunities/summary (Lead rows, client-scoped). Replaces
      // the prior soft "In market" / "Conversations" labels.
      summary: summary,
      metrics: [
        _Metric('Evaluated', '${_countValue(summary['entitiesEvaluated'])}'),
        _Metric('Suppressed',
            '${_countValue(byQualification['suppressed'])}'),
        _Metric('Opportunities',
            '${_countValue(byQualification['qualified'])}'),
        _Metric('Dispatched',
            '${_countValue(byQualification['dispatched'])}'),
      ],
      primaryTitle: 'Your growth operation',
      primaryRows: [
        _Row(
            title: 'Representation scope',
            primary:
                'Business identity, ICP, voice, and authorization.',
            secondary:
                'This scope is how Orchestrate represents you across every outreach.',
            actionLabel: 'Open representation',
            route: '/client/representation'),
        _Row(
            title: 'Contacts and intelligence',
            primary: _join([
              '${_countValue(activity['leadCount'] ?? activity['leads'])} contacts',
              '${_countValue(activity['sendableLeadCount'] ?? activity['sendableLeads'])} reachable',
            ]),
            secondary:
                'Review the businesses Orchestrate has sourced and is engaging for you.',
            actionLabel: 'Open contacts',
            route: '/app/contacts'),
        _Row(
            title: 'Meetings',
            primary: _join([
              '${_countValue(activity['meetingCount'] ?? activity['meetings'])} meetings',
              '${_countValue(activity['handoffPending'] ?? activity['proposedMeetings'])} being coordinated',
            ]),
            secondary:
                'Conversations and meeting coordination, surfaced in one place.',
            actionLabel: 'Open activity',
            route: '/app/activity'),
      ],
      primaryEmpty: 'Your growth operation is coming online.',
      secondaryTitle: 'Account and support',
      secondaryRows: [
        _Row(
            title: 'Billing standing',
            primary: _title(_read(subscription ?? const {}, 'status',
                fallback: session.subscriptionStatus)),
            secondary:
                'Invoices, statements, and service standing stay under billing.',
            actionLabel: 'Open billing',
            route: '/app/billing'),
        _Row(
            title: 'Account control',
            primary: _join(
                [_read(client, 'websiteUrl'), _read(client, 'bookingUrl')]),
            secondary:
                'Profile, password, and account settings stay separate from your growth operation.',
            actionLabel: 'Open account',
            route: '/app/account'),
        _Row(
            title: 'Support',
            primary: notifications.isEmpty
                ? 'Support is available whenever you need guidance.'
                : '${notifications.length} notices currently visible.',
            secondary:
                'Help stays available without mixing with contacts or meetings.',
            actionLabel: 'Open help',
            route: '/client/support'),
      ],
      secondaryEmpty: 'No account actions are visible yet.',
    );
  }
}

Future<ClientExperience?> _safeFetchExperience(
    ClientPortalRepository repo) async {
  try {
    return await repo.fetchClientExperience();
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>> _safeFetchSummary(
    ClientPortalRepository repo) async {
  try {
    return await repo.fetchOpportunitySummary();
  } catch (_) {
    return const <String, dynamic>{};
  }
}

class _ViewData {
  const _ViewData(
      {required this.title,
      required this.subtitle,
      required this.metrics,
      required this.primaryTitle,
      required this.primaryRows,
      required this.primaryEmpty,
      required this.secondaryTitle,
      required this.secondaryRows,
      required this.secondaryEmpty,
      this.subscription = const <String, dynamic>{},
      this.summary = const <String, dynamic>{},
      this.experience});
  final String title;
  final String subtitle;
  final List<_Metric> metrics;
  final Map<String, dynamic> summary;
  final String primaryTitle;
  final List<_Row> primaryRows;
  final String primaryEmpty;
  final String secondaryTitle;
  final List<_Row> secondaryRows;
  final String secondaryEmpty;
  final Map<String, dynamic> subscription;
  final ClientExperience? experience;
}

class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
}

class _Row {
  const _Row(
      {required this.title,
      required this.primary,
      required this.secondary,
      this.actionLabel,
      this.route});
  final String title;
  final String primary;
  final String secondary;
  final String? actionLabel;
  final String? route;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metrics});
  final List<_Metric> metrics;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final children = metrics
          .map((m) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.publicLine)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Text(m.value,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700))
                  ])))
          .toList();
      if (constraints.maxWidth < 900) {
        return Column(children: [
          for (final child in children) ...[child, const SizedBox(height: 12)]
        ]);
      }
      return Row(children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 12)
        ]
      ]);
    });
  }
}

/// Compact progression funnel for Home. Every stage is a live, client-
/// scoped DB count from /client/opportunities/summary. When no stage has
/// moved, a truthful empty state is shown instead of an empty chart.
class _HomeFunnel extends StatelessWidget {
  const _HomeFunnel({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final byq = _asMap(summary['byQualification']);
    final data = <ClientChartDatum>[
      ClientChartDatum('Evaluated', _countValue(summary['entitiesEvaluated']),
          tone: ClientBarTone.neutral),
      ClientChartDatum('Qualified', _countValue(byq['qualified'])),
      ClientChartDatum('Dispatch-ready', _countValue(byq['dispatchReady'])),
      ClientChartDatum('Dispatched', _countValue(byq['dispatched']),
          tone: ClientBarTone.positive),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.publicLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your operation at a glance',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (chartHasSignal(data))
          ClientBarChart(data: data)
        else
          const ClientEmptyState(
              message:
                  'Your operation is coming online. Stages fill in here as Orchestrate evaluates and dispatches for your business.'),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title, required this.rows, required this.emptyLabel});
  final String title;
  final List<_Row> rows;
  final String emptyLabel;
  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.publicLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
          else
            for (int i = 0; i < rows.length; i++) ...[
              _RowTile(row: rows[i]),
              if (i < rows.length - 1) const Divider(height: 22)
            ]
        ]));
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});
  final _Row row;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(row.title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)),
      if (row.primary.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(row.primary,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.publicText))
      ],
      if (row.secondary.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(row.secondary, style: Theme.of(context).textTheme.bodyMedium)
      ],
      if (row.route != null && row.actionLabel != null) ...[
        const SizedBox(height: 12),
        FilledButton.tonal(
            onPressed: () => context.go(row.route!),
            child: Text(row.actionLabel!))
      ]
    ]);
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

String _read(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final v = map[key];
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String _title(String value) {
  if (value.trim().isEmpty) return 'Unknown';
  return value
      .split(RegExp(r'[_\s-]+'))
      .map((e) => e.isEmpty
          ? e
          : '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}')
      .join(' ');
}

String _firstNonEmpty(List<String> values) {
  for (final v in values) {
    if (v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

String _join(List<String> values) {
  return values.where((e) => e.trim().isNotEmpty).join(' · ');
}

int _countValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

String _countLabel(dynamic value) => '${_countValue(value)}';
