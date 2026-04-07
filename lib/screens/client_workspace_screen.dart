import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/async_surface.dart';
import '../core/widgets/section_header.dart';
import '../data/repositories/client_portal_repository.dart';

enum ClientSection {
  overview,
  billing,
  agreements,
  statements,
  requests,
  notifications,
  account,
}

class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({super.key, required this.section});

  final ClientSection section;

  @override
  Widget build(BuildContext context) {
    if (section == ClientSection.account) {
      return const _ClientAccountSurface();
    }

    final repository = ClientPortalRepository();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: AsyncSurface<_ClientLoadState>(
              future: _loadSafe(repository),
              builder: (context, data) {
                final state = data ?? _ClientLoadState(view: _ClientViewData.empty(section));
                if (state.errorMessage != null) {
                  return _ErrorState(message: state.errorMessage!);
                }

                final view = state.view;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client workspace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.publicMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SectionHeader(
                      title: view.title,
                      subtitle: view.subtitle,
                    ),
                    const SizedBox(height: 16),
                    if (view.notice != null) ...[
                      _NoticeStrip(message: view.notice!, isPositive: AppConfig.hasClientAccess),
                      const SizedBox(height: 16),
                    ],
                    if (view.subscription != null) ...[
                      _SubscriptionPanel(
                        subscription: view.subscription!,
                        onManageBilling: () => _handleManageBilling(context, repository),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (view.stats.isNotEmpty) ...[
                      _StatsBand(stats: view.stats),
                      const SizedBox(height: 18),
                    ],
                    _PanelLayout(
                      primaryTitle: view.primaryTitle,
                      primaryRows: view.primaryRows,
                      primaryEmpty: view.primaryEmpty,
                      secondaryTitle: view.secondaryTitle,
                      secondaryRows: view.secondaryRows,
                      secondaryEmpty: view.secondaryEmpty,
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

  Future<void> _handleManageBilling(
    BuildContext context,
    ClientPortalRepository repository,
  ) async {
    try {
      final url = await repository.createBillingPortalSession();
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('Invalid billing portal URL');
      }

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Billing portal could not open right now.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing portal could not open right now.')),
      );
    }
  }

  Future<_ClientLoadState> _loadSafe(ClientPortalRepository repository) async {
    try {
      final view = await _load(repository);
      return _ClientLoadState(view: view);
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
        return _ClientViewData(
          title: 'Overview',
          subtitle: 'Account standing, active work, billing posture, and open items.',
          notice: AppConfig.hasClientAccess
              ? 'Client access is active for this session.'
              : 'Client access headers have not been provided for this session.',
          stats: [
            _ClientStat('Outstanding', _money(billing['outstandingCents']), tone: AppTheme.amber),
            _ClientStat('Open notifications', _num(communications['openNotifications']), tone: AppTheme.rose),
            _ClientStat('Replies', _num(activity['replies'])),
            _ClientStat('Meetings', _num(activity['meetings']), tone: AppTheme.emerald),
          ],
          primaryTitle: 'Account',
          primaryRows: [
            _ClientRow(
              title: _read(client, 'displayName', fallback: _read(client, 'legalName', fallback: 'Client account')),
              primary: [_read(client, 'status'), _read(client, 'industry')].where((e) => e.isNotEmpty).join(' · '),
              secondary: [_read(client, 'websiteUrl'), _read(client, 'primaryTimezone')].where((e) => e.isNotEmpty).join(' · '),
            ),
            _ClientRow(
              title: 'Portal',
              primary: _read(communications, 'portalUrl'),
              secondary: '${_num(communications['emailDispatches'])} email dispatches',
            ),
          ],
          secondaryTitle: 'Billing standing',
          secondaryRows: [
            _ClientRow(
              title: 'Invoices',
              primary: _num(billing['invoiceCount']),
              secondary: '${_money(billing['collectedCents'])} collected',
            ),
            _ClientRow(
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
          title: 'Billing',
          subtitle: 'Invoices, receipts, and current payment standing.',
          subscription: subscription,
          stats: [
            _ClientStat('Invoices', '${invoices.length}'),
            _ClientStat(
              'Paid',
              '${_countBy(invoices, (item) => _read(item, 'status') == 'PAID')}',
              tone: AppTheme.emerald,
            ),
            _ClientStat(
              'Open',
              '${_countBy(invoices, (item) {
                final status = _read(item, 'status');
                return status == 'OPEN' ||
                    status == 'ISSUED' ||
                    status == 'OVERDUE' ||
                    status == 'PARTIALLY_PAID';
              })}',
              tone: AppTheme.amber,
            ),
          ],
          primaryTitle: 'Invoices',
          primaryRows: invoices.take(12).map(_invoiceRow).toList(),
          primaryEmpty: 'No invoices are available.',
        );

      case ClientSection.agreements:
        final agreements = await repository.fetchAgreements();
        return _ClientViewData(
          title: 'Agreements',
          subtitle: 'Service agreements and current renewal footing.',
          primaryTitle: 'Agreements',
          primaryRows: agreements.take(12).map(_agreementRow).toList(),
          primaryEmpty: 'No agreements are available.',
        );

      case ClientSection.statements:
        final statements = await repository.fetchStatements();
        return _ClientViewData(
          title: 'Statements',
          subtitle: 'Quarterly, half-year, and annual record summaries.',
          primaryTitle: 'Statements',
          primaryRows: statements.take(12).map(_statementRow).toList(),
          primaryEmpty: 'No statements are available.',
        );

      case ClientSection.requests:
        final reminders = await repository.fetchReminders();
        return _ClientViewData(
          title: 'Requests',
          subtitle: 'Items that require attention, response, or scheduled follow-through.',
          primaryTitle: 'Requests',
          primaryRows: reminders.take(12).map(_reminderRow).toList(),
          primaryEmpty: 'No requests are available.',
        );

      case ClientSection.notifications:
        final results = await Future.wait([
          repository.fetchNotifications(),
          repository.fetchEmailDispatches(),
        ]);
        final notifications = results[0];
        final dispatches = results[1];
        return _ClientViewData(
          title: 'Notifications',
          subtitle: 'Account alerts and delivered communications.',
          primaryTitle: 'Notifications',
          primaryRows: notifications.take(8).map(_notificationRow).toList(),
          primaryEmpty: 'No notifications are available.',
          secondaryTitle: 'Delivered emails',
          secondaryRows: dispatches.take(8).map(_dispatchRow).toList(),
          secondaryEmpty: 'No delivered emails are available.',
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
  String? _error;
  String? _message;

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
      final profile = _asMap(data['profile']);
      final branding = _asMap(profile['branding']);
      if (!mounted) return;
      setState(() {
        _displayName.text = _read(profile, 'displayName');
        _legalName.text = _read(profile, 'legalName');
        _websiteUrl.text = _read(profile, 'websiteUrl');
        _bookingUrl.text = _read(profile, 'bookingUrl');
        _primaryTimezone.text = _read(profile, 'primaryTimezone');
        _currencyCode.text = _read(profile, 'currencyCode');
        _brandName.text = _read(branding, 'brandName');
        _logoUrl.text = _read(branding, 'logoUrl');
        _primaryColor.text = _read(branding, 'primaryColor', fallback: '#111827');
        _accentColor.text = _read(branding, 'accentColor', fallback: '#2563eb');
        _welcomeHeadline.text = _read(branding, 'welcomeHeadline');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The client profile could not load right now.';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      await ClientPortalRepository().updateClientProfile(
        displayName: _displayName.text.trim(),
        legalName: _legalName.text.trim(),
        websiteUrl: _websiteUrl.text.trim(),
        bookingUrl: _bookingUrl.text.trim(),
        primaryTimezone: _primaryTimezone.text.trim(),
        currencyCode: _currencyCode.text.trim(),
        brandName: _brandName.text.trim(),
        logoUrl: _logoUrl.text.trim(),
        primaryColor: _primaryColor.text.trim(),
        accentColor: _accentColor.text.trim(),
        welcomeHeadline: _welcomeHeadline.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _message = 'Company profile and office branding have been saved.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The profile could not be saved right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client workspace',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.publicMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const SectionHeader(
                        title: 'Account',
                        subtitle: 'Edit company identity, client-facing office signals, and branding.',
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) _NoticeStrip(message: _error!, isPositive: false),
                      if (_message != null) ...[
                        _NoticeStrip(message: _message!, isPositive: true),
                        const SizedBox(height: 16),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 980;
                          final preview = _OfficePreviewCard(
                            brandName: _brandName.text.isEmpty ? _displayName.text : _brandName.text,
                            logoUrl: _logoUrl.text,
                            primaryColor: _primaryColor.text,
                            accentColor: _accentColor.text,
                            headline: _welcomeHeadline.text,
                          );
                          final form = _TintedPanel(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Company profile', style: Theme.of(context).textTheme.titleLarge),
                                  const SizedBox(height: 18),
                                  _field(_displayName, 'Display name'),
                                  const SizedBox(height: 12),
                                  _field(_legalName, 'Legal name'),
                                  const SizedBox(height: 12),
                                  _field(_websiteUrl, 'Website', keyboardType: TextInputType.url, required: false),
                                  const SizedBox(height: 12),
                                  _field(_bookingUrl, 'Booking URL', keyboardType: TextInputType.url, required: false),
                                  const SizedBox(height: 12),
                                  _field(_primaryTimezone, 'Primary timezone', required: false),
                                  const SizedBox(height: 12),
                                  _field(_currencyCode, 'Currency code', required: false),
                                  const SizedBox(height: 20),
                                  Text('Office branding', style: Theme.of(context).textTheme.titleLarge),
                                  const SizedBox(height: 18),
                                  _field(_brandName, 'Brand name', required: false),
                                  const SizedBox(height: 12),
                                  _field(_logoUrl, 'Logo URL', keyboardType: TextInputType.url, required: false),
                                  const SizedBox(height: 12),
                                  _field(_primaryColor, 'Primary color', required: false, hintText: '#111827'),
                                  const SizedBox(height: 12),
                                  _field(_accentColor, 'Accent color', required: false, hintText: '#2563eb'),
                                  const SizedBox(height: 12),
                                  _field(_welcomeHeadline, 'Welcome headline', required: false),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _saving ? null : _save,
                                      child: Text(_saving ? 'Saving profile...' : 'Save profile'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (stacked) {
                            return Column(
                              children: [preview, const SizedBox(height: 18), form],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: preview),
                              const SizedBox(width: 18),
                              Expanded(flex: 7, child: form),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? '$label is required.' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}

class _OfficePreviewCard extends StatelessWidget {
  const _OfficePreviewCard({
    required this.brandName,
    required this.logoUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.headline,
  });

  final String brandName;
  final String logoUrl;
  final String primaryColor;
  final String accentColor;
  final String headline;

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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.white.withOpacity(0.12),
                    child: logoUrl.trim().isNotEmpty
                        ? Image.network(
                            logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.apartment_rounded, color: Colors.white),
                          )
                        : const Icon(Icons.apartment_rounded, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    brandName.trim().isEmpty ? 'Client office' : brandName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            headline.trim().isEmpty
                ? 'Your account is configured for active service operations.'
                : headline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'This office-facing layer gives clients a stronger sense of identity, continuity, and control inside their workspace.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                ),
          ),
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

class _ClientLoadState {
  const _ClientLoadState({required this.view, this.errorMessage});

  final _ClientViewData view;
  final String? errorMessage;
}

class _ClientViewData {
  const _ClientViewData({
    required this.title,
    required this.subtitle,
    this.notice,
    this.subscription,
    this.stats = const [],
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
  final List<_ClientStat> stats;
  final String primaryTitle;
  final List<_ClientRow> primaryRows;
  final String primaryEmpty;
  final String? secondaryTitle;
  final List<_ClientRow> secondaryRows;
  final String secondaryEmpty;

  factory _ClientViewData.empty(ClientSection section) => _ClientViewData(
        title: section.name[0].toUpperCase() + section.name.substring(1),
        subtitle: '',
        primaryTitle: 'Overview',
      );
}

class _ClientStat {
  const _ClientStat(this.label, this.value, {this.tone});

  final String label;
  final String value;
  final Color? tone;
}

class _ClientRow {
  const _ClientRow({required this.title, required this.primary, required this.secondary});

  final String title;
  final String primary;
  final String secondary;
}

class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({
    required this.subscription,
    required this.onManageBilling,
  });

  final Map<String, dynamic> subscription;
  final VoidCallback onManageBilling;

  @override
  Widget build(BuildContext context) {
    final plan = _read(subscription, 'plan', fallback: 'Subscription');
    final status = _read(subscription, 'status', fallback: '—');
    final amount = _subscriptionAmount(subscription);
    final nextBillingDate = _subscriptionDate(subscription['currentPeriodEnd']);

    return _TintedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Subscription', style: Theme.of(context).textTheme.titleLarge),
              ),
              TextButton(
                onPressed: onManageBilling,
                child: const Text('Manage Billing'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final items = [
                _SubscriptionMetric(label: 'Current plan', value: plan),
                _SubscriptionMetric(label: 'Status', value: status),
                _SubscriptionMetric(label: 'Amount', value: amount),
                _SubscriptionMetric(label: 'Next billing date', value: nextBillingDate),
              ];

              if (compact) {
                return Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      items[index],
                      if (index != items.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, thickness: 1, color: AppTheme.publicLine),
                        ),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    Expanded(child: items[index]),
                    if (index != items.length - 1)
                      Container(
                        width: 1,
                        height: 64,
                        color: AppTheme.publicLine,
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SubscriptionMetric extends StatelessWidget {
  const _SubscriptionMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatsBand extends StatelessWidget {
  const _StatsBand({required this.stats});

  final List<_ClientStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          if (compact) {
            return Column(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  _StatsBandItem(stat: stats[i]),
                  if (i != stats.length - 1)
                    const Divider(height: 1, thickness: 1, color: AppTheme.publicLine),
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                Expanded(child: _StatsBandItem(stat: stats[i])),
                if (i != stats.length - 1)
                  Container(
                    width: 1,
                    height: 76,
                    color: AppTheme.publicLine,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatsBandItem extends StatelessWidget {
  const _StatsBandItem({required this.stat});

  final _ClientStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            stat.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: stat.tone ?? AppTheme.publicText,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
          ),
        ],
      ),
    );
  }
}

class _PanelLayout extends StatelessWidget {
  const _PanelLayout({
    required this.primaryTitle,
    required this.primaryRows,
    required this.primaryEmpty,
    this.secondaryTitle,
    this.secondaryRows = const [],
    this.secondaryEmpty = 'Nothing is available.',
  });

  final String primaryTitle;
  final List<_ClientRow> primaryRows;
  final String primaryEmpty;
  final String? secondaryTitle;
  final List<_ClientRow> secondaryRows;
  final String secondaryEmpty;

  @override
  Widget build(BuildContext context) {
    if (secondaryTitle == null) {
      return _Panel(
        title: primaryTitle,
        rows: primaryRows,
        emptyLabel: primaryEmpty,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              _Panel(
                title: primaryTitle,
                rows: primaryRows,
                emptyLabel: primaryEmpty,
              ),
              const SizedBox(height: 18),
              _Panel(
                title: secondaryTitle!,
                rows: secondaryRows,
                emptyLabel: secondaryEmpty,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _Panel(
                title: primaryTitle,
                rows: primaryRows,
                emptyLabel: primaryEmpty,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: _Panel(
                title: secondaryTitle!,
                rows: secondaryRows,
                emptyLabel: secondaryEmpty,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.rows, required this.emptyLabel});

  final String title;
  final List<_ClientRow> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return _TintedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
            )
          else
            Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _PanelRow(row: rows[index]),
                  if (index != rows.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Divider(height: 1, thickness: 1, color: AppTheme.publicLine),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({required this.row});

  final _ClientRow row;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(row.primary, style: Theme.of(context).textTheme.bodyLarge),
              if (row.secondary.isNotEmpty) ...[
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                row.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Text(
                row.primary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Text(
                row.secondary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.publicMuted,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({required this.message, required this.isPositive});

  final String message;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFF6FAF6) : const Color(0xFFF9FAF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPositive ? const Color(0xFFDCE8DD) : const Color(0xFFE3E6E2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: isPositive ? AppTheme.emerald : AppTheme.publicMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.publicText,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TintedPanel extends StatelessWidget {
  const _TintedPanel({required this.child, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: child,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _TintedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Client workspace',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 10),
          Text('This page could not load.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) => value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

String _num(dynamic value) => ((value as num?) ?? 0).toString();

String _money(dynamic cents) {
  final amount = ((cents as num?) ?? 0) / 100;
  return '\$${amount.toStringAsFixed(2)}';
}

String _read(dynamic source, String key, {String fallback = ''}) {
  if (source is Map && source[key] != null) return '${source[key]}';
  return fallback;
}

int _countBy(List<dynamic> items, bool Function(Map<String, dynamic>) test) {
  var count = 0;
  for (final item in items) {
    final map = _asMap(item);
    if (test(map)) count += 1;
  }
  return count;
}

String _subscriptionAmount(Map<String, dynamic> subscription) {
  final amount = subscription['amount'];
  final currency = _read(subscription, 'currency', fallback: 'USD').toUpperCase();

  if (amount is num) {
    final symbol = currency == 'USD' ? '\$' : '$currency ';
    return '$symbol${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
  }

  return '—';
}

String _subscriptionDate(dynamic raw) {
  if (raw == null) return '—';
  final value = DateTime.tryParse('$raw');
  if (value == null) return '$raw';

  const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  return '${monthNames[value.month - 1]} ${value.day}, ${value.year}';
}

_ClientRow _invoiceRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'invoiceNumber', fallback: 'Invoice'),
    primary: [_read(item, 'status'), _money(item['totalCents'])].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'dueAt'),
  );
}

_ClientRow _agreementRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'title', fallback: _read(item, 'agreementNumber', fallback: 'Agreement')),
    primary: [_read(item, 'status'), _read(item, 'agreementNumber')].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'effectiveStartAt'), _read(item, 'effectiveEndAt')].where((e) => e.isNotEmpty).join(' → '),
  );
}

_ClientRow _statementRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'statementNumber', fallback: 'Statement'),
    primary: [_read(item, 'status'), _money(item['balanceCents'])].where((e) => e.isNotEmpty).join(' · '),
    secondary: [_read(item, 'periodStart'), _read(item, 'periodEnd')].where((e) => e.isNotEmpty).join(' → '),
  );
}

_ClientRow _reminderRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'subjectLine', fallback: 'Request'),
    primary: [_read(item, 'status'), _read(item, 'scheduledAt')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bodyText'),
  );
}

_ClientRow _notificationRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'title', fallback: 'Notification'),
    primary: [_read(item, 'severity'), _read(item, 'status')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'bodyText'),
  );
}

_ClientRow _dispatchRow(dynamic raw) {
  final item = _asMap(raw);
  return _ClientRow(
    title: _read(item, 'subjectLine', fallback: 'Email'),
    primary: [_read(item, 'status'), _read(item, 'recipientEmail')].where((e) => e.isNotEmpty).join(' · '),
    secondary: _read(item, 'createdAt'),
  );
}

String _humanizeError(Object error) {
  final raw = '$error';
  if (raw.contains('401') || raw.contains('Unauthorized')) {
    return 'This portal could not load because account access is not active for the current session.';
  }
  return 'This account surface could not load right now.';
}
