import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_workspace_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientBillingScreen extends StatefulWidget {
  const ClientBillingScreen({super.key});

  @override
  State<ClientBillingScreen> createState() => _ClientBillingScreenState();
}

class _ClientBillingScreenState extends State<ClientBillingScreen> {
  final ClientWorkspaceRepository _workspaceRepository =
      ClientWorkspaceRepository();
  final ClientBillingRepository _billingRepository = ClientBillingRepository();
  late Future<_BillingData> _future;
  bool _openingPortal = false;
  String? _portalError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BillingData> _load() async {
    final results = await Future.wait<dynamic>([
      _workspaceRepository.fetchOverview(),
      _billingRepository.fetchSubscription(),
      _billingRepository.fetchInvoices(),
      _billingRepository.fetchAgreements(),
      _billingRepository.fetchStatements(),
      _billingRepository.fetchReminders(),
    ]);
    return _BillingData(
      overview: asMap(results[0]),
      subscription: asMap(results[1]),
      invoices: asList(results[2]),
      agreements: asList(results[3]),
      statements: asList(results[4]),
      reminders: asList(results[5]),
    );
  }

  void _retry() {
    setState(() {
      _portalError = null;
      _future = _load();
    });
  }

  Future<void> _openPortal() async {
    setState(() {
      _openingPortal = true;
      _portalError = null;
    });
    try {
      final url = await _billingRepository.createBillingPortalSession();
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('Billing portal returned an invalid URL.');
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _portalError =
            error is ApiException ? error.displayMessage : error.toString();
      });
    } finally {
      if (mounted) setState(() => _openingPortal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BillingData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading billing');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ClientErrorView(
            message:
                error is ApiException ? error.displayMessage : error.toString(),
            onRetry: _retry,
          );
        }
        final data = snapshot.data!;
        final session = AuthSessionController.instance;
        final billing = asMap(data.overview['billing']);
        final status = readText(data.subscription, 'status',
            fallback: session.subscriptionStatus);
        final currency = readText(data.subscription, 'currency',
            fallback: readText(asMap(data.overview['client']), 'currencyCode',
                fallback: 'USD'));
        final banner = _billingBanner(
          status: status,
          periodEnd: data.subscription['currentPeriodEnd'],
          portalError: _portalError,
        );

        return ClientPage(
          eyebrow: 'Billing',
          title: 'Billing and service standing',
          subtitle:
              'Confirm whether service is active, trialing, or at risk, then use the portal when billing needs attention.',
          banner: banner,
          actions: [
            FilledButton.icon(
              onPressed: _openingPortal ? null : _openPortal,
              icon: _openingPortal
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new, size: 18),
              label: Text(_openingPortal ? 'Opening' : 'Open billing portal'),
            ),
          ],
          children: [
            if (_portalError != null) ...[
              ClientPanel(
                title: 'Billing portal unavailable',
                children: [ClientEmptyState(message: _portalError!)],
              ),
              const SizedBox(height: 18),
            ],
            ClientMetricStrip(metrics: [
              ClientMetric('Status', titleCase(status)),
              ClientMetric(
                  'Plan',
                  readText(data.subscription, 'displayPlanLabel',
                      fallback: session.selectedPlanDisplay ?? 'Not set')),
              ClientMetric('Invoices', '${data.invoices.length}'),
              ClientMetric(
                  'Open balance',
                  moneyLabel(
                      asMap(asMap(billing['invoices']))['totalBalanceDueCents'],
                      currency)),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Subscription',
              children: [
                ClientInfoRow(
                  title: readText(data.subscription, 'displayPlanLabel',
                      fallback: 'No active subscription record'),
                  primary: 'Status: ${titleCase(status)}',
                  secondary: [
                    'Period start: ${dateLabel(data.subscription['currentPeriodStart'])}',
                    'Period end: ${dateLabel(data.subscription['currentPeriodEnd'])}',
                    data.subscription['isTrialing'] == true ? 'Trialing' : '',
                  ]
                      .where((item) => !item.endsWith(': ') && item.isNotEmpty)
                      .join(' · '),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Invoices',
              children: data.invoices.isEmpty
                  ? const [
                      ClientEmptyState(
                          message:
                              'No invoices are currently visible. When billing documents are issued for this account, they will appear here.')
                    ]
                  : [
                      for (final raw in data.invoices.take(20))
                        _InvoiceRow(invoice: asMap(raw), currency: currency),
                    ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Related records',
              subtitle:
                  'Usage and limits are hidden because no client usage/limits contract is currently exposed.',
              children: [
                ClientInfoRow(
                  title: 'Agreements',
                  primary: '${data.agreements.length} records',
                ),
                ClientInfoRow(
                  title: 'Statements',
                  primary: '${data.statements.length} records',
                ),
                ClientInfoRow(
                  title: 'Reminders',
                  primary: '${data.reminders.length} records',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

ClientStatusBanner _billingBanner({
  required String status,
  required dynamic periodEnd,
  required String? portalError,
}) {
  if (portalError != null) {
    return ClientStatusBanner(
      tone: ClientBannerTone.warning,
      title: 'Billing portal needs attention',
      message:
          'The portal could not open. If you do nothing, billing changes must wait until portal access is available.',
    );
  }
  final normalized = status.toLowerCase();
  final end = DateTime.tryParse('${periodEnd ?? ''}');
  final expiring = end != null &&
      end.toLocal().isAfter(DateTime.now()) &&
      end.toLocal().difference(DateTime.now()).inDays <= 7;
  if (normalized == 'past_due' || normalized == 'past due') {
    return const ClientStatusBanner(
      tone: ClientBannerTone.blocked,
      title: 'Billing requires attention',
      message:
          'The subscription is past due. Open the billing portal to resolve payment so service is not interrupted.',
    );
  }
  if (normalized == 'trialing') {
    return ClientStatusBanner(
      tone: expiring ? ClientBannerTone.warning : ClientBannerTone.info,
      title: expiring ? 'Trial ends soon' : 'Trial is active',
      message:
          'Open the billing portal when you need to manage payment details. If you do nothing, billing follows the current subscription terms.',
    );
  }
  if (normalized == 'active') {
    return const ClientStatusBanner(
      tone: ClientBannerTone.success,
      title: 'Billing is active',
      message:
          'No billing action is required right now. Use the portal only when you need to manage payment or subscription details.',
    );
  }
  return const ClientStatusBanner(
    tone: ClientBannerTone.warning,
    title: 'Billing status is not active',
    message:
        'Open the billing portal or review subscription setup. If you do nothing, service activation may remain limited.',
  );
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.currency});

  final Map<String, dynamic> invoice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return ClientInfoRow(
      title: readText(invoice, 'invoiceNumber', fallback: 'Invoice'),
      primary: [
        titleCase(readText(invoice, 'status')),
        moneyLabel(invoice['totalCents'],
            readText(invoice, 'currencyCode', fallback: currency)),
      ].where((item) => item.isNotEmpty).join(' · '),
      secondary: [
        'Issued: ${dateLabel(invoice['issuedAt'])}',
        'Due: ${dateLabel(invoice['dueAt'])}',
      ].where((item) => !item.endsWith(': ')).join(' · '),
    );
  }
}

class _BillingData {
  const _BillingData({
    required this.overview,
    required this.subscription,
    required this.invoices,
    required this.agreements,
    required this.statements,
    required this.reminders,
  });

  final Map<String, dynamic> overview;
  final Map<String, dynamic> subscription;
  final List<dynamic> invoices;
  final List<dynamic> agreements;
  final List<dynamic> statements;
  final List<dynamic> reminders;
}
