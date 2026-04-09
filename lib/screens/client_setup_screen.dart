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
  final _locality = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _planCode;
  String? _countryCode;
  String? _regionCode;
  String? _industryCode;
  String? _trial;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uri = GoRouterState.of(context).uri;
    final session = AuthSessionController.instance;

    _planCode = uri.queryParameters['plan']?.trim().toLowerCase() ?? session.selectedPlan ?? 'opportunity';
    _trial = uri.queryParameters['trial']?.trim().toLowerCase();

    try {
      final response = await AuthRepository().fetchClientSetup();
      final setup = _asMap(response['setup']);
      final client = _asMap(response['client']);

      if (!mounted) return;
      setState(() {
        _countryCode = _read(setup, 'countryCode');
        _regionCode = _read(setup, 'regionCode');
        _industryCode = _read(setup, 'industryCode');
        _planCode = _read(client, 'selectedPlan', fallback: _planCode ?? 'opportunity').toLowerCase();
        _locality.text = _read(setup, 'localityName');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _countryCode ??= 'US';
      });
    }
  }

  Future<void> _save() async {
    final country = GlobalSetupOptions.countryByCode(_countryCode);
    GeoRegionOption? region;
    for (final item in GlobalSetupOptions.regionsForCountry(_countryCode)) {
      if (item.code == _regionCode) {
        region = item;
        break;
      }
    }
    final industry = GlobalSetupOptions.industryByCode(_industryCode);
    final plan = GlobalSetupOptions.planByCode(_planCode);

    if (country == null || region == null || industry == null || plan == null) {
      setState(() => _error = 'Complete country, region, industry, and plan before continuing.');
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
      context.go(
        Uri(
          path: '/client/subscribe',
          queryParameters: {
            'plan': plan.code,
            'tier': AuthSessionController.instance.selectedTier ?? 'focused',
            if (_trial == '15d') 'trial': '15d',
          },
        ).toString(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'We could not save your setup right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = GlobalSetupOptions.regionsForCountry(_countryCode);

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 940;
                        final intro = _SetupIntro(planCode: _planCode ?? 'opportunity', trial: _trial);
                        final form = Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32), side: const BorderSide(color: AppTheme.publicLine)),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Define your operating profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Text('This sets the market, region, and industry context your workspace will use from the start.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
                              const SizedBox(height: 20),
                              if (_error != null) _SetupBanner(message: _error!, error: true),
                              DropdownButtonFormField<String>(
                                value: _planCode,
                                items: GlobalSetupOptions.plans.map((plan) => DropdownMenuItem(value: plan.code, child: Text(plan.label))).toList(),
                                onChanged: (value) => setState(() => _planCode = value),
                                decoration: const InputDecoration(labelText: 'Service lane'),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _countryCode,
                                items: GlobalSetupOptions.countries.map((country) => DropdownMenuItem(value: country.code, child: Text(country.label))).toList(),
                                onChanged: (value) => setState(() {
                                  _countryCode = value;
                                  _regionCode = null;
                                }),
                                decoration: const InputDecoration(labelText: 'Country'),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: regions.any((region) => region.code == _regionCode) ? _regionCode : null,
                                items: regions.map((region) => DropdownMenuItem(value: region.code, child: Text(region.label))).toList(),
                                onChanged: (value) => setState(() => _regionCode = value),
                                decoration: InputDecoration(labelText: GlobalSetupOptions.regionLabelForCountry(_countryCode)),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _locality,
                                decoration: const InputDecoration(labelText: 'City or metro focus', hintText: 'Optional'),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _industryCode,
                                items: GlobalSetupOptions.industries.map((industry) => DropdownMenuItem(value: industry.code, child: Text(industry.label))).toList(),
                                onChanged: (value) => setState(() => _industryCode = value),
                                decoration: const InputDecoration(labelText: 'Industry'),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(width: double.infinity, child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save and continue'))),
                            ]),
                          ),
                        );

                        if (stacked) {
                          return Column(children: [intro, const SizedBox(height: 18), form]);
                        }
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: intro), const SizedBox(width: 18), Expanded(flex: 4, child: form)]);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupIntro extends StatelessWidget {
  const _SetupIntro({required this.planCode, required this.trial});
  final String planCode;
  final String? trial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Set up before billing begins', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('Confirm your service lane, market, and industry before moving into billing.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Pill(label: 'Lane: ${_title(planCode)}'),
          if (trial == '15d') const _Pill(label: '15-day start period selected'),
        ]),
        const SizedBox(height: 22),
        const _SetupPoint(title: 'Country and region', body: 'This defines the market you want to start in.'),
        const SizedBox(height: 12),
        const _SetupPoint(title: 'Industry context', body: 'This keeps outreach and service direction grounded in the right commercial context.'),
        const SizedBox(height: 12),
        const _SetupPoint(title: 'Locality focus', body: 'Optional city or metro detail helps you begin with a tighter local focus.'),
      ]),
    );
  }
}

class _SetupPoint extends StatelessWidget {
  const _SetupPoint({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(body, style: Theme.of(context).textTheme.bodyMedium),
    ]);
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
        border: Border.all(color: error ? Colors.red.shade100 : Colors.green.shade100),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.publicSurfaceSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.publicLine)),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : const {};
String _read(Map<String, dynamic> value, String key, {String fallback = ''}) => value[key]?.toString() ?? fallback;
String _title(String text) => text.split(RegExp(r'[-_]')).where((part) => part.isNotEmpty).map((word) => '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
