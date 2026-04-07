
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';
import '../data/repositories/client_portal_repository.dart';

enum ClientSection {
  overview,
  billing,
  agreements,
  statements,
  account,
}

class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({
    super.key,
    required this.section,
  });

  final ClientSection section;

  @override
  Widget build(BuildContext context) {
    if (section == ClientSection.account) {
      return const _ClientAccountSurface();
    }

    final repository = ClientPortalRepository();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: AsyncSurface<_ClientLoadState>(
              future: _loadSafe(repository),
              builder: (context, data) {
                final state = data ?? _ClientLoadState(view: _ClientViewData.empty(section));
                if (state.errorMessage != null) {
                  return _ScreenMessage(
                    title: 'This area could not load right now.',
                    message: state.errorMessage!,
                  );
                }

                final view = state.view;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WorkspaceHero(
                      eyebrow: _eyebrowForSection(section),
                      title: view.title,
                      subtitle: view.subtitle,
                      ctaLabel: _ctaLabelForSection(section),
                      onCta: () => _handlePrimaryAction(context, section),
                    ),
                    const SizedBox(height: 18),
                    if (view.notice != null) ...[
                      _InlineNotice(message: view.notice!),
                      const SizedBox(height: 18),
                    ],
                    if (view.subscription != null) ...[
                      _SubscriptionBand(
                        subscription: view.subscription!,
                        onManageBilling: () => _handleManageBilling(context, repository),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (view.metrics.isNotEmpty) ...[
                      _MetricsGrid(metrics: view.metrics),
                      const SizedBox(height: 18),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 980;
                        if (stacked || view.secondaryTitle == null) {
                          return Column(
                            children: [
                              _DataPanel(
                                title: view.primaryTitle,
                                rows: view.primaryRows,
                                emptyLabel: view.primaryEmpty,
                              ),
                              if (view.secondaryTitle != null) ...[
                                const SizedBox(height: 18),
                                _DataPanel(
                                  title: view.secondaryTitle!,
                                  rows: view.secondaryRows,
                                  emptyLabel: view.secondaryEmpty,
                                ),
                              ],
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _DataPanel(
                                title: view.primaryTitle,
                                rows: view.primaryRows,
                                emptyLabel: view.primaryEmpty,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 5,
                              child: _DataPanel(
                                title: view.secondaryTitle!,
                                rows: view.secondaryRows,
                                emptyLabel: view.secondaryEmpty,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _eyebrowForSection(ClientSection section) {
    switch (section) {
      case ClientSection.overview:
        return 'Client workspace';
      case ClientSection.billing:
        return 'Payment standing';
      case ClientSection.agreements:
        return 'Service footing';
      case ClientSection.statements:
        return 'Recorded summaries';
      case ClientSection.account:
        return 'Account';
    }
  }

  String _ctaLabelForSection(ClientSection section) {
    switch (section) {
      case ClientSection.overview:
        return 'Review account';
      case ClientSection.billing:
        return 'Manage billing';
      case ClientSection.agreements:
        return 'Open account';
      case ClientSection.statements:
        return 'Open account';
      case ClientSection.account:
        return 'Update details';
    }
  }

  void _handlePrimaryAction(BuildContext context, ClientSection section) {
    switch (section) {
      case ClientSection.overview:
      case ClientSection.agreements:
      case ClientSection.statements:
      case ClientSection.account:
        context.go('/client/account');
        break;
      case ClientSection.billing:
        context.go('/client/billing');
        break;
    }
  }

  Future<void> _handleManageBilling(
    BuildContext context,
    ClientPortalRepository repository,
  ) async {
    try {
      final url = await repository.createBillingPortalSession();
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid billing portal URL');
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Billing could not open right now.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing could not open right now.')),
      );
    }
  }

  Future<_ClientLoadState> _loadSafe(ClientPortalRepository repository) async {
    try {
      return _ClientLoadState(view: await _load(repository));
    } catch (error) {
      return _ClientLoadState(
        view: _ClientViewData.empty(section),
        errorMessage: _humanizeError(error),
      );
    }
  }

  Future<_ClientViewData> _load(ClientPortalRepository repository) async {
    switch (section) {
      case ClientSection.overview:
        final overview = await repository.fetchOverview();
        final billing = _asMap(overview['billing']);
        final activity = _asMap(overview['activity']);
        final communications = _asMap(overview['communications']);
        final client = _asMap(overview['client']);
        final displayName = _read(client, 'displayName', fallback: _read(client, 'legalName', fallback: 'Client account'));

        return _ClientViewData(
          title: 'Your workspace at a glance',
          subtitle: 'Current standing, live delivery, and what needs your attention next.',
          notice: AppTheme.publicBackground != Colors.transparent
              ? 'Your workspace stays aligned with your current setup, plan, and account details.'
              : null,
          metrics: [
            _Metric(label: 'Outstanding', value: _money(billing['outstandingCents']), tone: AppTheme.amber),
            _Metric(label: 'Meetings', value: _num(activity['meetings']), tone: AppTheme.emerald),
            _Metric(label: 'Replies', value: _num(activity['replies'])),
            _Metric(label: 'Alerts', value: _num(communications['openNotifications']), tone: AppTheme.rose),
          ],
          primaryTitle: 'Account view',
          primaryRows: [
            _DataRow(
              title: displayName,
              primary: [_read(client, 'status'), _read(client, 'industry')]
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
              secondary: [_read(client, 'websiteUrl'), _read(client, 'primaryTimezone')]
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
            ),
            _DataRow(
              title: 'Coverage and service',
              primary: _read(client, 'selectedPlan', fallback: 'Plan selected'),
              secondary: 'Review your account to update market direction and company details.',
            ),
          ],
          secondaryTitle: 'Billing standing',
          secondaryRows: [
            _DataRow(
              title: 'Invoices',
              primary: _num(billing['invoiceCount']),
              secondary: '${_money(billing['collectedCents'])} collected',
            ),
            _DataRow(
              title: 'Balance',
              primary: _money(billing['outstandingCents']),
              secondary: '${_money(billing['overdueCents'])} overdue',
            ),
          ],
        );

      case ClientSection.billing:
        final results = await Future.wait([
          repository.fetchInvoices(),
          repository.fetchSubscription(),
        ]);
        final invoices = results[0] as List<dynamic>;
        final subscription = results[1] as Map<String, dynamic>?;

        return _ClientViewData(
          title: 'Billing and payment standing',
          subtitle: 'Invoices, receipts, and your current subscription.',
          subscription: subscription,
          metrics: [
            _Metric(label: 'Invoices', value: '${invoices.length}'),
            _Metric(
              label: 'Paid',
              value: '${_countBy(invoices, (item) => _read(item, 'status') == 'PAID')}',
              tone: AppTheme.emerald,
            ),
            _Metric(
              label: 'Open',
              value: '${_countBy(invoices, (item) {
                final status = _read(item, 'status');
                return status == 'OPEN' ||
                    status == 'ISSUED' ||
                    status == 'OVERDUE' ||
                    status == 'PARTIALLY_PAID';
              })}',
              tone: AppTheme.amber,
            ),
          ],
          primaryTitle: 'Recent invoices',
          primaryRows: invoices.take(12).map(_invoiceRow).toList(),
          primaryEmpty: 'No invoices are available yet.',
        );

      case ClientSection.agreements:
        final agreements = await repository.fetchAgreements();
        return _ClientViewData(
          title: 'Agreements and renewals',
          subtitle: 'Service agreements and their current standing.',
          primaryTitle: 'Agreements',
          primaryRows: agreements.take(12).map(_agreementRow).toList(),
          primaryEmpty: 'No agreements are available yet.',
        );

      case ClientSection.statements:
        final statements = await repository.fetchStatements();
        return _ClientViewData(
          title: 'Statements and record summaries',
          subtitle: 'Quarterly, half-year, and annual summaries when available.',
          primaryTitle: 'Statements',
          primaryRows: statements.take(12).map(_statementRow).toList(),
          primaryEmpty: 'No statements are available yet.',
        );

      case ClientSection.account:
        return _ClientViewData.empty(section);
    }
  }
}

class _ClientAccountSurface extends StatefulWidget {
  const _ClientAccountSurface();

  @override
  State<_ClientAccountSurface> createState() => _ClientAccountSurfaceState();
}

class _ClientAccountSurfaceState extends State<_ClientAccountSurface> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _legalName = TextEditingController();
  final _websiteUrl = TextEditingController();
  final _bookingUrl = TextEditingController();
  final _primaryTimezone = TextEditingController();
  final _currencyCode = TextEditingController();
  final _brandName = TextEditingController();
  final _logoUrl = TextEditingController();
  final _primaryColor = TextEditingController();
  final _accentColor = TextEditingController();
  final _welcomeHeadline = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _message;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _legalName.dispose();
    _websiteUrl.dispose();
    _bookingUrl.dispose();
    _primaryTimezone.dispose();
    _currencyCode.dispose();
    _brandName.dispose();
    _logoUrl.dispose();
    _primaryColor.dispose();
    _accentColor.dispose();
    _welcomeHeadline.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ClientPortalRepository().fetchClientProfile();
      _profile = data;
      _displayName.text = _read(data, 'displayName');
      _legalName.text = _read(data, 'legalName');
      _websiteUrl.text = _read(data, 'websiteUrl');
      _bookingUrl.text = _read(data, 'bookingUrl');
      _primaryTimezone.text = _read(data, 'primaryTimezone');
      _currencyCode.text = _read(data, 'currencyCode');
      _brandName.text = _read(data, 'brandName');
      _logoUrl.text = _read(data, 'logoUrl');
      _primaryColor.text = _read(data, 'primaryColor');
      _accentColor.text = _read(data, 'accentColor');
      _welcomeHeadline.text = _read(data, 'welcomeHeadline');
    } catch (error) {
      _error = _humanizeError(error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _message = null;
      _error = null;
    });

    try {
      final saved = await ClientPortalRepository().updateClientProfile(
        displayName: _displayName.text,
        legalName: _legalName.text,
        websiteUrl: _websiteUrl.text,
        bookingUrl: _bookingUrl.text,
        primaryTimezone: _primaryTimezone.text,
        currencyCode: _currencyCode.text,
        brandName: _brandName.text,
        logoUrl: _logoUrl.text,
        primaryColor: _primaryColor.text,
        accentColor: _accentColor.text,
        welcomeHeadline: _welcomeHeadline.text,
      );

      _profile = saved;
      await AuthSessionController.instance.applyClientSetupResponse({
        'client': {
          'setupCompleted': true,
          'selectedPlan': _profile?['selectedPlan'],
          'subscriptionStatus': _profile?['subscriptionStatus'],
          'setup': _profile?['setup'],
        },
      });

      if (!mounted) return;
      setState(() {
        _editing = false;
        _message = 'Your account details were updated.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _humanizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _profile == null) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: _ScreenMessage(
                title: 'Account details could not load right now.',
                message: _error!,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WorkspaceHero(
                  eyebrow: 'Account',
                  title: 'Company identity and workspace details',
                  subtitle: 'Keep your account current so your workspace, records, and billing stay aligned.',
                  ctaLabel: _editing ? 'Stop editing' : 'Update details',
                  onCta: () => setState(() {
                    _editing = !_editing;
                    _message = null;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 18),
                if (_message != null) ...[
                  _InlineNotice(message: _message!),
                  const SizedBox(height: 18),
                ],
                if (_error != null) ...[
                  _InlineNotice(message: _error!, error: true),
                  const SizedBox(height: 18),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 980;

                    final preview = _IdentityPreviewCard(
                      displayName: _displayName.text,
                      brandName: _brandName.text,
                      logoUrl: _logoUrl.text,
                      primaryColor: _primaryColor.text,
                      accentColor: _accentColor.text,
                      headline: _welcomeHeadline.text,
                      websiteUrl: _websiteUrl.text,
                      bookingUrl: _bookingUrl.text,
                    );

                    final details = _EditableAccountPanel(
                      formKey: _formKey,
                      editing: _editing,
                      saving: _saving,
                      displayName: _displayName,
                      legalName: _legalName,
                      websiteUrl: _websiteUrl,
                      bookingUrl: _bookingUrl,
                      primaryTimezone: _primaryTimezone,
                      currencyCode: _currencyCode,
                      brandName: _brandName,
                      logoUrl: _logoUrl,
                      primaryColor: _primaryColor,
                      accentColor: _accentColor,
                      welcomeHeadline: _welcomeHeadline,
                      onSave: _save,
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          preview,
                          const SizedBox(height: 18),
                          details,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: preview),
                        const SizedBox(width: 18),
                        Expanded(flex: 7, child: details),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableAccountPanel extends StatelessWidget {
  const _EditableAccountPanel({
    required this.formKey,
    required this.editing,
    required this.saving,
    required this.displayName,
    required this.legalName,
    required this.websiteUrl,
    required this.bookingUrl,
    required this.primaryTimezone,
    required this.currencyCode,
    required this.brandName,
    required this.logoUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.welcomeHeadline,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final bool editing;
  final bool saving;
  final TextEditingController displayName;
  final TextEditingController legalName;
  final TextEditingController websiteUrl;
  final TextEditingController bookingUrl;
  final TextEditingController primaryTimezone;
  final TextEditingController currencyCode;
  final TextEditingController brandName;
  final TextEditingController logoUrl;
  final TextEditingController primaryColor;
  final TextEditingController accentColor;
  final TextEditingController welcomeHeadline;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _DataPanel(
      title: editing ? 'Update account details' : 'Current account details',
      customChild: Form(
        key: formKey,
        child: Column(
          children: [
            _AccountFieldRow(
              child: _field(
                controller: displayName,
                label: 'Display name',
                enabled: editing,
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: legalName,
                label: 'Legal name',
                enabled: editing,
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: websiteUrl,
                label: 'Website',
                enabled: editing,
                required: false,
                keyboardType: TextInputType.url,
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: bookingUrl,
                label: 'Booking link',
                enabled: editing,
                required: false,
                keyboardType: TextInputType.url,
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: primaryTimezone,
                label: 'Primary timezone',
                enabled: editing,
                required: false,
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: currencyCode,
                label: 'Currency',
                enabled: editing,
                required: false,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Workspace presentation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.publicText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _AccountFieldRow(
              child: _field(
                controller: brandName,
                label: 'Brand name',
                enabled: editing,
                required: false,
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: logoUrl,
                label: 'Logo URL',
                enabled: editing,
                required: false,
                keyboardType: TextInputType.url,
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: primaryColor,
                label: 'Primary color',
                enabled: editing,
                required: false,
                hintText: '#111827',
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: accentColor,
                label: 'Accent color',
                enabled: editing,
                required: false,
                hintText: '#2563eb',
              ),
            ),
            _AccountFieldRow(
              child: _field(
                controller: welcomeHeadline,
                label: 'Workspace headline',
                enabled: editing,
                required: false,
              ),
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: Text(saving ? 'Saving...' : 'Save changes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _field({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    bool required = true,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? '$label is required.' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        filled: !enabled,
        fillColor: enabled ? null : const Color(0xFFF7F8F5),
      ),
    );
  }
}

class _AccountFieldRow extends StatelessWidget {
  const _AccountFieldRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: child,
    );
  }
}

class _IdentityPreviewCard extends StatelessWidget {
  const _IdentityPreviewCard({
    required this.displayName,
    required this.brandName,
    required this.logoUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.headline,
    required this.websiteUrl,
    required this.bookingUrl,
  });

  final String displayName;
  final String brandName;
  final String logoUrl;
  final String primaryColor;
  final String accentColor;
  final String headline;
  final String websiteUrl;
  final String bookingUrl;

  @override
  Widget build(BuildContext context) {
    final primary = _parseColor(primaryColor, const Color(0xFF111827));
    final accent = _parseColor(accentColor, const Color(0xFF2563EB));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.white.withOpacity(0.12),
                  child: logoUrl.trim().isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.apartment_rounded, color: Colors.white),
                        )
                      : const Icon(Icons.apartment_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  brandName.trim().isNotEmpty
                      ? brandName
                      : (displayName.trim().isNotEmpty ? displayName : 'Client workspace'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            headline.trim().isNotEmpty
                ? headline
                : 'Your client workspace is presented with the identity and details you set here.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'This is not a placeholder surface. It is the account layer clients return to for continuity, billing, and account footing.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                ),
          ),
          if (websiteUrl.trim().isNotEmpty || bookingUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            if (websiteUrl.trim().isNotEmpty)
              _PreviewLine(label: 'Website', value: websiteUrl),
            if (bookingUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _PreviewLine(label: 'Booking', value: bookingUrl),
            ],
          ],
        ],
      ),
    );
  }

  Color _parseColor(String raw, Color fallback) {
    final normalized = raw.trim().replaceAll('#', '');
    if (normalized.length != 6) return fallback;
    final value = int.tryParse('FF$normalized', radix: 16);
    return value == null ? fallback : Color(value);
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label · $value',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.88),
          ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;

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
          final stacked = constraints.maxWidth < 860;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.publicMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.02,
                    ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.publicMuted,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          );

          final action = FilledButton(
            onPressed: onCta,
            child: Text(ctaLabel),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: 18),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 18),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _SubscriptionBand extends StatelessWidget {
  const _SubscriptionBand({
    required this.subscription,
    required this.onManageBilling,
  });

  final Map<String, dynamic> subscription;
  final VoidCallback onManageBilling;

  @override
  Widget build(BuildContext context) {
    return _DataPanel(
      title: 'Current subscription',
      trailing: TextButton(
        onPressed: onManageBilling,
        child: const Text('Manage billing'),
      ),
      customChild: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _Metric(label: 'Plan', value: _read(subscription, 'plan', fallback: '—')),
            _Metric(label: 'Status', value: _read(subscription, 'status', fallback: '—')),
            _Metric(label: 'Amount', value: _subscriptionAmount(subscription)),
            _Metric(label: 'Next billing', value: _subscriptionDate(subscription['currentPeriodEnd'])),
          ];

          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _MetricTile(metric: items[index]),
                  if (index != items.length - 1)
                    const Divider(height: 1, thickness: 1, color: AppTheme.publicLine),
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                Expanded(child: _MetricTile(metric: items[index])),
                if (index != items.length - 1)
                  Container(width: 1, height: 72, color: AppTheme.publicLine),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120 ? 4 : width >= 760 ? 2 : 1;
        final gap = 16.0;
        final itemWidth = columns == 1 ? width : (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: metric.tone ?? AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: metric.tone ?? AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.title,
    this.rows = const [],
    this.emptyLabel = 'Nothing is available.',
    this.trailing,
    this.customChild,
  });

  final String title;
  final List<_DataRow> rows;
  final String emptyLabel;
  final Widget? trailing;
  final Widget? customChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          if (customChild != null)
            customChild!
          else if (rows.isEmpty)
            Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.publicMuted,
                  ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _DataRowTile(row: rows[index]),
                  if (index != rows.length - 1)
                    const Divider(height: 24, thickness: 1, color: AppTheme.publicLine),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _DataRowTile extends StatelessWidget {
  const _DataRowTile({required this.row});

  final _DataRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.publicText,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (row.primary.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            row.primary,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
        if (row.secondary.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            row.secondary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    this.error = false,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? Colors.red.shade50 : const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error ? Colors.red.shade100 : AppTheme.publicLine,
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: error ? Colors.red.shade700 : AppTheme.publicText,
            ),
      ),
    );
  }
}

class _ScreenMessage extends StatelessWidget {
  const _ScreenMessage({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _ClientLoadState {
  const _ClientLoadState({
    required this.view,
    this.errorMessage,
  });

  final _ClientViewData view;
  final String? errorMessage;
}

class _ClientViewData {
  const _ClientViewData({
    required this.title,
    required this.subtitle,
    this.notice,
    this.subscription,
    this.metrics = const [],
    required this.primaryTitle,
    this.primaryRows = const [],
    this.primaryEmpty = 'Nothing is available.',
    this.secondaryTitle,
    this.secondaryRows = const [],
    this.secondaryEmpty = 'Nothing is available.',
  });

  final String title;
  final String subtitle;
  final String? notice;
  final Map<String, dynamic>? subscription;
  final List<_Metric> metrics;
  final String primaryTitle;
  final List<_DataRow> primaryRows;
  final String primaryEmpty;
  final String? secondaryTitle;
  final List<_DataRow> secondaryRows;
  final String secondaryEmpty;

  factory _ClientViewData.empty(ClientSection section) {
    return _ClientViewData(
      title: section.name[0].toUpperCase() + section.name.substring(1),
      subtitle: '',
      primaryTitle: 'Overview',
    );
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    this.tone,
  });

  final String label;
  final String value;
  final Color? tone;
}

class _DataRow {
  const _DataRow({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondary;
}

_DataRow _invoiceRow(dynamic item) {
  return _DataRow(
    title: _read(item, 'invoiceNumber', fallback: 'Invoice'),
    primary: '${_money(_asMap(item)['amountDueCents'])} · ${_read(item, 'status', fallback: '—')}',
    secondary: _dateRange(_asMap(item)['issuedAt'], _asMap(item)['dueAt']),
  );
}

_DataRow _agreementRow(dynamic item) {
  return _DataRow(
    title: _read(item, 'title', fallback: 'Agreement'),
    primary: _read(item, 'status', fallback: '—'),
    secondary: _dateRange(_asMap(item)['effectiveAt'], _asMap(item)['expiresAt']),
  );
}

_DataRow _statementRow(dynamic item) {
  return _DataRow(
    title: _read(item, 'title', fallback: 'Statement'),
    primary: _read(item, 'periodLabel', fallback: _read(item, 'statementType', fallback: 'Summary')),
    secondary: _read(item, 'createdAt', fallback: ''),
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _read(dynamic source, String key, {String fallback = ''}) {
  if (source is Map<String, dynamic>) {
    final value = source[key];
    return value == null ? fallback : value.toString();
  }
  if (source is Map) {
    final value = source[key];
    return value == null ? fallback : value.toString();
  }
  return fallback;
}

String _num(dynamic value) {
  if (value == null) return '0';
  if (value is num) return value.toInt().toString();
  return value.toString();
}

String _money(dynamic value) {
  if (value == null) return '\$0';
  final cents = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
  final amount = cents / 100;
  if (amount == amount.roundToDouble()) {
    return '\$${amount.round()}';
  }
  return '\$${amount.toStringAsFixed(2)}';
}

int _countBy(List<dynamic> values, bool Function(dynamic item) predicate) {
  var count = 0;
  for (final item in values) {
    if (predicate(item)) count += 1;
  }
  return count;
}

String _dateRange(dynamic start, dynamic end) {
  final startText = start?.toString().trim() ?? '';
  final endText = end?.toString().trim() ?? '';
  if (startText.isEmpty && endText.isEmpty) return '';
  if (startText.isNotEmpty && endText.isNotEmpty) return '$startText · $endText';
  return startText.isNotEmpty ? startText : endText;
}

String _subscriptionAmount(Map<String, dynamic> subscription) {
  final cents = subscription['amountCents'];
  if (cents == null) return '—';
  return '${_money(cents)} / month';
}

String _subscriptionDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _humanizeError(Object error) {
  final raw = error.toString();
  if (raw.contains('401')) return 'Your session needs to be refreshed. Please sign in again.';
  if (raw.contains('403')) return 'This area is not available for your current access.';
  if (raw.contains('404')) return 'That information is not available yet.';
  if (raw.contains('500')) return 'The workspace ran into a server issue. Please try again.';
  return 'The workspace could not load right now.';
}
