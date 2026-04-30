import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/core/network/api_client.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_account_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';

class ClientSettingsScreen extends StatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  final ClientAccountRepository _accountRepository = ClientAccountRepository();
  final ClientBillingRepository _billingRepository = ClientBillingRepository();
  final ClientPortalRepository _portalRepository = ClientPortalRepository();
  final AuthRepository _authRepository = AuthRepository();
  late Future<_SettingsData> _future;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SettingsData> _load() async {
    final results = await Future.wait<dynamic>([
      _accountRepository.fetchClientProfile(),
      _billingRepository.fetchSubscription(),
      _portalRepository.fetchRepresentationAuth(),
      _portalRepository.fetchOutreach(),
      _portalRepository.fetchRecords(),
    ]);
    return _SettingsData(
      profile: asMap(results[0]),
      subscription: asMap(results[1]),
      auth: asMap(results[2]),
      outreach: asMap(results[3]),
      records: asMap(results[4]),
    );
  }

  void _retry() {
    setState(() => _future = _load());
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await _authRepository.logout();
    } catch (_) {
      // Local session cleanup still completes sign out if the network call fails.
    } finally {
      await AuthSessionController.instance.clear();
      if (mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SettingsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClientLoadingView(label: 'Loading settings');
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
        final profile = asMap(data.profile['profile']).isNotEmpty
            ? asMap(data.profile['profile'])
            : data.profile;
        final readiness = asMap(data.outreach['readiness']);
        final mailbox = asMap(data.outreach['mailbox']);
        final billingDocs = asMap(data.records['billingDocuments']);

        return ClientPage(
          eyebrow: 'Settings',
          title: readText(profile, 'displayName',
              fallback: session.workspaceName.isEmpty
                  ? 'Client workspace'
                  : session.workspaceName),
          subtitle:
              'Account details, setup state, billing state, authorization, record availability, and outreach readiness are read from backend records.',
          actions: [
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/client/account'),
              icon: const Icon(Icons.manage_accounts_outlined, size: 18),
              label: const Text('Edit profile'),
            ),
            TextButton.icon(
              onPressed: _signingOut ? null : _signOut,
              icon: _signingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, size: 18),
              label: Text(_signingOut ? 'Signing out' : 'Sign out'),
            ),
          ],
          children: [
            ClientMetricStrip(metrics: [
              ClientMetric('Setup',
                  session.hasSetupCompleted ? 'Complete' : 'Incomplete'),
              ClientMetric(
                  'Billing',
                  titleCase(readText(data.subscription, 'status',
                      fallback: session.subscriptionStatus))),
              ClientMetric(
                  'Authorization',
                  data.auth['authorized'] == true
                      ? 'Recorded'
                      : 'Not recorded'),
              ClientMetric(
                  'Mailbox', mailbox['ready'] == true ? 'Ready' : 'Not ready'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Profile',
              children: [
                ClientInfoRow(
                  title: readText(profile, 'legalName',
                      fallback: readText(profile, 'displayName')),
                  primary: [
                    readText(profile, 'primaryEmail', fallback: session.email),
                    readText(profile, 'websiteUrl'),
                    readText(profile, 'bookingUrl'),
                  ].where((part) => part.isNotEmpty).join(' · '),
                  secondary: [
                    readText(profile, 'primaryTimezone'),
                    readText(profile, 'currencyCode'),
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Setup and billing',
              children: [
                ClientInfoRow(
                  title: 'Setup state',
                  primary: session.hasSetupCompleted
                      ? 'Setup is complete.'
                      : 'Setup is incomplete.',
                  secondary: session.hasSetupCompleted
                      ? 'Campaign targeting and service preferences are available.'
                      : 'Finish setup before outreach can run.',
                ),
                ClientInfoRow(
                  title: 'Subscription',
                  primary: readText(data.subscription, 'displayPlanLabel',
                      fallback: session.selectedPlanDisplay ?? 'Not set'),
                  secondary:
                      'Status: ${titleCase(readText(data.subscription, 'status', fallback: session.subscriptionStatus))}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Authorization and readiness',
              children: [
                ClientInfoRow(
                  title: 'Representation authorization',
                  primary: data.auth['authorized'] == true
                      ? 'Current authorization is recorded.'
                      : 'Representation authorization is not recorded yet.',
                  secondary:
                      dateLabel(asMap(data.auth['latest'])['acceptedAt']),
                ),
                ClientInfoRow(
                  title: 'Outreach readiness',
                  primary: asList(readiness['blockers']).isEmpty
                      ? 'No blockers reported.'
                      : '${asList(readiness['blockers']).length} blockers reported.',
                  secondary: asList(readiness['blockers'])
                      .map((item) => readText(asMap(item), 'label'))
                      .where((item) => item.isNotEmpty)
                      .join(' · '),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Record availability',
              children: [
                ClientInfoRow(
                  title: 'Service and billing records',
                  primary:
                      '${asList(data.records['agreements']).length} agreements · ${asList(billingDocs['invoices']).length} invoices · ${asList(billingDocs['statements']).length} statements',
                ),
                ClientInfoRow(
                  title: 'Source/import records',
                  primary:
                      '${asList(asMap(data.records['sourceRecords'])['imports']).length} import batches',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SettingsData {
  const _SettingsData({
    required this.profile,
    required this.subscription,
    required this.auth,
    required this.outreach,
    required this.records,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> subscription;
  final Map<String, dynamic> auth;
  final Map<String, dynamic> outreach;
  final Map<String, dynamic> records;
}
