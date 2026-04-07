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

  int _currentStep = 0;

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
        _error = 'Your setup could not load right now.';
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

  SetupOption? _planByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final item in GlobalSetupOptions.plans) {
      if (item.code == code) return item;
    }
    return null;
  }

  SetupOption? _countryByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final item in GlobalSetupOptions.countries) {
      if (item.code == code) return item;
    }
    return null;
  }

  SetupOption? _industryByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final item in GlobalSetupOptions.industries) {
      if (item.code == code) return item;
    }
    return null;
  }

  GeoRegionOption? _regionByCode(String? countryCode, String? regionCode) {
    if (countryCode == null || countryCode.isEmpty || regionCode == null || regionCode.isEmpty) {
      return null;
    }
    for (final item in GlobalSetupOptions.regionsForCountry(countryCode)) {
      if (item.code == regionCode) return item;
    }
    return null;
  }

  String _marketStepTitle() {
    return 'Where do you want us to work first?';
  }

  String _scopeStepTitle() {
    return 'How broad should we go within this market?';
  }

  String _controlStepTitle() {
    return 'How much control do you want over the market?';
  }

  String _planLabel() {
    final plan = _planByCode(_planCode);
    return plan?.label ?? 'your service';
  }

  Future<void> _nextStep() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (_currentStep == 0) {
      if (_countryCode == null || _countryCode!.isEmpty) {
        setState(() => _error = 'Choose the country where you want us to begin.');
        return;
      }
      setState(() => _currentStep = 1);
      return;
    }

    if (_currentStep == 1) {
      if (_regionCode == null || _regionCode!.isEmpty) {
        final regionLabel = GlobalSetupOptions.regionLabelForCountry(_countryCode);
        setState(() => _error = 'Choose the $regionLabel you want us to prioritize first.');
        return;
      }
      if (_industryCode == null || _industryCode!.isEmpty) {
        setState(() => _error = 'Choose the market you want us to represent.');
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    await _submit();
  }

  void _backStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      if (_currentStep > 0) {
        _currentStep -= 1;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final country = _countryByCode(_countryCode);
    final region = _regionByCode(_countryCode, _regionCode);
    final industry = _industryByCode(_industryCode);
    final plan = _planByCode(_planCode);

    if (country == null || region == null || industry == null || plan == null) {
      setState(() {
        _error = 'Complete your market setup before continuing.';
      });
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
        _saving = false;
        _error = 'We could not save your setup right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
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
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 56),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set up your market direction',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'We will use this to shape where Orchestrate starts working for you and how tightly that coverage is defined.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.publicMuted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _SetupProgressIndicator(currentStep: _currentStep),
                              const SizedBox(height: 24),
                              if (_error != null) ...[
                                _SetupBanner(message: _error!, error: true),
                                const SizedBox(height: 18),
                              ],
                              _SetupSummary(
                                currentStep: _currentStep,
                                countryLabel: _countryByCode(_countryCode)?.label,
                                regionLabel: _regionByCode(_countryCode, _regionCode)?.label,
                                regionType: GlobalSetupOptions.regionLabelForCountry(_countryCode),
                                industryLabel: _industryByCode(_industryCode)?.label,
                                planLabel: _planByCode(_planCode)?.label,
                              ),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: KeyedSubtree(
                                  key: ValueKey<int>(_currentStep),
                                  child: _buildStepBody(context),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: _saving || _currentStep == 0 ? null : _backStep,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.publicMuted,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Back'),
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: _saving ? null : _nextStep,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.publicText,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(_currentStep == 2 ? 'Continue' : 'Next'),
                                  ),
                                ],
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

  Widget _buildStepBody(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildMarketStep(context);
      case 1:
        return _buildScopeStep(context);
      case 2:
      default:
        return _buildControlStep(context);
    }
  }

  Widget _buildMarketStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          eyebrow: 'Market',
          title: _marketStepTitle(),
          description:
              'Start with the country that matters most right now. You can expand later without rebuilding your setup.',
        ),
        const SizedBox(height: 22),
        DropdownButtonFormField<String>(
          value: _countryCode,
          items: _countryItems(),
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
          validator: (value) =>
              value == null || value.isEmpty ? 'Choose a country.' : null,
        ),
        const SizedBox(height: 20),
        _FutureSurface(
          title: 'Multi-market coverage',
          message:
              'When you are ready to work across countries, you can expand your coverage without changing the way the workspace operates.',
          badge: 'Expand later',
        ),
      ],
    );
  }

  Widget _buildScopeStep(BuildContext context) {
    final regionLabel = GlobalSetupOptions.regionLabelForCountry(_countryCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          eyebrow: 'Scope',
          title: _scopeStepTitle(),
          description:
              'Choose the part of the country where you want the first push to begin, then tell us what kind of market you want us to represent.',
        ),
        const SizedBox(height: 22),
        DropdownButtonFormField<String>(
          value: _regionCode,
          items: _regionItems(),
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
          validator: (value) =>
              value == null || value.isEmpty ? 'Choose a $regionLabel.' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _industryCode,
          items: _industryItems(),
          decoration: const InputDecoration(
            labelText: 'Market',
            border: OutlineInputBorder(),
          ),
          onChanged: _saving
              ? null
              : (value) {
                  setState(() {
                    _industryCode = value;
                  });
                },
          validator: (value) =>
              value == null || value.isEmpty ? 'Choose a market.' : null,
        ),
        const SizedBox(height: 20),
        _ScopeHintCard(
          regionType: regionLabel,
          countryLabel: _countryByCode(_countryCode)?.label,
          planLabel: _planLabel(),
        ),
      ],
    );
  }

  Widget _buildControlStep(BuildContext context) {
    final country = _countryByCode(_countryCode)?.label ?? 'your selected country';
    final regionType = GlobalSetupOptions.regionLabelForCountry(_countryCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          eyebrow: 'Control',
          title: _controlStepTitle(),
          description:
              'You can begin at the market level now and tighten control later with city targeting, exclusions, and priority order when you need it.',
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _locality,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'City or metro area',
            hintText: 'Optional for your first launch',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _FutureSurface(
                title: 'Exclude specific areas',
                message: 'Keep certain cities or metros out of the active coverage when you need tighter boundaries.',
                badge: 'Precision coverage',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FutureSurface(
                title: 'Set market priority',
                message: 'Order your markets so the system knows where to spend effort first as your coverage expands.',
                badge: 'Precision coverage',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ReviewCard(
          country: country,
          regionLabel: _regionByCode(_countryCode, _regionCode)?.label,
          regionType: regionType,
          market: _industryByCode(_industryCode)?.label,
          plan: _planByCode(_planCode)?.label,
          locality: _locality.text.trim(),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppTheme.publicMuted,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.publicMuted,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SetupProgressIndicator extends StatelessWidget {
  const _SetupProgressIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress,
            backgroundColor: AppTheme.publicSurfaceSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.publicText),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: _ProgressLabel(label: 'Market')),
            SizedBox(width: 12),
            Expanded(child: _ProgressLabel(label: 'Scope')),
            SizedBox(width: 12),
            Expanded(child: _ProgressLabel(label: 'Control')),
          ],
        ),
      ],
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.publicMuted,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _SetupSummary extends StatelessWidget {
  const _SetupSummary({
    required this.currentStep,
    required this.countryLabel,
    required this.regionLabel,
    required this.regionType,
    required this.industryLabel,
    required this.planLabel,
  });

  final int currentStep;
  final String? countryLabel;
  final String? regionLabel;
  final String regionType;
  final String? industryLabel;
  final String? planLabel;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (planLabel != null && planLabel!.trim().isNotEmpty) {
      chips.add(_SummaryChip(label: planLabel!));
    }
    if (countryLabel != null && countryLabel!.trim().isNotEmpty) {
      chips.add(_SummaryChip(label: countryLabel!));
    }
    if (regionLabel != null && regionLabel!.trim().isNotEmpty) {
      chips.add(_SummaryChip(label: '$regionType: $regionLabel'));
    }
    if (industryLabel != null && industryLabel!.trim().isNotEmpty) {
      chips.add(_SummaryChip(label: industryLabel!));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _FutureSurface extends StatelessWidget {
  const _FutureSurface({
    required this.title,
    required this.message,
    required this.badge,
  });

  final String title;
  final String message;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.publicLine),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.publicMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.publicMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeHintCard extends StatelessWidget {
  const _ScopeHintCard({
    required this.regionType,
    required this.countryLabel,
    required this.planLabel,
  });

  final String regionType;
  final String? countryLabel;
  final String planLabel;

  @override
  Widget build(BuildContext context) {
    final country = countryLabel ?? 'this country';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(
        'Orchestrate will begin in $country, with your first $regionType shaping the initial coverage for $planLabel.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.publicMuted,
              height: 1.45,
            ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.country,
    required this.regionLabel,
    required this.regionType,
    required this.market,
    required this.plan,
    required this.locality,
  });

  final String country;
  final String? regionLabel;
  final String regionType;
  final String? market;
  final String? plan;
  final String locality;

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, String>>[
      MapEntry('Service', plan ?? 'Not selected'),
      MapEntry('Country', country),
      MapEntry(regionType, regionLabel ?? 'Not selected'),
      MapEntry('Market', market ?? 'Not selected'),
    ];

    if (locality.trim().isNotEmpty) {
      items.add(MapEntry('City or metro', locality.trim()));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to launch',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      item.key,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.publicMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFF1F1) : const Color(0xFFF5FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error ? const Color(0xFFF2B8B5) : const Color(0xFFD6E4FF),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: error ? const Color(0xFF8C2F2B) : const Color(0xFF21406D),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
