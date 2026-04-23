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
      if (mounted) context.go('/auth/login');
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
        final planLabel = _resolvedPlanLabel(subscription, session);
        final billingStatus = _title(
          _read(subscription, 'status', fallback: session.subscriptionStatus),
        );
        final currency = _read(profile, 'currencyCode', fallback: 'USD');
        final periodEnd = _read(subscription, 'currentPeriodEnd');
        final websiteUrl = _read(profile, 'websiteUrl');
        final bookingUrl = _read(profile, 'bookingUrl');
        final outstanding = _centsToMoney(_intValue(billing['outstandingCents']), currency);

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
                    onPressed: () => context.go('/contact'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MetricStrip(
                metrics: [
                  _MetricData(label: 'Account state', value: _accountState(session)),
                  _MetricData(label: 'Plan', value: planLabel),
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
                    title: 'Profile and links',
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
                        secondary: 'These stay editable directly from account.',
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
                    ],
                    emptyLabel: 'No profile details are available yet.',
                  );

                  final controlPanel = _Panel(
                    title: 'Billing and account control',
                    rows: [
                      _RowData(
                        title: 'Subscription standing',
                        primary: billingStatus,
                        secondary: _joinNonEmpty([
                          planLabel == 'Not set' ? '' : planLabel,
                          periodEnd,
                        ]),
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
                        const SizedBox(height: 18),
                        controlPanel,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: profilePanel),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: controlPanel),
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
  late final TextEditingController _displayName;
  late final TextEditingController _legalName;
  late final TextEditingController _brandName;
  late final TextEditingController _websiteUrl;
  late final TextEditingController _bookingUrl;
  late final TextEditingController _timezone;
  late final TextEditingController _currency;
  late final TextEditingController _headline;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _displayName = TextEditingController(text: _read(p, 'displayName'));
    _legalName = TextEditingController(text: _read(p, 'legalName'));
    _brandName = TextEditingController(text: _read(p, 'brandName'));
    _websiteUrl = TextEditingController(text: _read(p, 'websiteUrl'));
    _bookingUrl = TextEditingController(text: _read(p, 'bookingUrl'));
    _timezone = TextEditingController(text: _read(p, 'primaryTimezone'));
    _currency = TextEditingController(text: _read(p, 'currencyCode', fallback: 'USD'));
    _headline = TextEditingController(text: _read(p, 'welcomeHeadline'));
  }

  @override
  void dispose() {
    _displayName.dispose();
    _legalName.dispose();
    _brandName.dispose();
    _websiteUrl.dispose();
    _bookingUrl.dispose();
    _timezone.dispose();
    _currency.dispose();
    _headline.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final displayName = _displayName.text.trim();
    final legalName = _legalName.text.trim();
    if (displayName.isEmpty || legalName.isEmpty) {
      setState(() => _error = 'Display name and legal name are required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository.updateClientProfile(
        displayName: displayName,
        legalName: legalName,
        brandName: _brandName.text.trim(),
        websiteUrl: _websiteUrl.text.trim(),
        bookingUrl: _bookingUrl.text.trim(),
        primaryTimezone: _timezone.text.trim(),
        currencyCode: _currency.text.trim(),
        welcomeHeadline: _headline.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Profile could not be updated right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit profile', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Keep the client identity and public links current without leaving the account surface.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.publicMuted),
                ),
                const SizedBox(height: 20),
                _FormRow(
                  left: _Field(controller: _displayName, label: 'Display name'),
                  right: _Field(controller: _legalName, label: 'Legal name'),
                ),
                const SizedBox(height: 14),
                _FormRow(
                  left: _Field(controller: _brandName, label: 'Brand name'),
                  right: _Field(controller: _timezone, label: 'Primary timezone'),
                ),
                const SizedBox(height: 14),
                _FormRow(
                  left: _Field(controller: _websiteUrl, label: 'Website URL'),
                  right: _Field(controller: _bookingUrl, label: 'Booking URL'),
                ),
                const SizedBox(height: 14),
                _FormRow(
                  left: _Field(controller: _currency, label: 'Currency code'),
                  right: _Field(controller: _headline, label: 'Welcome headline'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.red.shade700),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving...' : 'Save changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_confirmation.text.trim().toUpperCase() != 'DEACTIVATE') {
      setState(() => _error = 'Type DEACTIVATE to continue.');
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await widget.repository.deactivateClientAccount(
        reason: _reason.text.trim(),
        confirmationText: _confirmation.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = 'The account could not be deactivated right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deactivate account', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'This closes the client account from the account surface instead of leaving access in an unclear state.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 18),
            _Field(
              controller: _reason,
              label: 'Reason',
              minLines: 3,
            ),
            const SizedBox(height: 14),
            _Field(
              controller: _confirmation,
              label: 'Type DEACTIVATE to confirm',
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _working ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _working ? null : _submit,
                  child: Text(_working ? 'Working...' : 'Deactivate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
            ],
          );

          final actionRow = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final action in actions)
                action.isPrimary
                    ? FilledButton(onPressed: action.onPressed, child: Text(action.label))
                    : OutlinedButton(onPressed: action.onPressed, child: Text(action.label)),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 18), actionRow],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: text), const SizedBox(width: 24), actionRow],
          );
        },
      ),
    );
  }
}

class _HeroAction {
  const _HeroAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.minLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 6,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)],
        );
      },
    );
  }
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

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class _RowData {
  const _RowData({
    required this.title,
    required this.primary,
    required this.secondary,
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

String _resolvedPlanLabel(
  Map<String, dynamic> subscription,
  AuthSessionController session,
) {
  final explicit = _read(subscription, 'displayPlanLabel');
  if (explicit.isNotEmpty) return explicit;

  final livePlan = _composePlanLabel(
    plan: _read(subscription, 'service', fallback: _read(subscription, 'lane')),
    tier: _read(subscription, 'tier'),
  );
  if (livePlan.isNotEmpty) return livePlan;

  final sessionPlan = _composePlanLabel(
    plan: session.commercialPlan ?? session.selectedPlan,
    tier: session.commercialTier ?? session.selectedTier,
  );
  if (sessionPlan.isNotEmpty) return sessionPlan;

  return 'Not set';
}

String _composePlanLabel({String? plan, String? tier}) {
  final normalizedPlan = _title(plan ?? '');
  final normalizedTier = _title(tier ?? '');
  if (normalizedPlan.isEmpty && normalizedTier.isEmpty) return '';
  if (normalizedPlan.isEmpty) return normalizedTier;
  if (normalizedTier.isEmpty) return normalizedPlan;
  return '$normalizedPlan · $normalizedTier';
}

String _joinNonEmpty(List<String> values) {
  return values.where((value) => value.trim().isNotEmpty).join(' · ');
}

String _title(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  return text
      .split(RegExp(r'[\s_-]+'))
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _displayIdentity(Map<String, dynamic> map, {String fallback = 'Client workspace'}) {
  final candidates = [
    _read(map, 'displayName'),
    _read(map, 'brandName'),
    _read(map, 'legalName'),
  ];

  for (final value in candidates) {
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _accountState(AuthSessionController session) {
  if (!session.emailVerified) return 'Verification pending';
  if (!session.hasSetupCompleted) return 'Draft';
  if (session.normalizedSubscriptionStatus == 'active') return 'Active';
  return 'Review';
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _centsToMoney(int cents, String currency) {
  if (cents <= 0) return 'No outstanding balance';
  final amount = (cents / 100).toStringAsFixed(2);
  return '$currency $amount';
}