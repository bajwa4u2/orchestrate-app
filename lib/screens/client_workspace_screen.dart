import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    if (section == ClientSection.account) {
      return const _AccountWorkspaceScreen();
    }

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
              if (data.statusCards.isNotEmpty) ...[
                _StatusStrip(cards: data.statusCards),
                const SizedBox(height: 18),
              ],
              if (data.primaryAction != null) ...[
                _PrimaryActionCard(action: data.primaryAction!),
                const SizedBox(height: 18),
              ],
              if (data.summaryCards.isNotEmpty) ...[
                _SummaryGrid(cards: data.summaryCards),
                const SizedBox(height: 18),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  final left = _Panel(
                    title: data.primaryTitle,
                    rows: data.primaryRows,
                    empty: data.primaryEmpty,
                  );
                  final right = _Panel(
                    title: data.secondaryTitle,
                    rows: data.secondaryRows,
                    empty: data.secondaryEmpty,
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

  Future<_ClientSectionData> _load(ClientSection section) async {
    final repo = ClientPortalRepository();
    final session = AuthSessionController.instance;

    switch (section) {
      case ClientSection.billing:
        final invoices = await repo.fetchInvoices();
        final subscription = await repo.fetchSubscription();
        final reminders = await repo.fetchReminders();
        final subscriptionMap = _asMap(subscription);
        final billingActive =
            _read(subscriptionMap, 'status', fallback: session.subscriptionStatus)
                    .toLowerCase() ==
                'active';

        return _ClientSectionData(
          eyebrow: 'Billing',
          title: billingActive
              ? 'Billing is in good standing'
              : 'Billing needs attention',
          subtitle: billingActive
              ? 'Plan, invoices, and reminders are available below.'
              : 'Review subscription and billing records before service is interrupted.',
          notice: subscription == null
              ? 'Billing details will appear here after activation.'
              : null,
          statusCards: [
            _StatusCard(
              'Plan',
              _read(
                subscriptionMap,
                'planName',
                fallback: _labelize(session.selectedPlan ?? 'Not set'),
              ),
            ),
            _StatusCard(
              'Status',
              _labelize(
                _read(
                  subscriptionMap,
                  'status',
                  fallback: session.subscriptionStatus,
                ),
              ),
            ),
            _StatusCard('Invoices', '${invoices.length}'),
            _StatusCard('Reminders', '${reminders.length}'),
          ],
          primaryAction: _PrimaryAction(
            title: billingActive ? 'Billing is clear' : 'Review billing now',
            body: billingActive
                ? 'You can review invoices, reminders, or plan details whenever needed.'
                : 'Subscription or billing state needs review before work can remain fully active.',
          ),
          summaryCards: [
            _SummaryCardData(
              title: 'Subscription',
              body: subscription == null
                  ? 'No active subscription record yet.'
                  : [
                      _read(subscriptionMap, 'planName'),
                      _labelize(_read(subscriptionMap, 'interval')),
                      _labelize(_read(subscriptionMap, 'status')),
                    ].where((e) => e.isNotEmpty).join(' · '),
            ),
            const _SummaryCardData(
              title: 'Secure billing',
              body: 'Secure billing powered by Stripe',
            ),
          ],
          primaryTitle: 'Invoices',
          primaryRows: invoices
              .map(
                (item) => _rowFromMap(
                  item,
                  titleKey: 'invoiceNumber',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['dueDate', 'currencyCode'],
                ),
              )
              .toList(),
          primaryEmpty: 'No invoices are available yet.',
          secondaryTitle: 'Subscription and reminders',
          secondaryRows: [
            if (subscription != null)
              _rowFromMap(
                subscription,
                titleKey: 'planName',
                primaryKeys: const ['status', 'interval'],
                secondaryKeys: const ['currentPeriodEnd'],
              ),
            ...reminders.map(
              (item) => _rowFromMap(
                item,
                titleKey: 'title',
                primaryKeys: const ['status'],
                secondaryKeys: const ['sendAt'],
              ),
            ),
          ],
          secondaryEmpty:
              'Subscription details and reminders will appear here after activation.',
        );

      case ClientSection.agreements:
        final agreements = await repo.fetchAgreements();
        final notifications = await repo.fetchNotifications();

        return _ClientSectionData(
          eyebrow: 'Agreements',
          title: 'Service record and notices',
          subtitle: 'Keep formal service records visible and easy to review.',
          statusCards: [
            _StatusCard('Agreements', '${agreements.length}'),
            _StatusCard('Notices', '${notifications.length}'),
          ],
          primaryAction: const _PrimaryAction(
            title: 'Keep the formal record current',
            body:
                'Review agreements and notices from one place so service footing stays clear.',
          ),
          primaryTitle: 'Agreements',
          primaryRows: agreements
              .map(
                (item) => _rowFromMap(
                  item,
                  titleKey: 'title',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['updatedAt'],
                ),
              )
              .toList(),
          primaryEmpty: 'No agreements are available yet.',
          secondaryTitle: 'Notices',
          secondaryRows: notifications
              .map(
                (item) => _rowFromMap(
                  item,
                  titleKey: 'title',
                  primaryKeys: const ['kind'],
                  secondaryKeys: const ['createdAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No notices are available right now.',
        );

      case ClientSection.statements:
        final statements = await repo.fetchStatements();
        final emails = await repo.fetchEmailDispatches();

        return _ClientSectionData(
          eyebrow: 'Statements',
          title: 'Statements and dispatch history',
          subtitle: 'Review what has been summarized and what has already been sent.',
          statusCards: [
            _StatusCard('Statements', '${statements.length}'),
            _StatusCard('Dispatches', '${emails.length}'),
          ],
          primaryAction: const _PrimaryAction(
            title: 'Keep recorded summaries within reach',
            body:
                'Statements and dispatch history stay here so the formal record remains easy to follow.',
          ),
          primaryTitle: 'Statements',
          primaryRows: statements
              .map(
                (item) => _rowFromMap(
                  item,
                  titleKey: 'statementNumber',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['periodEnd'],
                ),
              )
              .toList(),
          primaryEmpty: 'No statements are available yet.',
          secondaryTitle: 'Dispatch history',
          secondaryRows: emails
              .map(
                (item) => _rowFromMap(
                  item,
                  titleKey: 'subject',
                  primaryKeys: const ['status'],
                  secondaryKeys: const ['sentAt'],
                ),
              )
              .toList(),
          secondaryEmpty: 'No dispatches are available yet.',
        );

      case ClientSection.account:
        final profile = await repo.fetchClientProfile();
        final client = _asMap(profile['client']);
        final currentPlan = _labelize(
          _read(client, 'selectedPlan', fallback: session.selectedPlan ?? 'Not set'),
        );
        final currentTier = _labelize(session.selectedTier ?? 'focused');
        final profileName = _displayIdentity(client);

        return _ClientSectionData(
          eyebrow: 'Account',
          title: profileName,
          subtitle: 'Profile, subscription, and security all stay within reach from here.',
          statusCards: [
            _StatusCard('Plan', currentPlan),
            _StatusCard('Tier', currentTier),
            _StatusCard('Verification', session.emailVerified ? 'Verified' : 'Pending'),
            _StatusCard('Currency', _read(client, 'currencyCode', fallback: 'USD')),
          ],
          primaryAction: _PrimaryAction(
            title: session.emailVerified
                ? 'Account is ready'
                : 'Complete account verification',
            body: session.emailVerified
                ? 'Update profile, review subscription, or manage security from this page.'
                : 'Finish verification so access and service continuity stay clear.',
          ),
          summaryCards: const [
            _SummaryCardData(
              title: 'Profile',
              body: 'Richer profile editing and presentation templates should live here next.',
            ),
            _SummaryCardData(
              title: 'Subscription',
              body: 'Plan switch options belong here, not only passive billing status.',
            ),
            _SummaryCardData(
              title: 'Security',
              body: 'Password reset and account deletion should be available here.',
            ),
          ],
          primaryTitle: 'Profile',
          primaryRows: [
            _DataRow(
              title: profileName,
              primary: _read(client, 'legalName'),
              secondary: _read(client, 'websiteUrl'),
              actionLabel: _linkLabel(_read(client, 'websiteUrl')),
              onTap: _openLinkAction(_read(client, 'websiteUrl')),
            ),
            _DataRow(
              title: 'Contact and routing',
              primary: _read(client, 'primaryEmail', fallback: session.email),
              secondary: _read(client, 'bookingUrl'),
              actionLabel: _linkLabel(_read(client, 'bookingUrl')),
              onTap: _openLinkAction(_read(client, 'bookingUrl')),
            ),
            const _DataRow(
              title: 'Profile presentation',
              primary: 'Visual editing and template controls should be added here next.',
              secondary: 'This area should carry the client identity, not a flat account form.',
            ),
          ],
          primaryEmpty: 'No profile details are available.',
          secondaryTitle: 'Subscription and security',
          secondaryRows: [
            _DataRow(
              title: 'Current subscription',
              primary: '$currentPlan · $currentTier',
              secondary: _labelize(session.subscriptionStatus),
            ),
            const _DataRow(
              title: 'Plan change',
              primary: 'Plan switch options should be available here.',
              secondary:
                  'Clients should be able to move between plans without leaving the account area.',
            ),
            _DataRow(
              title: 'Email verification',
              primary: session.emailVerified ? 'Verified' : 'Pending',
              secondary: session.email,
            ),
            const _DataRow(
              title: 'Security',
              primary: 'Password reset and account deletion should live here.',
              secondary: 'These should be direct actions under the security section.',
            ),
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

        final billingActive = session.normalizedSubscriptionStatus == 'active';
        final setupComplete = session.hasSetupCompleted;
        final openNotices = _numberValue(communications['openNotifications']);
        final outstanding = _money(billing['outstandingCents']);
        final replies = _numberValue(activity['replies']);
        final meetings = _numberValue(activity['meetings']);
        final campaigns = _numberValue(activity['campaigns']);
        final identity = _displayIdentity(client);

        return _ClientSectionData(
          eyebrow: setupComplete ? 'Workspace ready' : 'Setup still needs attention',
          title: identity,
          subtitle: _overviewSubtitle(
            setupComplete: setupComplete,
            billingActive: billingActive,
            replies: replies,
            meetings: meetings,
            campaigns: campaigns,
            openNotices: openNotices,
          ),
          notice: !setupComplete
              ? 'Finish setup to prepare the workspace for live service.'
              : (!billingActive
                  ? 'Billing needs attention before service can stay fully active.'
                  : null),
          statusCards: [
            _StatusCard(
              'Plan',
              _labelize(
                session.selectedPlan ??
                    _read(client, 'selectedPlan', fallback: 'Not set'),
              ),
            ),
            _StatusCard('Billing', billingActive ? 'Active' : 'Attention needed'),
            _StatusCard('Scope', _scopeLabel(client)),
            _StatusCard('Support', openNotices > 0 ? '$openNotices open' : 'None'),
          ],
          primaryAction: _overviewAction(
            setupComplete: setupComplete,
            billingActive: billingActive,
            replies: replies,
            meetings: meetings,
            campaigns: campaigns,
            openNotices: openNotices,
          ),
          summaryCards: [
            _SummaryCardData(
              title: 'Current standing',
              body: [
                if (identity.isNotEmpty) identity,
                if (_read(client, 'industry').isNotEmpty) _read(client, 'industry'),
                if (_read(client, 'status').isNotEmpty)
                  _labelize(_read(client, 'status')),
              ].join(' · '),
            ),
            _SummaryCardData(
              title: 'Billing snapshot',
              body:
                  '$outstanding outstanding · ${_numberValue(billing['invoiceCount'])} invoices',
            ),
            _SummaryCardData(
              title: 'Movement',
              body: '$replies replies · $meetings meetings · $campaigns campaigns',
            ),
          ],
          primaryTitle: 'What needs attention',
          primaryRows: _overviewAttentionRows(
            client: client,
            session: session,
            billing: billing,
            communications: communications,
            activity: activity,
          ),
          primaryEmpty: 'Nothing needs attention right now.',
          secondaryTitle: 'Current activity',
          secondaryRows: _overviewActivityRows(
            client: client,
            billing: billing,
            communications: communications,
            activity: activity,
          ),
          secondaryEmpty: 'No live movement is available yet.',
        );
    }
  }
}


class _AccountWorkspaceScreen extends StatefulWidget {
  const _AccountWorkspaceScreen();

  @override
  State<_AccountWorkspaceScreen> createState() => _AccountWorkspaceScreenState();
}

class _AccountWorkspaceScreenState extends State<_AccountWorkspaceScreen> {
  final _repo = ClientPortalRepository();
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _bookingController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _currencyController = TextEditingController();
  final _logoController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _accentColorController = TextEditingController();
  final _welcomeHeadlineController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _deactivating = false;
  String? _error;
  Map<String, dynamic> _profile = const {};
  Map<String, dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _legalNameController.dispose();
    _brandNameController.dispose();
    _websiteController.dispose();
    _bookingController.dispose();
    _timezoneController.dispose();
    _currencyController.dispose();
    _logoController.dispose();
    _primaryColorController.dispose();
    _accentColorController.dispose();
    _welcomeHeadlineController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileResponse = await _repo.fetchClientProfile();
      final subscription = await _repo.fetchSubscription();
      final profile = _asMap(profileResponse['profile']);
      final branding = _asMap(profile['branding']);

      _profile = profile;
      _subscription = subscription;
      _displayNameController.text = _read(profile, 'displayName');
      _legalNameController.text = _read(profile, 'legalName');
      _brandNameController.text = _read(branding, 'brandName', fallback: _read(profile, 'displayName'));
      _websiteController.text = _read(profile, 'websiteUrl');
      _bookingController.text = _read(profile, 'bookingUrl');
      _timezoneController.text = _read(profile, 'primaryTimezone');
      _currencyController.text = _read(profile, 'currencyCode', fallback: 'USD');
      _logoController.text = _read(branding, 'logoUrl');
      _primaryColorController.text = _read(branding, 'primaryColor', fallback: '#111827');
      _accentColorController.text = _read(branding, 'accentColor', fallback: '#2563eb');
      _welcomeHeadlineController.text = _read(
        branding,
        'welcomeHeadline',
        fallback: 'Your account is configured for active service operations.',
      );
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final response = await _repo.updateClientProfile(
        displayName: _displayNameController.text.trim(),
        legalName: _legalNameController.text.trim(),
        brandName: _brandNameController.text.trim(),
        websiteUrl: _websiteController.text.trim(),
        bookingUrl: _bookingController.text.trim(),
        primaryTimezone: _timezoneController.text.trim(),
        currencyCode: _currencyController.text.trim(),
        logoUrl: _logoController.text.trim(),
        primaryColor: _primaryColorController.text.trim(),
        accentColor: _accentColorController.text.trim(),
        welcomeHeadline: _welcomeHeadlineController.text.trim(),
      );
      final profile = _asMap(response['profile']);
      final branding = _asMap(profile['branding']);
      _profile = profile;
      _displayNameController.text = _read(profile, 'displayName');
      _legalNameController.text = _read(profile, 'legalName');
      _brandNameController.text = _read(branding, 'brandName', fallback: _read(profile, 'displayName'));
      _websiteController.text = _read(profile, 'websiteUrl');
      _bookingController.text = _read(profile, 'bookingUrl');
      _timezoneController.text = _read(profile, 'primaryTimezone');
      _currencyController.text = _read(profile, 'currencyCode', fallback: 'USD');
      _logoController.text = _read(branding, 'logoUrl');
      _primaryColorController.text = _read(branding, 'primaryColor', fallback: '#111827');
      _accentColorController.text = _read(branding, 'accentColor', fallback: '#2563eb');
      _welcomeHeadlineController.text = _read(
        branding,
        'welcomeHeadline',
        fallback: 'Your account is configured for active service operations.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account profile updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _confirmDeactivate() async {
    final reasonController = TextEditingController();
    final confirmController = TextEditingController();
    var localError = '';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_deactivating,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.panel,
              title: const Text('Deactivate account'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will deactivate your account and stop all active service activity.',
                      style: TextStyle(color: AppTheme.muted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    _AccountField(
                      label: 'Reason',
                      controller: reasonController,
                      maxLines: 3,
                      hintText: 'Optional',
                    ),
                    const SizedBox(height: 14),
                    _AccountField(
                      label: 'Confirmation',
                      controller: confirmController,
                      hintText: 'Type DEACTIVATE',
                    ),
                    if (localError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(localError, style: const TextStyle(color: AppTheme.rose)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _deactivating ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.rose),
                  onPressed: _deactivating
                      ? null
                      : () async {
                          if (confirmController.text.trim().toUpperCase() != 'DEACTIVATE') {
                            setDialogState(() {
                              localError = 'Enter DEACTIVATE to continue.';
                            });
                            return;
                          }
                          setState(() {
                            _deactivating = true;
                          });
                          try {
                            await _repo.deactivateClientAccount(
                              reason: reasonController.text.trim(),
                              confirmationText: confirmController.text.trim(),
                            );
                            if (!mounted) return;
                            await AuthSessionController.instance.clear();
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop(true);
                          } catch (error) {
                            setDialogState(() {
                              localError = 'Could not deactivate account: $error';
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                _deactivating = false;
                              });
                            }
                          }
                        },
                  child: _deactivating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Deactivate account'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
    confirmController.dispose();

    if (confirmed == true && mounted) {
      context.go('/client/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionController.instance;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Account could not load right now.'),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.muted), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final branding = _asMap(_profile['branding']);
    final accountState = _accountState(session);
    final planName = _labelize(session.selectedPlan ?? 'Not set');
    final tierName = _labelize(session.selectedTier ?? 'Focused');
    final subscriptionStatus = _labelize(_read(_asMap(_subscription), 'status', fallback: session.subscriptionStatus));
    final primaryEmail = _read(_profile, 'primaryEmail', fallback: session.email);
    final billingEmail = _read(_profile, 'billingEmail');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AccountHeader(),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AccountStatusChip(label: 'Account', value: accountState),
                _AccountStatusChip(label: 'Plan', value: '$planName · $tierName'),
                _AccountStatusChip(label: 'Subscription', value: subscriptionStatus),
                _AccountStatusChip(
                  label: 'Verification',
                  value: session.emailVerified ? 'Verified' : 'Pending',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _AccountInfoBanner(
              title: 'Client identity and settings',
              body: session.normalizedSubscriptionStatus == 'active'
                  ? 'Profile, commercial status, and security stay together here.'
                  : 'Profile and account control stay available even before service activation.',
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1040;
                final identityPanel = _AccountPanel(
                  title: 'Profile and business identity',
                  child: Column(
                    children: [
                      _AccountField(
                        label: 'Display name',
                        controller: _displayNameController,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 14),
                      _AccountField(
                        label: 'Legal name',
                        controller: _legalNameController,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 14),
                      _AccountField(label: 'Brand name', controller: _brandNameController),
                      const SizedBox(height: 14),
                      _AccountField(label: 'Website', controller: _websiteController, keyboardType: TextInputType.url),
                      const SizedBox(height: 14),
                      _AccountField(label: 'Booking link', controller: _bookingController, keyboardType: TextInputType.url),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _AccountField(label: 'Timezone', controller: _timezoneController)),
                          const SizedBox(width: 14),
                          Expanded(child: _AccountField(label: 'Currency', controller: _currencyController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _StaticInfoRow(label: 'Primary email', value: primaryEmail),
                      if (billingEmail.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _StaticInfoRow(label: 'Billing email', value: billingEmail),
                      ],
                    ],
                  ),
                );

                final brandingPanel = _AccountPanel(
                  title: 'Visual identity',
                  child: Column(
                    children: [
                      _AccountField(label: 'Logo URL', controller: _logoController, keyboardType: TextInputType.url),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _AccountField(label: 'Primary color', controller: _primaryColorController)),
                          const SizedBox(width: 14),
                          Expanded(child: _AccountField(label: 'Accent color', controller: _accentColorController)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _AccountField(
                        label: 'Welcome headline',
                        controller: _welcomeHeadlineController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _BrandPreviewCard(
                        brandName: _brandNameController.text.trim().isEmpty
                            ? _displayNameController.text.trim()
                            : _brandNameController.text.trim(),
                        headline: _welcomeHeadlineController.text.trim(),
                        primaryColor: _primaryColorController.text.trim(),
                        accentColor: _accentColorController.text.trim(),
                        logoUrl: _logoController.text.trim(),
                      ),
                    ],
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [identityPanel, const SizedBox(height: 18), brandingPanel],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: identityPanel),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: brandingPanel),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1040;
                final accountPanel = _AccountPanel(
                  title: 'Plan and status',
                  child: Column(
                    children: [
                      _StaticInfoRow(label: 'Account state', value: accountState),
                      const SizedBox(height: 12),
                      _StaticInfoRow(label: 'Selected plan', value: '$planName · $tierName'),
                      const SizedBox(height: 12),
                      _StaticInfoRow(label: 'Subscription', value: subscriptionStatus),
                      const SizedBox(height: 12),
                      _StaticInfoRow(
                        label: 'Verification',
                        value: session.emailVerified ? 'Verified' : 'Pending',
                      ),
                    ],
                  ),
                );
                final securityPanel = _AccountPanel(
                  title: 'Security and account actions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Security actions stay available from account settings.',
                        style: TextStyle(color: AppTheme.muted, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => context.go('/client/reset-password'),
                            child: const Text('Reset password'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: AppTheme.line),
                      const SizedBox(height: 18),
                      const Text(
                        'Deactivate account',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Deactivate your account when you want service activity and access to stop under this client profile.',
                        style: TextStyle(color: AppTheme.muted, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          foregroundColor: AppTheme.rose,
                          backgroundColor: AppTheme.rose.withOpacity(0.12),
                        ),
                        onPressed: _deactivating ? null : _confirmDeactivate,
                        child: const Text('Deactivate account'),
                      ),
                    ],
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [accountPanel, const SizedBox(height: 18), securityPanel],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: accountPanel),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: securityPanel),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _saving ? null : _saveProfile,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String _accountState(AuthSessionController session) {
    if (!session.hasSetupCompleted) return 'Draft';
    if (session.normalizedSubscriptionStatus == 'active') return 'Active';
    return 'Review';
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: TextStyle(
            color: AppTheme.muted,
            letterSpacing: 1.0,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Identity, plan, and account control',
          style: TextStyle(
            color: AppTheme.text,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Keep client profile, commercial status, and account actions together in one place.',
          style: TextStyle(color: AppTheme.muted, height: 1.55, fontSize: 15),
        ),
      ],
    );
  }
}

class _AccountStatusChip extends StatelessWidget {
  const _AccountStatusChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.subdued, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AccountInfoBanner extends StatelessWidget {
  const _AccountInfoBanner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: AppTheme.muted, height: 1.5)),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.hintText,
    this.validator,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final String? hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.text),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppTheme.subdued),
            filled: true,
            fillColor: AppTheme.panelRaised,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.rose),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.rose),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaticInfoRow extends StatelessWidget {
  const _StaticInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(color: AppTheme.subdued, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not set' : value,
            style: const TextStyle(color: AppTheme.text, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _BrandPreviewCard extends StatelessWidget {
  const _BrandPreviewCard({
    required this.brandName,
    required this.headline,
    required this.primaryColor,
    required this.accentColor,
    required this.logoUrl,
  });

  final String brandName;
  final String headline;
  final String primaryColor;
  final String accentColor;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final primary = _tryParseColor(primaryColor) ?? AppTheme.panelRaised;
    final accent = _tryParseColor(accentColor) ?? AppTheme.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  (brandName.isEmpty ? 'C' : brandName.trim()[0].toUpperCase()),
                  style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName.isEmpty ? 'Client brand' : brandName,
                      style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700),
                    ),
                    if (logoUrl.trim().isNotEmpty)
                      Text(
                        logoUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            headline.isEmpty ? 'Your account is configured for active service operations.' : headline,
            style: const TextStyle(color: AppTheme.text, height: 1.5),
          ),
        ],
      ),
    );
  }
}

Color? _tryParseColor(String value) {
  final raw = value.trim().replaceAll('#', '');
  if (raw.length != 6 && raw.length != 8) return null;
  final normalized = raw.length == 6 ? 'FF$raw' : raw;
  final intValue = int.tryParse(normalized, radix: 16);
  if (intValue == null) return null;
  return Color(intValue);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});

  final _ClientSectionData data;

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.cards});

  final List<_StatusCard> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                _StatusCardTile(card: cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _StatusCardTile(card: cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatusCardTile extends StatelessWidget {
  const _StatusCardTile({required this.card});

  final _StatusCard card;

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
          Text(card.label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(card.value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.action});

  final _PrimaryAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.publicText,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicText),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;

          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                action.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.88),
                    ),
              ),
            ],
          );

          final button = action.actionLabel != null && action.onTap != null
              ? FilledButton(
                  onPressed: action.onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.publicText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(action.actionLabel!),
                )
              : const SizedBox.shrink();

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                if (action.actionLabel != null && action.onTap != null) ...[
                  const SizedBox(height: 16),
                  button,
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: text),
              if (action.actionLabel != null && action.onTap != null) ...[
                const SizedBox(width: 18),
                button,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cards});

  final List<_SummaryCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                _SummaryCard(card: cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _SummaryCard(card: cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.card});

  final _SummaryCardData card;

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
  const _Panel({required this.title, required this.rows, required this.empty});

  final String title;
  final List<_DataRow> rows;
  final String empty;

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
            Text(empty, style: Theme.of(context).textTheme.bodyMedium)
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

  final _DataRow row;

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
          Text(row.secondary, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (row.actionLabel != null && row.onTap != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: row.onTap, child: Text(row.actionLabel!)),
        ],
      ],
    );
  }
}

class _ClientSectionData {
  const _ClientSectionData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.notice,
    this.statusCards = const [],
    this.primaryAction,
    this.summaryCards = const [],
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
  final List<_StatusCard> statusCards;
  final _PrimaryAction? primaryAction;
  final List<_SummaryCardData> summaryCards;
  final String primaryTitle;
  final List<_DataRow> primaryRows;
  final String primaryEmpty;
  final String secondaryTitle;
  final List<_DataRow> secondaryRows;
  final String secondaryEmpty;
}

class _StatusCard {
  const _StatusCard(this.label, this.value);

  final String label;
  final String value;
}

class _PrimaryAction {
  const _PrimaryAction({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onTap;
}

class _SummaryCardData {
  const _SummaryCardData({required this.title, required this.body});

  final String title;
  final String body;
}

class _DataRow {
  const _DataRow({
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

_PrimaryAction _overviewAction({
  required bool setupComplete,
  required bool billingActive,
  required int replies,
  required int meetings,
  required int campaigns,
  required int openNotices,
}) {
  if (!setupComplete) {
    return const _PrimaryAction(
      title: 'Finish setup',
      body: 'Complete scope and workspace setup so service can move forward cleanly.',
    );
  }

  if (!billingActive) {
    return const _PrimaryAction(
      title: 'Resolve billing',
      body: 'Billing needs attention before service can stay fully active.',
    );
  }

  if (openNotices > 0) {
    return _PrimaryAction(
      title: 'Review open notices',
      body: '$openNotices support or service notices are waiting for review.',
    );
  }

  if (replies > 0 || meetings > 0 || campaigns > 0) {
    return _PrimaryAction(
      title: 'Review current work',
      body: '$replies replies, $meetings meetings, and $campaigns campaigns are currently in motion.',
    );
  }

  return const _PrimaryAction(
    title: 'Workspace is ready',
    body: 'Your account is in place. Billing, support, and account controls are available when needed.',
  );
}

List<_DataRow> _overviewAttentionRows({
  required Map<String, dynamic> client,
  required AuthSessionController session,
  required Map<String, dynamic> billing,
  required Map<String, dynamic> communications,
  required Map<String, dynamic> activity,
}) {
  final rows = <_DataRow>[];

  if (!session.hasSetupCompleted) {
    rows.add(
      const _DataRow(
        title: 'Setup is still pending',
        primary: 'Complete workspace setup before live service begins.',
        secondary: 'Country, region, industry, and service profile still need to be confirmed.',
      ),
    );
  }

  if (session.normalizedSubscriptionStatus != 'active') {
    rows.add(
      _DataRow(
        title: 'Billing requires attention',
        primary: _labelize(session.subscriptionStatus),
        secondary: '${_money(billing['outstandingCents'])} outstanding',
      ),
    );
  }

  final openNotices = _numberValue(communications['openNotifications']);
  if (openNotices > 0) {
    rows.add(
      _DataRow(
        title: 'Open notices',
        primary: '$openNotices currently open',
        secondary: 'Review the latest support or service notices from the workspace.',
      ),
    );
  }

  final replies = _numberValue(activity['replies']);
  final meetings = _numberValue(activity['meetings']);
  if (replies > 0 || meetings > 0) {
    rows.add(
      _DataRow(
        title: 'Current movement',
        primary: '$replies replies · $meetings meetings',
        secondary: 'There is active work in motion right now.',
      ),
    );
  }

  if (rows.isEmpty) {
    rows.add(
      _DataRow(
        title: 'Everything is in order',
        primary: _displayIdentity(client),
        secondary: 'No immediate action is required right now.',
      ),
    );
  }

  return rows;
}

List<_DataRow> _overviewActivityRows({
  required Map<String, dynamic> client,
  required Map<String, dynamic> billing,
  required Map<String, dynamic> communications,
  required Map<String, dynamic> activity,
}) {
  return [
    _DataRow(
      title: 'Workspace identity',
      primary: [
        _displayIdentity(client),
        _read(client, 'industry'),
      ].where((e) => e.isNotEmpty).join(' · '),
      secondary: [
        _read(client, 'websiteUrl'),
        _read(client, 'primaryTimezone'),
      ].where((e) => e.isNotEmpty).join(' · '),
      actionLabel: _linkLabel(_read(client, 'websiteUrl')),
      onTap: _openLinkAction(_read(client, 'websiteUrl')),
    ),
    _DataRow(
      title: 'Billing snapshot',
      primary: '${_money(billing['outstandingCents'])} outstanding',
      secondary:
          '${_numberValue(billing['invoiceCount'])} invoices · ${_money(billing['collectedCents'])} collected',
    ),
    _DataRow(
      title: 'Activity',
      primary:
          '${_numberValue(activity['campaigns'])} campaigns · ${_numberValue(activity['replies'])} replies · ${_numberValue(activity['meetings'])} meetings',
      secondary:
          '${_numberValue(communications['emailDispatches'])} dispatches · ${_numberValue(communications['openNotifications'])} open notices',
    ),
  ];
}

String _overviewSubtitle({
  required bool setupComplete,
  required bool billingActive,
  required int replies,
  required int meetings,
  required int campaigns,
  required int openNotices,
}) {
  if (!setupComplete) return 'Complete setup to prepare this workspace for live service.';
  if (!billingActive) return 'Billing needs attention before service can remain fully active.';
  if (openNotices > 0) return 'There are open notices waiting for review.';
  if (replies > 0 || meetings > 0 || campaigns > 0) {
    return '$replies replies, $meetings meetings, and $campaigns campaigns are currently in motion.';
  }
  return 'Everything is in place and ready for the next move.';
}

_DataRow _rowFromMap(
  dynamic raw, {
  required String titleKey,
  List<String> primaryKeys = const [],
  List<String> secondaryKeys = const [],
}) {
  final map = _asMap(raw);
  return _DataRow(
    title: _read(map, titleKey, fallback: 'Record'),
    primary: primaryKeys.map((key) => _read(map, key)).where((value) => value.isNotEmpty).join(' · '),
    secondary: secondaryKeys.map((key) => _read(map, key)).where((value) => value.isNotEmpty).join(' · '),
  );
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _read(dynamic source, String key, {String fallback = ''}) {
  final map = _asMap(source);
  final value = map[key];
  if (value == null) return fallback;
  return value.toString();
}

int _numberValue(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _money(dynamic cents) {
  final amount = cents is num ? cents / 100 : 0;
  return '\$${amount.toStringAsFixed(2)}';
}

String _scopeLabel(Map<String, dynamic> client) {
  final country = _read(client, 'countryName');
  final region = _read(client, 'regionName');
  final parts = [country, region].where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'Not set';
  return parts.join(' · ');
}

String _displayIdentity(Map<String, dynamic> client) {
  final displayName = _read(client, 'displayName');
  if (displayName.isNotEmpty) return displayName;
  final legalName = _read(client, 'legalName');
  if (legalName.isNotEmpty) return legalName;
  return 'Client workspace';
}

String _labelize(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '';
  return normalized
      .split(RegExp(r'[_\\-\\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String? _linkLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return 'Open link';
}

VoidCallback? _openLinkAction(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  return () => openExternalUrl(trimmed);
}

Future<void> openExternalUrl(String? url) async {
  final uri = Uri.tryParse(url ?? '');
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}