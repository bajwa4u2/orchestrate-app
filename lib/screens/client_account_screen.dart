import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client/client_account_repository.dart';
import '../data/repositories/client/client_billing_repository.dart';
import '../data/repositories/client/client_workspace_repository.dart';

class ClientAccountScreen extends StatefulWidget {
  const ClientAccountScreen({super.key});

  @override
  State<ClientAccountScreen> createState() => _ClientAccountScreenState();
}

class _ClientAccountScreenState extends State<ClientAccountScreen> {
  final ClientWorkspaceRepository _workspaceRepository = ClientWorkspaceRepository();
  final ClientAccountRepository _accountRepository = ClientAccountRepository();
  final ClientBillingRepository _billingRepository = ClientBillingRepository();

  late Future<_AccountViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AccountViewData> _load() async {
    final overview = await _workspaceRepository.fetchOverview();
    final profile = await _accountRepository.fetchClientProfile();
    final subscription = await _billingRepository.fetchSubscription();
    return _AccountViewData(
      overview: overview,
      profile: profile,
      subscription: subscription,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openBillingPortal() async {
    final url = await _billingRepository.createBillingPortalSession();
    await _openUrl(url);
  }

  Future<void> _showProfileEditor(_AccountViewData data) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProfileEditorDialog(
        initialProfile: data.profile,
        repository: _accountRepository,
      ),
    );

    if (saved == true) {
      await _refresh();
    }
  }

  Future<void> _showDeactivateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeactivateAccountDialog(repository: _accountRepository),
    );

    if (result == true && mounted) {
      await AuthSessionController.instance.clear();
      if (mounted) context.go('/client/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AccountViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('This area could not load right now.'));
        }

        final data = snapshot.data!;
        final session = AuthSessionController.instance;
        final profile = data.profile;
        final subscription = data.subscription ?? const <String, dynamic>{};
        final client = _asMap(data.overview['client']);
        final billing = _asMap(data.overview['billing']);

        final workspaceName = _displayIdentity(profile, fallback: _displayIdentity(client));
        final displayPlan = _resolvePlanLabel(subscription, session: session);
        final billingStatus = _title(
          _read(subscription, 'status', fallback: session.subscriptionStatus),
        );
        final currency = _read(profile, 'currencyCode', fallback: 'USD');
        final periodEnd = _formatDate(_read(subscription, 'currentPeriodEnd'));
        final websiteUrl = _read(profile, 'websiteUrl');
        final bookingUrl = _read(profile, 'bookingUrl');
        final outstanding = _centsToMoney(_intValue(billing['outstandingCents']), currency);
        final setupPlanSummary = _joinNonEmpty([
          _title(session.setupSelectedPlan ?? ''),
          _title(session.setupSelectedTier ?? ''),
        ]);
        final subscriptionSummary = _joinNonEmpty([
          displayPlan,
          periodEnd.isEmpty ? '' : 'Current period ends $periodEnd',
        ]);

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                eyebrow: 'Account',
                title: workspaceName,
                subtitle:
                    'Profile, billing standing, account controls, and direct actions stay together here.',
                actions: [
                  _HeroAction(
                    label: 'Edit profile',
                    onPressed: () => _showProfileEditor(data),
                  ),
                  _HeroAction(
                    label: 'Help',
                    isPrimary: false,
                    onPressed: () => context.go('/client/help'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MetricStrip(
                metrics: [
                  _MetricData(label: 'Account state', value: _accountState(session)),
                  _MetricData(label: 'Plan', value: displayPlan.isEmpty ? 'Not set' : displayPlan),
                  _MetricData(label: 'Billing', value: billingStatus),
                  _MetricData(
                    label: 'Verification',
                    value: session.emailVerified ? 'Verified' : 'Pending',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  final profilePanel = _Panel(
                    title: 'Profile and setup',
                    rows: [
                      _RowData(
                        title: workspaceName,
                        primary: _joinNonEmpty([
                          _read(profile, 'legalName'),
                          _read(profile, 'brandName'),
                        ]),
                        secondary: _joinNonEmpty([
                          _read(profile, 'primaryEmail', fallback: session.email),
                          _read(profile, 'primaryTimezone'),
                        ]),
                        actionLabel: 'Edit profile',
                        onTap: () => _showProfileEditor(data),
                      ),
                      _RowData(
                        title: 'Website and booking',
                        primary: _joinNonEmpty([
                          websiteUrl,
                          bookingUrl,
                        ]).isEmpty
                            ? 'No public links added yet.'
                            : _joinNonEmpty([websiteUrl, bookingUrl]),
                        secondary: 'These stay editable without waiting for plan activation.',
                        actionLabel: websiteUrl.isNotEmpty
                            ? 'Open website'
                            : bookingUrl.isNotEmpty
                                ? 'Open booking link'
                                : null,
                        onTap: websiteUrl.isNotEmpty
                            ? () => _openUrl(websiteUrl)
                            : bookingUrl.isNotEmpty
                                ? () => _openUrl(bookingUrl)
                                : null,
                      ),
                      _RowData(
                        title: 'Setup readiness',
                        primary: session.hasSetupCompleted
                            ? 'Setup completed'
                            : 'Setup still needs completion',
                        secondary: setupPlanSummary.isEmpty ? 'No setup scope saved yet.' : setupPlanSummary,
                        actionLabel: 'Open setup',
                        onTap: () => context.go('/client/setup'),
                      ),
                    ],
                    emptyLabel: 'No profile details are available yet.',
                  );

                  final controlPanel = _Panel(
                    title: 'Billing and account control',
                    rows: [
                      _RowData(
                        title: 'Subscription standing',
                        primary: billingStatus,
                        secondary: subscriptionSummary,
                        actionLabel: 'Open billing portal',
                        onTap: _openBillingPortal,
                      ),
                      _RowData(
                        title: 'Outstanding balance',
                        primary: outstanding,
                        secondary: _intValue(billing['invoiceCount']) == 0
                            ? 'No invoices are currently visible.'
                            : '${_intValue(billing['invoiceCount'])} invoices are on record.',
                      ),
                      _RowData(
                        title: 'Support and account closure',
                        primary: 'Help stays available directly from the client side.',
                        secondary:
                            'If you need to stop the account, use the closure action here rather than leaving the workspace unclear.',
                        actionLabel: 'Deactivate account',
                        onTap: _showDeactivateDialog,
                      ),
                    ],
                    emptyLabel: 'No billing control is available yet.',
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        profilePanel,
                        const SizedBox(height: 16),
                        controlPanel,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: profilePanel),
                      const SizedBox(width: 16),
                      Expanded(child: controlPanel),
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
}

String _resolvePlanLabel(
  Map<String, dynamic> subscription, {
  required AuthSessionController session,
}) {
  final explicit = _read(subscription, 'displayPlanLabel');
  if (explicit.isNotEmpty) return explicit;

  final service = _title(
    _read(
      subscription,
      'service',
      fallback: _read(subscription, 'lane', fallback: _read(subscription, 'plan', fallback: '')),
    ),
  );
  final tier = _title(_read(subscription, 'tier', fallback: ''));

  if (service.isNotEmpty && tier.isNotEmpty) return '$service · $tier';
  if (service.isNotEmpty) return service;
  if (tier.isNotEmpty) return tier;

  final setupService = _title(session.selectedPlan ?? '');
  final setupTier = _title(session.selectedTier ?? '');
  if (setupService.isNotEmpty && setupTier.isNotEmpty) return '$setupService · $setupTier';
  if (setupTier.isNotEmpty) return setupTier;
  if (setupService.isNotEmpty) return setupService;
  return '';
}

String _formatDate(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return value.trim();
  final local = parsed.toLocal();
  final month = _monthName(local.month);
  return '$month ${local.day}, ${local.year}';
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[(month - 1).clamp(0, 11)];
}

String _accountState(AuthSessionController session) {
  if (!session.emailVerified) return 'Verification pending';
  if (!session.hasSetupCompleted) return 'Draft';
  if (session.normalizedSubscriptionStatus == 'active') return 'Active';
  return 'Review';
}

class _AccountViewData {
  const _AccountViewData({
    required this.overview,
    required this.profile,
    required this.subscription,
  });

  final Map<String, dynamic> overview;
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? subscription;
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<_HeroAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.publicMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(label),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: metrics
          .map(
            (metric) => Container(
              constraints: const BoxConstraints(minWidth: 160),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.publicMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.publicText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
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
      padding: const EdgeInsets.all(32),
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
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            )
          else
            ...List.generate(rows.length, (index) {
              final row = rows[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == rows.length - 1 ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PanelRow(data: row),
                    if (index != rows.length - 1) ...[
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: AppTheme.publicLine),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({required this.data});

  final _RowData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.publicText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                data.primary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicText,
                    ),
              ),
              if (data.secondary.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  data.secondary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.publicMuted,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (data.actionLabel != null && data.onTap != null) ...[
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: data.onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(data.actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _RowData {
  const _RowData({
    required this.title,
    required this.primary,
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

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog({
    required this.initialProfile,
    required this.repository,
  });

  final Map<String, dynamic> initialProfile;
  final ClientAccountRepository repository;

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _legalName;
  late final TextEditingController _brandName;
  late final TextEditingController _contactName;
  late final TextEditingController _contactTitle;
  late final TextEditingController _primaryEmail;
  late final TextEditingController _phone;
  late final TextEditingController _websiteUrl;
  late final TextEditingController _bookingUrl;
  late final TextEditingController _billingEmail;
  late final TextEditingController _timezone;
  late final TextEditingController _currencyCode;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _legalName = TextEditingController(text: _read(profile, 'legalName'));
    _brandName = TextEditingController(text: _read(profile, 'brandName'));
    _contactName = TextEditingController(text: _read(profile, 'contactName'));
    _contactTitle = TextEditingController(text: _read(profile, 'contactTitle'));
    _primaryEmail = TextEditingController(text: _read(profile, 'primaryEmail'));
    _phone = TextEditingController(text: _read(profile, 'phone'));
    _websiteUrl = TextEditingController(text: _read(profile, 'websiteUrl'));
    _bookingUrl = TextEditingController(text: _read(profile, 'bookingUrl'));
    _billingEmail = TextEditingController(text: _read(profile, 'billingEmail'));
    _timezone = TextEditingController(text: _read(profile, 'primaryTimezone', fallback: 'America/New_York'));
    _currencyCode = TextEditingController(text: _read(profile, 'currencyCode', fallback: 'USD'));
  }

  @override
  void dispose() {
    _legalName.dispose();
    _brandName.dispose();
    _contactName.dispose();
    _contactTitle.dispose();
    _primaryEmail.dispose();
    _phone.dispose();
    _websiteUrl.dispose();
    _bookingUrl.dispose();
    _billingEmail.dispose();
    _timezone.dispose();
    _currencyCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository.updateClientProfile(
        legalName: _legalName.text.trim(),
        brandName: _brandName.text.trim(),
        contactName: _contactName.text.trim(),
        contactTitle: _contactTitle.text.trim(),
        primaryEmail: _primaryEmail.text.trim(),
        phone: _phone.text.trim(),
        websiteUrl: _websiteUrl.text.trim(),
        bookingUrl: _bookingUrl.text.trim(),
        billingEmail: _billingEmail.text.trim(),
        primaryTimezone: _timezone.text.trim(),
        currencyCode: _currencyCode.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() {
        _error = 'Profile updates could not be saved right now.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(controller: _legalName, label: 'Legal name'),
              _Field(controller: _brandName, label: 'Brand name'),
              _Field(controller: _contactName, label: 'Primary contact'),
              _Field(controller: _contactTitle, label: 'Contact title'),
              _Field(controller: _primaryEmail, label: 'Primary email'),
              _Field(controller: _phone, label: 'Phone'),
              _Field(controller: _websiteUrl, label: 'Website URL'),
              _Field(controller: _bookingUrl, label: 'Booking URL'),
              _Field(controller: _billingEmail, label: 'Billing email'),
              _Field(controller: _timezone, label: 'Timezone'),
              _Field(controller: _currencyCode, label: 'Currency code'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _DeactivateAccountDialog extends StatefulWidget {
  const _DeactivateAccountDialog({required this.repository});

  final ClientAccountRepository repository;

  @override
  State<_DeactivateAccountDialog> createState() => _DeactivateAccountDialogState();
}

class _DeactivateAccountDialogState extends State<_DeactivateAccountDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _deactivate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.repository.deactivateAccount();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Account closure could not be completed right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Deactivate account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This will close the client account and end access to the workspace.'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _deactivate,
          child: Text(_loading ? 'Closing...' : 'Deactivate'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return const <String, dynamic>{};
}

String _displayIdentity(Map<String, dynamic> source, {String fallback = 'Orchestrate Operations'}) {
  final candidates = <String>[
    _read(source, 'displayName'),
    _read(source, 'brandName'),
    _read(source, 'legalName'),
    _read(source, 'name'),
    fallback,
  ];

  for (final value in candidates) {
    if (value.trim().isNotEmpty) return value.trim();
  }

  return 'Orchestrate Operations';
}

String _read(Map<String, dynamic> source, String key, {String fallback = ''}) {
  final value = source[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _title(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .trim()
      .split(RegExp(r'[\s_\-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _joinNonEmpty(List<String> values) {
  return values.map((value) => value.trim()).where((value) => value.isNotEmpty).join(' · ');
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _centsToMoney(int cents, String currencyCode) {
  final amount = cents / 100;
  final symbol = currencyCode.trim().toUpperCase() == 'USD' ? '\$' : '${currencyCode.trim().toUpperCase()} ';
  return '$symbol${amount.toStringAsFixed(2)}';
}
