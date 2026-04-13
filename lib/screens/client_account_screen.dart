import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/client_portal_repository.dart';

class ClientAccountScreen extends StatefulWidget {
  const ClientAccountScreen({super.key});

  @override
  State<ClientAccountScreen> createState() => _ClientAccountScreenState();
}

class _ClientAccountScreenState extends State<ClientAccountScreen> {
  final _repo = ClientPortalRepository();
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _bookingUrlController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _currencyController = TextEditingController();
  final _headlineController = TextEditingController();
  final _deactivationReasonController = TextEditingController();
  final _deactivationConfirmController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _openingPortal = false;
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
    _websiteUrlController.dispose();
    _bookingUrlController.dispose();
    _timezoneController.dispose();
    _currencyController.dispose();
    _headlineController.dispose();
    _deactivationReasonController.dispose();
    _deactivationConfirmController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _repo.fetchClientProfile(),
        _repo.fetchSubscription(),
      ]);

      final profile = Map<String, dynamic>.from(results[0] as Map);
      final subscription = results[1] == null
          ? null
          : Map<String, dynamic>.from(results[1] as Map);

      _profile = profile;
      _subscription = subscription;
      _applyProfile(profile);

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Account details could not load right now.';
        });
      }
    }
  }

  void _applyProfile(Map<String, dynamic> profile) {
    final client = _asMap(profile['client']);
    _displayNameController.text = _read(client, 'displayName');
    _legalNameController.text = _read(client, 'legalName');
    _brandNameController.text = _read(client, 'brandName');
    _websiteUrlController.text = _read(client, 'websiteUrl');
    _bookingUrlController.text = _read(client, 'bookingUrl');
    _timezoneController.text = _read(client, 'primaryTimezone', fallback: 'America/Detroit');
    _currencyController.text = _read(client, 'currencyCode', fallback: 'USD');
    _headlineController.text = _read(client, 'welcomeHeadline');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final updated = await _repo.updateClientProfile(
        displayName: _displayNameController.text.trim(),
        legalName: _legalNameController.text.trim(),
        brandName: _brandNameController.text.trim(),
        websiteUrl: _websiteUrlController.text.trim(),
        bookingUrl: _bookingUrlController.text.trim(),
        primaryTimezone: _timezoneController.text.trim(),
        currencyCode: _currencyController.text.trim(),
        welcomeHeadline: _headlineController.text.trim(),
      );

      _profile = updated;
      _applyProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account details updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account details could not be updated.')),
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

  Future<void> _openBillingPortal() async {
    setState(() {
      _openingPortal = true;
    });

    try {
      final url = await _repo.createBillingPortalSession();
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Billing portal could not be opened.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingPortal = false;
        });
      }
    }
  }

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate account'),
          content: const Text(
            'This requests account deactivation. Billing and record visibility should be reviewed before continuing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deactivating = true;
    });

    try {
      await _repo.deactivateClientAccount(
        reason: _deactivationReasonController.text.trim(),
        confirmationText: _deactivationConfirmController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deactivation request submitted.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deactivation request could not be submitted.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deactivating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final session = AuthSessionController.instance;
    final client = _asMap(_profile['client']);
    final subscription = _asMap(_subscription);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(
            eyebrow: 'Account',
            title: _displayIdentity(client, session),
            subtitle:
                'Profile, business links, billing access, and account controls belong together here instead of staying buried inside workspace.',
          ),
          const SizedBox(height: 18),
          _MetricStrip(
            metrics: [
              _MetricData(label: 'State', value: _accountState(session)),
              _MetricData(
                label: 'Plan',
                value: _title(_read(subscription, 'planName', fallback: session.selectedPlan ?? 'Not set')),
              ),
              _MetricData(
                label: 'Billing',
                value: _title(_read(subscription, 'status', fallback: session.subscriptionStatus)),
              ),
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
              final left = _FormPanel(
                formKey: _formKey,
                displayNameController: _displayNameController,
                legalNameController: _legalNameController,
                brandNameController: _brandNameController,
                websiteUrlController: _websiteUrlController,
                bookingUrlController: _bookingUrlController,
                timezoneController: _timezoneController,
                currencyController: _currencyController,
                headlineController: _headlineController,
                saving: _saving,
                onSave: _save,
              );
              final right = _ControlPanel(
                session: session,
                client: client,
                subscription: subscription,
                openingPortal: _openingPortal,
                onOpenPortal: _openBillingPortal,
                deactivationReasonController: _deactivationReasonController,
                deactivationConfirmController: _deactivationConfirmController,
                deactivating: _deactivating,
                onDeactivate: _confirmDeactivate,
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
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

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
      ),
    );
  }
}

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
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
          Text(
            metric.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.publicMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.formKey,
    required this.displayNameController,
    required this.legalNameController,
    required this.brandNameController,
    required this.websiteUrlController,
    required this.bookingUrlController,
    required this.timezoneController,
    required this.currencyController,
    required this.headlineController,
    required this.saving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final TextEditingController legalNameController;
  final TextEditingController brandNameController;
  final TextEditingController websiteUrlController;
  final TextEditingController bookingUrlController;
  final TextEditingController timezoneController;
  final TextEditingController currencyController;
  final TextEditingController headlineController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Keep the client-facing identity, links, and default operating details current here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 22),
            _LabeledField(
              label: 'Display name',
              controller: displayNameController,
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Display name is required.' : null,
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Legal name',
              controller: legalNameController,
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Legal name is required.' : null,
            ),
            const SizedBox(height: 14),
            _LabeledField(label: 'Brand name', controller: brandNameController),
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Website',
              controller: websiteUrlController,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Booking link',
              controller: bookingUrlController,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(label: 'Timezone', controller: timezoneController),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _LabeledField(
                    label: 'Currency',
                    controller: currencyController,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Welcome headline',
              controller: headlineController,
              maxLines: 2,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: saving ? null : onSave,
              child: Text(saving ? 'Saving...' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.session,
    required this.client,
    required this.subscription,
    required this.openingPortal,
    required this.onOpenPortal,
    required this.deactivationReasonController,
    required this.deactivationConfirmController,
    required this.deactivating,
    required this.onDeactivate,
  });

  final AuthSessionController session;
  final Map<String, dynamic> client;
  final Map<String, dynamic> subscription;
  final bool openingPortal;
  final VoidCallback onOpenPortal;
  final TextEditingController deactivationReasonController;
  final TextEditingController deactivationConfirmController;
  final bool deactivating;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
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
              Text('Account standing', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _InfoRow(label: 'Email', value: session.email.isNotEmpty ? session.email : 'Client account'),
              _InfoRow(label: 'Verification', value: session.emailVerified ? 'Verified' : 'Pending'),
              _InfoRow(label: 'Scope', value: session.hasSetupCompleted ? 'Setup completed' : 'Setup still in draft'),
              _InfoRow(
                label: 'Subscription',
                value: _title(_read(subscription, 'status', fallback: session.subscriptionStatus)),
              ),
              _InfoRow(
                label: 'Current period',
                value: _read(subscription, 'currentPeriodEnd', fallback: 'Not available'),
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: openingPortal ? null : onOpenPortal,
                child: Text(openingPortal ? 'Opening billing...' : 'Open billing portal'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
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
              Text('Public links and status', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _InfoRow(label: 'Website', value: _read(client, 'websiteUrl', fallback: 'Not set')),
              _InfoRow(label: 'Booking', value: _read(client, 'bookingUrl', fallback: 'Not set')),
              _InfoRow(label: 'Timezone', value: _read(client, 'primaryTimezone', fallback: 'America/Detroit')),
              _InfoRow(label: 'Currency', value: _read(client, 'currencyCode', fallback: 'USD')),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
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
              Text('Deactivate account', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                'Use this only when the account should be taken out of service. Billing and records should be reviewed first.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
              ),
              const SizedBox(height: 18),
              _LabeledField(
                label: 'Reason',
                controller: deactivationReasonController,
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Confirmation note',
                controller: deactivationConfirmController,
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: deactivating ? null : onDeactivate,
                style: FilledButton.styleFrom(backgroundColor: Colors.black),
                child: Text(deactivating ? 'Submitting...' : 'Request deactivation'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.publicSurfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.publicLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.publicLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.publicText),
            ),
          ),
        ),
      ],
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _read(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _title(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed
      .split(RegExp(r'[\s_\-]+'))
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

String _accountState(AuthSessionController session) {
  if (!session.emailVerified) return 'Verification pending';
  if (!session.hasSetupCompleted) return 'Draft';
  if (session.normalizedSubscriptionStatus == 'active') return 'Active';
  return 'Review';
}

String _displayIdentity(Map<String, dynamic> client, AuthSessionController session) {
  final choices = <String>[
    _read(client, 'displayName'),
    _read(client, 'brandName'),
    session.workspaceName.trim(),
    session.fullName.trim(),
  ];

  for (final value in choices) {
    if (value.isNotEmpty) return value;
  }

  return 'Client account';
}
