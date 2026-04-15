import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client/client_billing_repository.dart';
import '../data/repositories/client/client_workspace_repository.dart';

enum ClientSection { workspace, billing }

class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({super.key, required this.section});
  final ClientSection section;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ViewData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('This area could not load right now.'));
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(title: data.title, subtitle: data.subtitle),
              const SizedBox(height: 18),
              _MetricRow(metrics: data.metrics),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final left = _Panel(title: data.primaryTitle, rows: data.primaryRows, emptyLabel: data.primaryEmpty);
                final right = _Panel(title: data.secondaryTitle, rows: data.secondaryRows, emptyLabel: data.secondaryEmpty);
                if (stacked) return Column(children: [left, const SizedBox(height: 18), right]);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: left), const SizedBox(width: 18), Expanded(flex: 5, child: right)]);
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
    final overview = await workspaceRepo.fetchOverview();
    final notifications = await workspaceRepo.fetchNotifications();
    final subscription = await workspaceRepo.fetchSubscription();
    final invoices = await billingRepo.fetchInvoices();

    final client = _asMap(overview['client']);
    final activity = _asMap(overview['activity']);
    final communications = _asMap(overview['communications']);
    final billing = _asMap(overview['billing']);
    final title = _firstNonEmpty([_read(client, 'displayName'), session.workspaceName, session.fullName, 'Client workspace']);

    if (section == ClientSection.billing) {
      return _ViewData(
        title: 'Billing and service standing',
        subtitle: 'Billing stays separate from targeting, leads, and meetings so account standing remains clear.',
        metrics: [
          _Metric('Status', _title(_read(subscription ?? const {}, 'status', fallback: session.subscriptionStatus))),
          _Metric('Invoices', '${invoices.length}'),
          _Metric('Agreements', _countLabel(billing['agreementCount'] ?? billing['agreements'])),
        ],
        primaryTitle: 'Billing record',
        primaryRows: invoices.take(12).map((item) {
          final map = _asMap(item);
          return _Row(
            title: _firstNonEmpty([_read(map, 'invoiceNumber'), _read(map, 'title'), 'Invoice']),
            primary: _join([_title(_read(map, 'status')), _read(map, 'amountFormatted'), _read(map, 'currency')]),
            secondary: _join([_read(map, 'issuedAt'), _read(map, 'dueAt')]),
          );
        }).toList(),
        primaryEmpty: 'No invoices are visible yet.',
        secondaryTitle: 'Direct actions',
        secondaryRows: [
          _Row(title: 'Campaign targeting', primary: 'Keep market scope in one place before new sourcing runs.', secondary: 'Countries, industries, notes, and boundaries live in campaigns.', actionLabel: 'Open campaigns', route: '/client/campaigns'),
          _Row(title: 'Lead generation', primary: 'Lead sourcing and sendability are tracked separately from billing.', secondary: 'Use leads to see what is found, ready, and moving.', actionLabel: 'Open leads', route: '/client/leads'),
        ],
        secondaryEmpty: 'No direct actions are available.',
      );
    }

    return _ViewData(
      title: title,
      subtitle: session.normalizedSubscriptionStatus == 'active'
          ? 'Workspace keeps the full lead generation to meeting flow visible without duplicating targeting or operator views.'
          : 'Workspace keeps setup, billing standing, and activation readiness visible before service is fully active.',
      metrics: [
        _Metric('Account state', session.hasSetupCompleted ? 'Setup complete' : 'Setup incomplete'),
        _Metric('Replies', _countLabel(activity['replies'])),
        _Metric('Meetings', _countLabel(activity['meetings'] ?? activity['meetingCount'])),
        _Metric('Dispatches', _countLabel(communications['emailDispatches'])),
      ],
      primaryTitle: 'Current flow',
      primaryRows: [
        _Row(title: 'Campaign targeting', primary: 'Set scope, industries, and market boundaries in one place only.', secondary: 'Campaigns is now the canonical targeting surface for lead generation.', actionLabel: 'Open campaigns', route: '/client/campaigns'),
        _Row(title: 'Lead generation', primary: _join([
          '${_countValue(activity['leadCount'] ?? activity['leads'])} leads',
          '${_countValue(activity['sendableLeadCount'] ?? activity['sendableLeads'])} sendable',
        ]), secondary: 'Use leads to review sourcing, sendability, outreach movement, and reply state.', actionLabel: 'Open leads', route: '/client/leads'),
        _Row(title: 'Meetings', primary: _join([
          '${_countValue(activity['meetingCount'] ?? activity['meetings'])} meetings',
          '${_countValue(activity['handoffPending'] ?? activity['proposedMeetings'])} handoff pending',
        ]), secondary: 'Meeting truth stays separate from lead generation so proposed and booked are not blurred.', actionLabel: 'Open meetings', route: '/client/meetings'),
      ],
      primaryEmpty: 'No workspace movement is visible yet.',
      secondaryTitle: 'Account and support',
      secondaryRows: [
        _Row(title: 'Billing standing', primary: _title(_read(subscription ?? const {}, 'status', fallback: session.subscriptionStatus)), secondary: 'Invoices, statements, and service standing stay under billing.', actionLabel: 'Open billing', route: '/client/billing'),
        _Row(title: 'Account control', primary: _join([_read(client, 'websiteUrl'), _read(client, 'bookingUrl')]), secondary: 'Profile, password, and account settings stay separate from execution.', actionLabel: 'Open account', route: '/client/account'),
        _Row(title: 'Support', primary: notifications.isEmpty ? 'Support is available whenever you need guidance.' : '${notifications.length} notices currently visible.', secondary: 'Help stays available without mixing with leads or campaigns.', actionLabel: 'Open help', route: '/client/help'),
      ],
      secondaryEmpty: 'No account actions are visible yet.',
    );
  }
}

class _ViewData {
  const _ViewData({required this.title, required this.subtitle, required this.metrics, required this.primaryTitle, required this.primaryRows, required this.primaryEmpty, required this.secondaryTitle, required this.secondaryRows, required this.secondaryEmpty});
  final String title; final String subtitle; final List<_Metric> metrics; final String primaryTitle; final List<_Row> primaryRows; final String primaryEmpty; final String secondaryTitle; final List<_Row> secondaryRows; final String secondaryEmpty;
}
class _Metric { const _Metric(this.label, this.value); final String label; final String value; }
class _Row { const _Row({required this.title, required this.primary, required this.secondary, this.actionLabel, this.route}); final String title; final String primary; final String secondary; final String? actionLabel; final String? route; }

class _Hero extends StatelessWidget { const _Hero({required this.title, required this.subtitle}); final String title; final String subtitle; @override Widget build(BuildContext context){ return Container(width: double.infinity,padding: const EdgeInsets.all(28),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12), Text(subtitle, style: Theme.of(context).textTheme.bodyLarge)])); }}
class _MetricRow extends StatelessWidget { const _MetricRow({required this.metrics}); final List<_Metric> metrics; @override Widget build(BuildContext context){ return LayoutBuilder(builder:(context,constraints){ final children=metrics.map((m)=>Container(padding: const EdgeInsets.all(18),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(22),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(m.label, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 10), Text(m.value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))]))).toList(); if (constraints.maxWidth < 900) return Column(children:[for(final child in children)...[child,const SizedBox(height:12)]]); return Row(children:[for(int i=0;i<children.length;i++) ...[Expanded(child: children[i]), if(i<children.length-1) const SizedBox(width:12)]]);}); }}
class _Panel extends StatelessWidget { const _Panel({required this.title, required this.rows, required this.emptyLabel}); final String title; final List<_Row> rows; final String emptyLabel; @override Widget build(BuildContext context){ return Container(width: double.infinity,padding: const EdgeInsets.all(24),decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28),border: Border.all(color: AppTheme.publicLine)),child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height:16), if(rows.isEmpty) Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium) else for(int i=0;i<rows.length;i++) ...[_RowTile(row: rows[i]), if(i<rows.length-1) const Divider(height: 22)]])); }}
class _RowTile extends StatelessWidget { const _RowTile({required this.row}); final _Row row; @override Widget build(BuildContext context){ return Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(row.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), if(row.primary.isNotEmpty)...[const SizedBox(height:6), Text(row.primary, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicText))], if(row.secondary.isNotEmpty)...[const SizedBox(height:4), Text(row.secondary, style: Theme.of(context).textTheme.bodyMedium)], if(row.route!=null && row.actionLabel!=null)...[const SizedBox(height:12), FilledButton.tonal(onPressed: ()=>context.go(row.route!), child: Text(row.actionLabel!))]]); }}

Map<String, dynamic> _asMap(dynamic value){ if(value is Map<String,dynamic>) return value; if(value is Map) return value.map((k,v)=>MapEntry(k.toString(),v)); return const {}; }
String _read(Map<String,dynamic> map,String key,{String fallback=''}){ final v=map[key]; if(v==null) return fallback; final s=v.toString().trim(); return s.isEmpty ? fallback : s; }
String _title(String value){ if(value.trim().isEmpty) return 'Unknown'; return value.split(RegExp(r'[_\s-]+')).map((e)=>e.isEmpty?e:'${e[0].toUpperCase()}${e.substring(1).toLowerCase()}').join(' '); }
String _firstNonEmpty(List<String> values){ for(final v in values){ if(v.trim().isNotEmpty) return v.trim(); } return ''; }
String _join(List<String> values){ return values.where((e)=>e.trim().isNotEmpty).join(' · '); }
int _countValue(dynamic value){ if(value is num) return value.toInt(); return int.tryParse((value??'').toString()) ?? 0; }
String _countLabel(dynamic value)=>'${_countValue(value)}';
