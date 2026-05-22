import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orchestrate_app/core/auth/auth_session.dart';
import 'package:orchestrate_app/data/repositories/auth_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_account_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_billing_repository.dart';
import 'package:orchestrate_app/data/repositories/client/client_portal_repository.dart';
import 'package:orchestrate_app/features/client/widgets/blocker_resolution_card.dart';
import 'package:orchestrate_app/features/client/widgets/client_workspace_widgets.dart';
import 'package:orchestrate_app/features/client/widgets/signature_identity_card.dart';

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
  bool _revokingDevice = false;

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
      _authRepository.fetchTrustedDevices(),
    ]);
    return _SettingsData(
      profile: asMap(results[0]),
      subscription: asMap(results[1]),
      auth: asMap(results[2]),
      outreach: asMap(results[3]),
      records: asMap(results[4]),
      trustedDevices: asMap(results[5]),
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

  Future<void> _revokeDevice(String deviceId) async {
    setState(() => _revokingDevice = true);
    try {
      await _authRepository.revokeTrustedDevice(deviceId);
      await AuthSessionController.instance.clearTrustedDeviceToken(
        surface: 'client',
      );
      _retry();
    } finally {
      if (mounted) setState(() => _revokingDevice = false);
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
          return ClientErrorView.fromError(
            snapshot.error,
            title: 'Settings are temporarily unavailable',
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
        final trustedDevices = asList(data.trustedDevices['devices']);
        final setupComplete = session.hasSetupCompleted;
        final authorized = data.auth['authorized'] == true;
        final blockers = asList(readiness['blockers']);

        return ClientPage(
          eyebrow: 'Settings',
          title: readText(profile, 'displayName',
              fallback: session.workspaceName.isEmpty
                  ? 'Client workspace'
                  : session.workspaceName),
          subtitle:
              'Use settings to resolve account, setup, billing, and permission items that affect service readiness.',
          banner: _settingsBanner(
            setupComplete: setupComplete,
            authorized: authorized,
            blockers: blockers,
          ),
          actions: [
            if (!setupComplete)
              FilledButton.icon(
                onPressed: () => context.go('/client/setup'),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Complete setup'),
              )
            else
              FilledButton.icon(
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
              // Truthful setup state: "Complete" is only honest when no
              // downstream readiness items are pending. With blockers
              // present, the setup record exists but operational
              // readiness is not actually complete.
              ClientMetric(
                'Setup',
                !session.hasSetupCompleted
                    ? 'Incomplete'
                    : blockers.isEmpty && authorized
                        ? 'Recorded'
                        : 'Recorded · readiness pending',
              ),
              ClientMetric(
                  'Billing',
                  titleCase(readText(data.subscription, 'status',
                      fallback: session.subscriptionStatus))),
              ClientMetric(
                  'Authorization',
                  data.auth['authorized'] == true
                      ? 'Recorded'
                      : 'Not recorded'),
              ClientMetric('Mailbox',
                  mailbox['ready'] == true ? 'Ready' : 'Not ready'),
            ]),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Account',
              subtitle:
                  'These details identify the workspace and the client-facing links used by service records.',
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
            const SignatureIdentityCard(),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Setup',
              subtitle:
                  'Setup controls whether targeting and service preferences are recorded. Operational readiness is reported separately below.',
              children: [
                ClientInfoRow(
                  title: 'Setup state',
                  primary: !session.hasSetupCompleted
                      ? 'Setup is incomplete.'
                      : (blockers.isEmpty && authorized)
                          ? 'Setup is recorded and no readiness blockers are pending.'
                          : 'Setup is recorded; operational readiness is still pending below.',
                  secondary: session.hasSetupCompleted
                      ? 'Targeting and service preferences are available. Dispatch eligibility is gated by the readiness items below, not by setup alone.'
                      : 'Finish setup before downstream readiness can be evaluated.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Billing',
              subtitle:
                  'Billing state determines whether service can remain active.',
              children: [
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
              title: 'Permissions and readiness',
              subtitle:
                  'Each item below names what is blocked, who owns it, and the path to resolve it.',
              children: [
                BlockerResolutionList(
                  blockers: blockers,
                  authorized: authorized,
                  authAcceptedAt: asMap(data.auth['latest'])['acceptedAt'],
                  onReturned: _retry,
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Security',
              subtitle:
                  'Trusted devices skip the email code until they expire or are revoked.',
              children: trustedDevices.isEmpty
                  ? const [
                      ClientInfoRow(
                        title: 'Trusted devices',
                        primary: 'No trusted devices are recorded yet.',
                        secondary:
                            'After verifying an email code, you can trust this device for 60 days.',
                      ),
                    ]
                  : [
                      for (final raw in trustedDevices)
                        _TrustedDeviceRow(
                          device: asMap(raw),
                          busy: _revokingDevice,
                          onRevoke: _revokeDevice,
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
            const SizedBox(height: 18),
            ClientPanel(
              title: 'Legal',
              subtitle:
                  'The policies that govern how Orchestrate handles your data and service.',
              children: [
                ClientInfoRow(
                  title: 'Privacy policy',
                  primary:
                      'How Orchestrate collects, uses, and protects workspace data.',
                  trailing: TextButton(
                    onPressed: () => context.push('/legal/privacy'),
                    child: const Text('Open'),
                  ),
                ),
                ClientInfoRow(
                  title: 'Terms of service',
                  primary:
                      'The agreement that governs use of the Orchestrate service.',
                  trailing: TextButton(
                    onPressed: () => context.push('/legal/terms'),
                    child: const Text('Open'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

ClientStatusBanner _settingsBanner({
  required bool setupComplete,
  required bool authorized,
  required List<dynamic> blockers,
}) {
  if (!setupComplete) {
    return const ClientStatusBanner(
      tone: ClientBannerTone.blocked,
      title: 'Setup is incomplete',
      message:
          'Complete setup before expecting campaign execution. If you do nothing, outreach readiness remains limited.',
    );
  }
  if (!authorized) {
    return const ClientStatusBanner(
      tone: ClientBannerTone.warning,
      title: 'Representation permission is missing',
      message:
          'Authorization is required before Orchestrate can send outreach on your behalf.',
    );
  }
  if (blockers.isNotEmpty) {
    return ClientStatusBanner(
      tone: ClientBannerTone.warning,
      title: '${blockers.length} readiness items need attention',
      message:
          'Review the permission and outreach readiness sections. If you do nothing, service execution may remain blocked.',
    );
  }
  return const ClientStatusBanner(
    tone: ClientBannerTone.success,
    title: 'Workspace controls are ready',
    message:
        'Account, setup, billing, and permission records are available. Edit profile only when details change.',
  );
}

class _SettingsData {
  const _SettingsData({
    required this.profile,
    required this.subscription,
    required this.auth,
    required this.outreach,
    required this.records,
    required this.trustedDevices,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> subscription;
  final Map<String, dynamic> auth;
  final Map<String, dynamic> outreach;
  final Map<String, dynamic> records;
  final Map<String, dynamic> trustedDevices;
}

class _TrustedDeviceRow extends StatelessWidget {
  const _TrustedDeviceRow({
    required this.device,
    required this.busy,
    required this.onRevoke,
  });

  final Map<String, dynamic> device;
  final bool busy;
  final Future<void> Function(String deviceId) onRevoke;

  @override
  Widget build(BuildContext context) {
    final active = device['active'] == true;
    final id = readText(device, 'id');
    return ClientInfoRow(
      title: readText(device, 'deviceName', fallback: 'Trusted device'),
      primary: [
        active ? 'Active' : 'Inactive',
        readText(device, 'platform'),
      ].where((part) => part.isNotEmpty).join(' · '),
      secondary: [
        'Created ${dateLabel(device['createdAt'])}',
        'Last used ${dateLabel(device['lastUsedAt'])}',
        'Expires ${dateLabel(device['expiresAt'])}',
        if (device['revokedAt'] != null)
          'Revoked ${dateLabel(device['revokedAt'])}',
      ].join(' · '),
      trailing: active && id.isNotEmpty
          ? TextButton(
              onPressed: busy ? null : () => onRevoke(id),
              child: Text(busy ? 'Revoking' : 'Revoke'),
            )
          : null,
    );
  }
}

