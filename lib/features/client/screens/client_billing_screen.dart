import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/core/platform/billing_gate.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_workspace_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/commercial_boundary.dart';
import 'package:orchestrate_app/features/client/widgets/store_subscribe_panel.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/pricing_config.dart';

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
      // Whether anything can be activated at all, from the one commercial
      // authority every rail reads. Asked rather than assumed: this page used
      // to offer activation on the strength of "no subscription exists",
      // which is a different fact from "activation is open".
      _billingRepository.fetchPricingCatalog(),
    ]);
    return _BillingData(
      overview: asMap(results[0]),
      subscription: asMap(results[1]),
      invoices: asList(results[2]),
      agreements: asList(results[3]),
      statements: asList(results[4]),
      reminders: asList(results[5]),
      activation: (results[6] as PricingCatalog).activation,
    );
  }

  void _retry() {
    setState(() {
      _portalError = null;
      _future = _load();
    });
  }

  Future<void> _openPortal() async {
    // App Store §3.1.1 — never open the external Stripe billing
    // portal from the iOS native app. The button is hidden on iOS;
    // this guard is a no-op fallback.
    if (!externalPurchaseAllowed) return;

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

  /// Whether the payment provider holds anything for this organisation.
  ///
  /// Activation and management are different actions and only one of them is
  /// available at a time. Showing a management portal to a business with no
  /// subscription is offering to manage nothing.
  bool _hasSubscription(dynamic data) {
    final record = data.subscription;
    if (record is! Map) return false;
    final status = '${record['status'] ?? ''}'.toUpperCase();
    return status.isNotEmpty && status != 'NONE' && status != 'CANCELED';
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
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Billing is temporarily unavailable',
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
          purchaseAllowed: externalPurchaseAllowed,
          activation: data.activation,
        );

        return ClientPage(
          eyebrow: 'Billing',
          title: 'Billing and service standing',
          subtitle: externalPurchaseAllowed
              ? 'What your organisation is entitled to, and the billing '
                  'record behind it.'
              : 'What your organisation is entitled to. '
                  '$kIosPlanManagementNotice',
          banner: banner,
          actions: [
            // ACTIVATION AND MANAGEMENT ARE DIFFERENT ACTIONS.
            //
            // A business with no subscription was shown "Open billing portal"
            // and nothing else — a portal for managing a subscription that
            // does not exist, on a page that had just told them managed
            // execution starts once a plan is activated. There was no way to
            // activate anywhere in the product.
            //
            // And activation is only offered when it is genuinely open. It is
            // frozen closed today, so the honest action is the conversation
            // that actually sets terms — not a button whose only destination
            // is a refusal.
            if (externalPurchaseAllowed &&
                !_hasSubscription(data) &&
                data.activation.open)
              FilledButton.icon(
                onPressed: () => context.go('/client/subscribe'),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Activate a plan'),
              ),
            if (externalPurchaseAllowed &&
                !_hasSubscription(data) &&
                !data.activation.open)
              OutlinedButton.icon(
                onPressed: () => context.go('/client/support'),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Talk to us about commercial terms'),
              ),
            if (externalPurchaseAllowed && _hasSubscription(data))
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
            // WHAT THE ORGANISATION IS ENTITLED TO, FROM THE ONE AUTHORITY
            // THAT DECIDES IT.
            //
            // Everything below this reads a Stripe subscription row. That row
            // is evidence about one rail: it says nothing about a grant, and
            // nothing about a purchase made through the App Store or Play. Four
            // rows in this database still read ACTIVE with periods that ended
            // in May. Leading with the derivation means the first thing a
            // person reads is the answer the rest of the product acts on.
            const EntitlementSummary(),
            const SizedBox(height: 18),
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
            // In a store build this is where service is actually bought. It
            // renders nothing on web and desktop, which are billed directly.
            const StoreSubscribePanel(),
            if (inAppPurchaseAllowed) const SizedBox(height: 18),
            ClientPanel(
              title: 'Subscription record',
              // Named as a record rather than as the answer. Kept because it is
              // legitimate administrative history — what the payment rail holds
              // and when — and demoted because it is not what governs the
              // workspace.
              subtitle: 'What the payment provider holds. Entitlement is stated '
                  'above and is what the product acts on.',
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
                              'No invoices issued yet. Invoices for this account are generated automatically each billing cycle once your subscription is active.')
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
  required bool purchaseAllowed,
  required CommercialActivation activation,
}) {
  // Apple §3.1.1 — strip portal/checkout call-outs on iOS. Banner
  // copy must report state without instructing the user to act
  // through an external payment surface.
  final portalInstruction = purchaseAllowed
      ? 'Open the billing portal to resolve.'
      : kIosPlanManagementNotice;
  final portalHint = purchaseAllowed
      ? 'The portal is here when you need to manage payment or subscription details.'
      : kIosPlanManagementNotice;

  if (portalError != null) {
    return ClientStatusBanner(
      tone: ClientBannerTone.warning,
      title: 'Billing portal needs attention',
      message:
          'The portal could not open. If you do nothing, billing changes must wait until portal access is available.',
    );
  }
  final normalized = status.toLowerCase().trim();
  final end = DateTime.tryParse('${periodEnd ?? ''}');
  final expiring = end != null &&
      end.toLocal().isAfter(DateTime.now()) &&
      end.toLocal().difference(DateTime.now()).inDays <= 7;

  switch (normalized) {
    case 'active':
      return ClientStatusBanner(
        tone: ClientBannerTone.success,
        title: 'Billing is active',
        message:
            'Managed execution is running under your lane. No billing action is required. $portalHint',
      );
    case 'trialing':
    case 'trial':
      return ClientStatusBanner(
        tone: expiring ? ClientBannerTone.warning : ClientBannerTone.info,
        title: expiring ? 'Trial ends soon' : 'Trial is active',
        message: purchaseAllowed
            ? 'Full managed execution runs during the trial. Billing follows the subscription terms automatically.'
            : 'Full managed execution runs during the trial. Billing '
                'follows the current subscription terms automatically. '
                '$kIosPlanManagementNotice',
      );
    case 'past_due':
    case 'past due':
      return ClientStatusBanner(
        tone: ClientBannerTone.blocked,
        title: 'Billing past due. Dispatch paused.',
        message:
            'New dispatch is paused until billing is current. Reply ingestion on engaged threads continues, and mailbox transport, sending domain, and audit trail remain attached. $portalInstruction',
      );
    case 'paused':
      return const ClientStatusBanner(
        tone: ClientBannerTone.warning,
        title: 'Subscription paused',
        message:
            'Dispatch is paused. Reply ingestion continues for matched threads. Mailbox transport and sending domain stay attached so resuming does not require reconnect.',
      );
    case 'canceled':
    case 'cancelled':
      return const ClientStatusBanner(
        tone: ClientBannerTone.warning,
        title: 'Subscription canceled. Paid period continues.',
        message:
            'Dispatch runs through the end of the current paid period. Reply ingestion continues until then. Mailbox transport stays attached so reactivation does not require reconnect.',
      );
    case 'expired':
      return const ClientStatusBanner(
        tone: ClientBannerTone.warning,
        title: 'Subscription expired. Dispatch ended.',
        message:
            'Dispatch has ended. Reply ingestion continues as long as the mailbox transport remains attached. Reactivate the plan to restore managed execution under the same lane and tier.',
      );
    case 'incomplete':
    case 'incomplete_expired':
    case 'unpaid':
      return ClientStatusBanner(
        tone: ClientBannerTone.blocked,
        title: 'Activation incomplete at billing provider',
        message:
            'The initial payment has not posted at the billing provider yet. Dispatch is gated until activation completes. $portalInstruction',
      );
    case 'none':
    case '':
      // "Once a plan is activated" reads as a step the business can take. It
      // is not one today, and saying so is better than letting them look for
      // the button. The reason is the server's own words, so the workspace,
      // the funnel and both stores say the same thing.
      if (!activation.open) {
        return ClientStatusBanner(
          tone: ClientBannerTone.info,
          title: 'Commercial terms are set directly, not published',
          message: '${activation.says} ${activation.resolution} '
              'Identity, sending domain and mailbox transport can be prepared '
              'in the meantime.',
        );
      }
      return const ClientStatusBanner(
        tone: ClientBannerTone.info,
        title: 'Subscription not yet activated',
        message:
            'Identity, sending domain, and mailbox transport can be prepared in parallel. Managed execution starts once a plan is activated.',
      );
    default:
      return ClientStatusBanner(
        tone: ClientBannerTone.warning,
        title: 'Subscription status: $normalized',
        message:
            'Mailbox transport and reply ingestion remain attached. $portalHint',
      );
  }
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
    required this.activation,
  });

  final Map<String, dynamic> overview;
  final Map<String, dynamic> subscription;
  final List<dynamic> invoices;
  final List<dynamic> agreements;
  final List<dynamic> statements;
  final List<dynamic> reminders;
  final CommercialActivation activation;
}
