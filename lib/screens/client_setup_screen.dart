import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/setup/global_setup_options.dart';

class ClientSetupScreen extends StatefulWidget {
  const ClientSetupScreen({super.key});

  @override
  State<ClientSetupScreen> createState() => _ClientSetupScreenState();
}

class _ClientSetupScreenState extends State<ClientSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locality = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _countryCode;
  String? _regionCode;
  String? _industryCode;
  String? _planCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uri = GoRouterState.of(context).uri;
      final queryPlan = uri.queryParameters['plan']?.trim().toLowerCase();
      final setup = await AuthRepository().fetchClientSetup();
      final setupData = Map<String, dynamic>.from((setup['setup'] as Map?) ?? const {});

      if (!mounted) return;
      setState(() {
        _countryCode = setupData['countryCode']?.toString();
        _regionCode = setupData['regionCode']?.toString();
        _industryCode = setupData['industryCode']?.toString();
        _planCode = (queryPlan ??
                setupData['selectedPlan']?.toString() ??
                AuthSessionController.instance.selectedPlan)
            ?.toLowerCase();
        _locality.text = setupData['localityName']?.toString() ?? '';
        _loading = false;
      });

      if (_planCode != null && _planCode!.isNotEmpty) {
        await AuthSessionController.instance.rememberSelectedPlan(_planCode);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The client setup profile could not load right now.';
      });
    }
  }

  List<DropdownMenuItem<String>> _countryItems() {
    return GlobalSetupOptions.countries
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.code,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false);
  }

  List<DropdownMenuItem<String>> _regionItems() {
    return GlobalSetupOptions.regionsForCountry(_countryCode)
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.code,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false);
  }

  List<DropdownMenuItem<String>> _industryItems() {
    return GlobalSetupOptions.industries
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.code,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false);
  }

  List<DropdownMenuItem<String>> _planItems() {
    return GlobalSetupOptions.plans
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.code,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final country = GlobalSetupOptions.countryByCode(_countryCode);
    final region = GlobalSetupOptions.regionsForCountry(_countryCode)
        .where((item) => item.code == _regionCode)
        .cast<GeoRegionOption?>()
        .firstOrNull;
    final industry = GlobalSetupOptions.industryByCode(_industryCode);
    final plan = GlobalSetupOptions.planByCode(_planCode);

    if (country == null || region == null || industry == null || plan == null) {
      setState(() => _error = 'Complete every required operating field to continue.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final response = await AuthRepository().saveClientSetup(
        countryCode: country.code,
        countryName: country.label,
        regionType: GlobalSetupOptions.regionLabelForCountry(country.code),
        regionCode: region.code,
        regionName: region.label,
        localityName: _locality.text.trim().isEmpty ? null : _locality.text.trim(),
        industryCode: industry.code,
        industryLabel: industry.label,
        selectedPlan: plan.code,
      );

      await AuthSessionController.instance.applyClientSetupResponse(response);
      await AuthSessionController.instance.rememberSelectedPlan(plan.code);

      if (!mounted) return;
      final nextRoute = response['nextRoute']?.toString() ?? '/client/subscribe?plan=${plan.code}';
      context.go(nextRoute);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The operating profile could not be saved right now.';
        _saving = false;
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionLabel = GlobalSetupOptions.regionLabelForCountry(_countryCode);
    final scopePreview = GlobalSetupOptions.planScopes[_planCode ?? ''] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(color: AppTheme.publicLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _loading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ))
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Set your operating profile',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This profile drives how Orchestrate defines your geography, market, and service lane before activation.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.publicMuted,
                                      height: 1.45,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              if (_error != null) _SetupBanner(message: _error!, error: true),
                              _SectionTitle(label: 'Service plan'),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: _planCode,
                                items: _planItems(),
                                decoration: const InputDecoration(
                                  labelText: 'Plan',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _planCode = value;
                                        });
                                      },
                                validator: (value) =>
                                    value == null || value.isEmpty ? 'Plan is required.' : null,
                              ),
                              if (scopePreview.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: scopePreview
                                      .map((item) => Chip(label: Text(_humanizeScope(item))))
                                      .toList(growable: false),
                                ),
                              ],
                              const SizedBox(height: 24),
                              _SectionTitle(label: 'Market geography'),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: _countryCode,
                                items: _countryItems(),
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Country',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _countryCode = value;
                                          _regionCode = null;
                                        });
                                      },
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Country is required.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _regionCode,
                                items: _regionItems(),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: regionLabel,
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _regionCode = value;
                                        });
                                      },
                                validator: (value) => value == null || value.isEmpty
                                    ? '$regionLabel is required.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _locality,
                                decoration: const InputDecoration(
                                  labelText: 'Locality, city, metro, or service zone',
                                  border: OutlineInputBorder(),
                                  hintText: 'Optional but useful for precise targeting',
                                ),
                              ),
                              const SizedBox(height: 24),
                              _SectionTitle(label: 'Industry context'),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: _industryCode,
                                items: _industryItems(),
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Industry',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _industryCode = value;
                                        });
                                      },
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Industry is required.'
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8F5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.publicLine),
                                ),
                                child: Text(
                                  'These selections become the client operating profile for geography, targeting, service lane, and future AI execution.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.publicMuted,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _saving ? null : _submit,
                                  child: Text(_saving ? 'Saving profile...' : 'Save and continue'),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _humanizeScope(String key) {
    switch (key) {
      case 'lead_generation':
        return 'Lead generation';
      case 'follow_up':
        return 'Follow-up';
      case 'meeting_booking':
        return 'Meeting booking';
      case 'billing_collections':
        return 'Billing collections';
      default:
        return key.replaceAll('_', ' ');
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error ? Colors.red.shade100 : Colors.green.shade100,
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
