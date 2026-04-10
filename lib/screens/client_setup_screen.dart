
import 'dart:convert';

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
  final TextEditingController _metroInput = TextEditingController();
  final TextEditingController _marketNotes = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _trial;

  String _planCode = 'opportunity';
  String _tierCode = 'focused';
  final Set<String> _countryCodes = <String>{};
  final Set<String> _regionCodes = <String>{};
  final List<String> _metroNames = <String>[];
  String? _industryCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _metroInput.dispose();
    _marketNotes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uri = GoRouterState.of(context).uri;
    final session = AuthSessionController.instance;
    final draft = session.setupDraft;

    _planCode = _normalizedLane(uri.queryParameters['plan']) ??
        _normalizedLane(session.selectedPlan) ??
        _normalizedLane(draft?['serviceType']) ??
        'opportunity';
    _tierCode = _normalizedTier(uri.queryParameters['tier']) ??
        _normalizedTier(session.selectedTier) ??
        _normalizedTier(draft?['scopeMode']) ??
        'focused';
    _trial = uri.queryParameters['trial']?.trim().toLowerCase();

    try {
      final response = await AuthRepository().fetchClientSetup();
      final setup = _asMap(response['setup']);
      final client = _asMap(response['client']);
      final sessionDraft = _asMap(draft);

      if (!mounted) return;
      setState(() {
        _planCode = _normalizedLane(
              client['selectedPlan']?.toString(),
            ) ??
            _planCode;
        _tierCode = _normalizedTier(
              client['selectedTier']?.toString(),
            ) ??
            _tierCode;
        _industryCode = _read(setup, 'industryCode') ?? sessionDraft['industryCode']?.toString();
        _marketNotes.text = sessionDraft['marketNotes']?.toString() ?? '';

        final loadedCountries = _asStringList(sessionDraft['countries']);
        final loadedRegions = _asStringList(sessionDraft['regions']);
        final loadedMetros = _asStringList(sessionDraft['metros']);

        if (loadedCountries.isNotEmpty) {
          _countryCodes
            ..clear()
            ..addAll(loadedCountries);
        } else {
          final countryCode = _read(setup, 'countryCode');
          if (countryCode != null && countryCode.isNotEmpty) {
            _countryCodes
              ..clear()
              ..add(countryCode.toUpperCase());
          }
        }

        if (loadedRegions.isNotEmpty) {
          _regionCodes
            ..clear()
            ..addAll(loadedRegions);
        } else {
          final regionCode = _read(setup, 'regionCode');
          if (regionCode != null && regionCode.isNotEmpty) {
            _regionCodes
              ..clear()
              ..add(regionCode);
          }
        }

        _metroNames
          ..clear()
          ..addAll(
            loadedMetros.isNotEmpty
                ? loadedMetros
                : _splitLocality(_read(setup, 'localityName')),
          );

        _applyTierRules();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_countryCodes.isEmpty) {
          _countryCodes.addAll(_asStringList(draft?['countries']));
        }
        if (_regionCodes.isEmpty) {
          _regionCodes.addAll(_asStringList(draft?['regions']));
        }
        if (_metroNames.isEmpty) {
          _metroNames.addAll(_asStringList(draft?['metros']));
        }
        _industryCode = _industryCode ?? draft?['industryCode']?.toString();
        _marketNotes.text = draft?['marketNotes']?.toString() ?? _marketNotes.text;
        _applyTierRules();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final primaryCountryCode = _countryCodes.first;
    final primaryCountry = GlobalSetupOptions.countryByCode(primaryCountryCode);
    final primaryRegionCode = _regionCodes.first;
    final primaryRegion = _findRegionByCode(primaryRegionCode);
    final industry = GlobalSetupOptions.industryByCode(_industryCode);

    if (primaryCountry == null || primaryRegion == null || industry == null) {
      setState(() => _error = 'Complete your market coverage before continuing.');
      return;
    }

    final draft = <String, dynamic>{
      'serviceType': _planCode,
      'scopeMode': _tierCode,
      'countries': _sortedCountryCodes(),
      'regions': _sortedRegionCodes(),
      'metros': List<String>.from(_metroNames),
      'industryCode': industry.code,
      'industryLabel': industry.label,
      'marketNotes': _marketNotes.text.trim(),
      'reviewSummary': _buildReviewSummary(),
      'lastUpdatedAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final response = await AuthRepository().saveClientSetup(
        countryCode: primaryCountry.code,
        countryName: primaryCountry.label,
        regionType: GlobalSetupOptions.regionLabelForCountry(primaryCountry.code),
        regionCode: primaryRegion.code,
        regionName: primaryRegion.label,
        localityName: _metroNames.isEmpty ? null : _metroNames.join(', '),
        industryCode: industry.code,
        industryLabel: industry.label,
        selectedPlan: _planCode,
      );

      await AuthSessionController.instance.rememberSelection(
        plan: _planCode,
        tier: _tierCode,
      );
      await AuthSessionController.instance.saveSetupDraft(draft);
      await AuthSessionController.instance.applyClientSetupResponse(response);

      if (!mounted) return;
      context.go(
        Uri(
          path: '/client/subscribe',
          queryParameters: {
            'plan': _planCode,
            'tier': _tierCode,
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

  void _applyTierRules() {
    if (_tierCode == 'focused' && _countryCodes.length > 1) {
      final first = _countryCodes.first;
      _countryCodes
        ..clear()
        ..add(first);
      _regionCodes.removeWhere((code) => !code.startsWith('$first-'));
    }

    if (_countryCodes.isNotEmpty) {
      _regionCodes.removeWhere((code) {
        final countryCode = code.split('-').first.toUpperCase();
        return !_countryCodes.contains(countryCode);
      });
    } else {
      _regionCodes.clear();
    }

    if (_tierCode != 'precision' && _metroNames.length > 12) {
      _metroNames.removeRange(12, _metroNames.length);
    }
  }

  void _updatePlan(String value) {
    setState(() {
      _planCode = _normalizedLane(value) ?? 'opportunity';
      _error = null;
    });
  }

  void _updateTier(String value) {
    setState(() {
      _tierCode = _normalizedTier(value) ?? 'focused';
      _applyTierRules();
      _error = null;
    });
  }

  void _toggleCountry(String code) {
    setState(() {
      final normalized = code.toUpperCase();
      if (_tierCode == 'focused') {
        _countryCodes
          ..clear()
          ..add(normalized);
        _regionCodes.removeWhere((regionCode) => !regionCode.startsWith('$normalized-'));
      } else if (_countryCodes.contains(normalized)) {
        _countryCodes.remove(normalized);
        _regionCodes.removeWhere((regionCode) => regionCode.startsWith('$normalized-'));
      } else {
        _countryCodes.add(normalized);
      }
      _error = null;
    });
  }

  void _toggleRegion(String code) {
    setState(() {
      if (_regionCodes.contains(code)) {
        _regionCodes.remove(code);
      } else {
        _regionCodes.add(code);
      }
      _error = null;
    });
  }

  void _addMetro([String? metro]) {
    final value = (metro ?? _metroInput.text).trim();
    if (value.isEmpty) return;
    if (_metroNames.any((item) => item.toLowerCase() == value.toLowerCase())) {
      _metroInput.clear();
      return;
    }

    setState(() {
      _metroNames.add(value);
      _metroInput.clear();
      _error = null;
    });
  }

  void _removeMetro(String metro) {
    setState(() {
      _metroNames.remove(metro);
    });
  }

  String? _validate() {
    if (_countryCodes.isEmpty) {
      return 'Choose at least one country to continue.';
    }
    if (_regionCodes.isEmpty) {
      return 'Add at least one region to continue.';
    }
    if (_industryCode == null || _industryCode!.isEmpty) {
      return 'Choose your industry before continuing.';
    }
    if (_tierCode == 'focused' && _countryCodes.length != 1) {
      return 'Focused setup covers one country at a time.';
    }
    if (_tierCode == 'multi' && _countryCodes.length < 2) {
      return 'Multi setup should include at least two countries.';
    }
    if (_tierCode == 'precision' && _metroNames.isEmpty) {
      return 'Precision setup needs at least one city or metro.';
    }
    return null;
  }

  Map<String, String> _buildReviewSummary() {
    return <String, String>{
      'serviceLine': _laneLabel(_planCode),
      'mode': _tierLabel(_tierCode),
      'countries': _selectedCountryLabels().join(', '),
      'regions': _selectedRegionLabels().join(', '),
      'metros': _metroNames.isEmpty ? 'Not added' : _metroNames.join(', '),
      'industry': GlobalSetupOptions.industryByCode(_industryCode)?.label ?? 'Not selected',
    };
  }

  List<String> _selectedCountryLabels() {
    return _sortedCountryCodes()
        .map((code) => GlobalSetupOptions.countryByCode(code)?.label ?? code)
        .toList();
  }

  List<String> _selectedRegionLabels() {
    return _sortedSelectedRegions()
        .map((region) => '${region.label} (${GlobalSetupOptions.countryByCode(region.code.split('-').first)?.label ?? region.code.split('-').first})')
        .toList();
  }

  List<String> _sortedCountryCodes() {
    final items = _countryCodes.toList();
    items.sort((a, b) {
      final aLabel = GlobalSetupOptions.countryByCode(a)?.label ?? a;
      final bLabel = GlobalSetupOptions.countryByCode(b)?.label ?? b;
      return aLabel.compareTo(bLabel);
    });
    return items;
  }

  List<String> _sortedRegionCodes() {
    final items = _regionCodes.toList();
    items.sort((a, b) {
      final aLabel = _findRegionByCode(a)?.label ?? a;
      final bLabel = _findRegionByCode(b)?.label ?? b;
      return aLabel.compareTo(bLabel);
    });
    return items;
  }

  List<GeoRegionOption> _sortedSelectedRegions() {
    final items = _regionCodes
        .map(_findRegionByCode)
        .whereType<GeoRegionOption>()
        .toList();
    items.sort((a, b) => a.label.compareTo(b.label));
    return items;
  }

  GeoRegionOption? _findRegionByCode(String code) {
    final country = code.split('-').first.toUpperCase();
    for (final region in GlobalSetupOptions.regionsForCountry(country)) {
      if (region.code == code) return region;
    }
    return null;
  }

  List<_GroupedRegion> _groupedRegions() {
    final groups = <_GroupedRegion>[];
    for (final countryCode in _sortedCountryCodes()) {
      final country = GlobalSetupOptions.countryByCode(countryCode);
      final label = country?.label ?? countryCode;
      final regions = List<GeoRegionOption>.from(GlobalSetupOptions.regionsForCountry(countryCode))
        ..sort((a, b) => a.label.compareTo(b.label));
      if (regions.isNotEmpty) {
        groups.add(_GroupedRegion(countryCode: countryCode, countryLabel: label, regions: regions));
      }
    }
    return groups;
  }

  List<String> _metroSuggestions() {
    final suggestions = <String>{};
    for (final countryCode in _sortedCountryCodes()) {
      for (final region in GlobalSetupOptions.regionsForCountry(countryCode)) {
        final type = region.type.toLowerCase();
        if (type.contains('city') ||
            type.contains('municipality') ||
            type.contains('district') ||
            type.contains('metropolitan')) {
          suggestions.add(region.label.replaceAll('[city]', '').trim());
        }
      }
    }
    final filtered = suggestions
        .where((item) => !_metroNames.any((selected) => selected.toLowerCase() == item.toLowerCase()))
        .toList()
      ..sort();
    return filtered.take(18).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.publicBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 980;
                        final intro = _SetupIntro(
                          laneLabel: _laneLabel(_planCode),
                          tierLabel: _tierLabel(_tierCode),
                          trial: _trial,
                        );
                        final builder = _BuilderCard(
                          planCode: _planCode,
                          tierCode: _tierCode,
                          selectedCountries: _selectedCountryLabels(),
                          selectedRegions: _selectedRegionLabels(),
                          selectedMetros: _metroNames,
                          industryLabel: GlobalSetupOptions.industryByCode(_industryCode)?.label,
                          marketNotes: _marketNotes,
                          error: _error,
                          saving: _saving,
                          onPlanChanged: _updatePlan,
                          onTierChanged: _updateTier,
                          onChooseCountries: () async {
                            final result = await showModalBottomSheet<Set<String>>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _CountryPickerSheet(
                                selected: _countryCodes,
                                singleSelect: _tierCode == 'focused',
                              ),
                            );
                            if (result == null || !mounted) return;
                            setState(() {
                              _countryCodes
                                ..clear()
                                ..addAll(result);
                              _applyTierRules();
                              _error = null;
                            });
                          },
                          onChooseRegions: _countryCodes.isEmpty
                              ? null
                              : () async {
                                  final result = await showModalBottomSheet<Set<String>>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => _RegionPickerSheet(
                                      groups: _groupedRegions(),
                                      selected: _regionCodes,
                                    ),
                                  );
                                  if (result == null || !mounted) return;
                                  setState(() {
                                    _regionCodes
                                      ..clear()
                                      ..addAll(result);
                                    _error = null;
                                  });
                                },
                          onAddMetro: (value) => _addMetro(value),
                          metroInput: _metroInput,
                          metroSuggestions: _metroSuggestions(),
                          onRemoveMetro: _removeMetro,
                          industryCode: _industryCode,
                          onIndustryChanged: (value) => setState(() => _industryCode = value),
                          onContinue: _saving ? null : _save,
                        );
                        final review = _ReviewCard(
                          summary: _buildReviewSummary(),
                          tierDescription: _tierDescription(_tierCode),
                          canContinue: !_saving,
                        );

                        if (stacked) {
                          return Column(
                            children: [
                              intro,
                              const SizedBox(height: 18),
                              builder,
                              const SizedBox(height: 18),
                              review,
                            ],
                          );
                        }

                        return Column(
                          children: [
                            intro,
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: builder),
                                const SizedBox(width: 18),
                                Expanded(flex: 5, child: review),
                              ],
                            ),
                          ],
                        );
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
  const _SetupIntro({
    required this.laneLabel,
    required this.tierLabel,
    required this.trial,
  });

  final String laneLabel;
  final String tierLabel;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set up how Orchestrate should operate for you', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Choose the service, define the market coverage, and review the exact scope before you move to checkout.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _IntroPill(label: 'Service: $laneLabel'),
              _IntroPill(label: 'Coverage: $tierLabel'),
              if (trial == '15d') const _IntroPill(label: '15-day start period selected'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuilderCard extends StatelessWidget {
  const _BuilderCard({
    required this.planCode,
    required this.tierCode,
    required this.selectedCountries,
    required this.selectedRegions,
    required this.selectedMetros,
    required this.industryLabel,
    required this.marketNotes,
    required this.error,
    required this.saving,
    required this.onPlanChanged,
    required this.onTierChanged,
    required this.onChooseCountries,
    required this.onChooseRegions,
    required this.onAddMetro,
    required this.metroInput,
    required this.metroSuggestions,
    required this.onRemoveMetro,
    required this.industryCode,
    required this.onIndustryChanged,
    required this.onContinue,
  });

  final String planCode;
  final String tierCode;
  final List<String> selectedCountries;
  final List<String> selectedRegions;
  final List<String> selectedMetros;
  final String? industryLabel;
  final TextEditingController marketNotes;
  final String? error;
  final bool saving;
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<String> onTierChanged;
  final VoidCallback onChooseCountries;
  final VoidCallback? onChooseRegions;
  final ValueChanged<String?> onAddMetro;
  final TextEditingController metroInput;
  final List<String> metroSuggestions;
  final ValueChanged<String> onRemoveMetro;
  final String? industryCode;
  final ValueChanged<String?> onIndustryChanged;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: AppTheme.publicLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Build your operating scope', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'This is the scope Orchestrate will use when your workspace goes live.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 20),
            if (error != null) ...[
              _SetupBanner(message: error!, error: true),
              const SizedBox(height: 18),
            ],
            _SectionTitle(title: '1. What do you want us to handle?'),
            const SizedBox(height: 10),
            _ChoiceGrid(
              children: [
                _ChoiceCard(
                  title: 'Opportunity',
                  subtitle: 'Find and reach the right prospects.',
                  selected: planCode == 'opportunity',
                  onTap: () => onPlanChanged('opportunity'),
                ),
                _ChoiceCard(
                  title: 'Revenue',
                  subtitle: 'Handle billing and payment operations.',
                  selected: planCode == 'revenue',
                  onTap: () => onPlanChanged('revenue'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(title: '2. How broad is your operation?'),
            const SizedBox(height: 10),
            _ChoiceGrid(
              children: [
                _ChoiceCard(
                  title: 'Focused',
                  subtitle: 'One country with selected regions.',
                  selected: tierCode == 'focused',
                  onTap: () => onTierChanged('focused'),
                ),
                _ChoiceCard(
                  title: 'Multi',
                  subtitle: 'Multiple countries and regions.',
                  selected: tierCode == 'multi',
                  onTap: () => onTierChanged('multi'),
                ),
                _ChoiceCard(
                  title: 'Precision',
                  subtitle: 'Detailed targeting with city or metro coverage.',
                  selected: tierCode == 'precision',
                  onTap: () => onTierChanged('precision'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(title: '3. Where should we operate?'),
            const SizedBox(height: 12),
            _SelectionField(
              label: tierCode == 'focused' ? 'Primary country' : 'Countries to include',
              helper: tierCode == 'focused'
                  ? 'Choose one country for this setup.'
                  : 'Search and select the countries you want covered.',
              values: selectedCountries,
              buttonLabel: selectedCountries.isEmpty ? 'Choose countries' : 'Update countries',
              onPressed: onChooseCountries,
            ),
            const SizedBox(height: 14),
            _SelectionField(
              label: 'Regions to cover',
              helper: 'Add the regions you want Orchestrate to work in.',
              values: selectedRegions,
              buttonLabel: selectedRegions.isEmpty ? 'Choose regions' : 'Update regions',
              onPressed: onChooseRegions,
              enabled: onChooseRegions != null,
            ),
            const SizedBox(height: 14),
            _MetroField(
              metroInput: metroInput,
              selectedMetros: selectedMetros,
              suggestions: metroSuggestions,
              onAddMetro: onAddMetro,
              onRemoveMetro: onRemoveMetro,
              precisionMode: tierCode == 'precision',
            ),
            const SizedBox(height: 22),
            _SectionTitle(title: '4. Tell us about your business'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: industryCode,
              items: GlobalSetupOptions.industries
                  .map((industry) => DropdownMenuItem<String>(
                        value: industry.code,
                        child: Text(industry.label),
                      ))
                  .toList(),
              onChanged: onIndustryChanged,
              decoration: const InputDecoration(
                labelText: 'Industry',
                hintText: 'Choose your industry',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: marketNotes,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Anything we should know about your market?',
                hintText: 'Optional notes for your setup',
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                child: Text(saving ? 'Saving your setup...' : 'Review setup and continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.summary,
    required this.tierDescription,
    required this.canContinue,
  });

  final Map<String, String> summary;
  final String tierDescription;
  final bool canContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: AppTheme.publicLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review your setup', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Checkout should match the scope you defined here.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.publicMuted),
            ),
            const SizedBox(height: 18),
            for (final entry in summary.entries) ...[
              _ReviewRow(label: _humanLabel(entry.key), value: entry.value),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.publicSurfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.publicLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What this setup supports', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(tierDescription, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted)),
                ],
              ),
            ),
            if (!canContinue) ...[
              const SizedBox(height: 16),
              Text('We are saving your setup now.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.selected,
    required this.singleSelect,
  });

  final Set<String> selected;
  final bool singleSelect;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _search = TextEditingController();
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selected);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = GlobalSetupOptions.countries.where((country) {
      if (query.isEmpty) return true;
      return country.label.toLowerCase().contains(query) || country.code.toLowerCase().contains(query);
    }).toList();

    return _PickerSheetScaffold(
      title: widget.singleSelect ? 'Choose your country' : 'Choose countries',
      subtitle: widget.singleSelect
          ? 'Focused setup works with one country at a time.'
          : 'Search and select the countries you want covered.',
      search: _search,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = _selected.contains(item.code);
          return CheckboxListTile(
            value: selected,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(item.label),
            subtitle: Text(item.code),
            onChanged: (_) {
              setState(() {
                if (widget.singleSelect) {
                  _selected = <String>{item.code};
                } else if (selected) {
                  _selected.remove(item.code);
                } else {
                  _selected.add(item.code);
                }
              });
            },
          );
        },
      ),
      onApply: () => Navigator.of(context).pop(_selected),
    );
  }
}

class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({
    required this.groups,
    required this.selected,
  });

  final List<_GroupedRegion> groups;
  final Set<String> selected;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  final TextEditingController _search = TextEditingController();
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selected);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();

    return _PickerSheetScaffold(
      title: 'Choose regions',
      subtitle: 'Select the regions you want Orchestrate to cover.',
      search: _search,
      child: ListView(
        children: [
          for (final group in widget.groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(group.countryLabel, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final region in group.regions)
              if (query.isEmpty ||
                  region.label.toLowerCase().contains(query) ||
                  region.code.toLowerCase().contains(query) ||
                  region.type.toLowerCase().contains(query))
                CheckboxListTile(
                  value: _selected.contains(region.code),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(region.label),
                  subtitle: Text(region.type),
                  onChanged: (_) {
                    setState(() {
                      if (_selected.contains(region.code)) {
                        _selected.remove(region.code);
                      } else {
                        _selected.add(region.code);
                      }
                    });
                  },
                ),
            const Divider(height: 1),
          ],
        ],
      ),
      onApply: () => Navigator.of(context).pop(_selected),
    );
  }
}

class _PickerSheetScaffold extends StatelessWidget {
  const _PickerSheetScaffold({
    required this.title,
    required this.subtitle,
    required this.search,
    required this.child,
    required this.onApply,
  });

  final String title;
  final String subtitle;
  final TextEditingController search;
  final Widget child;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, bottom + 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 640,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => (context as Element).markNeedsBuild(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: child),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onApply,
                      child: const Text('Apply selection'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetroField extends StatelessWidget {
  const _MetroField({
    required this.metroInput,
    required this.selectedMetros,
    required this.suggestions,
    required this.onAddMetro,
    required this.onRemoveMetro,
    required this.precisionMode,
  });

  final TextEditingController metroInput;
  final List<String> selectedMetros;
  final List<String> suggestions;
  final ValueChanged<String?> onAddMetro;
  final ValueChanged<String> onRemoveMetro;
  final bool precisionMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            precisionMode ? 'Cities or metros to target' : 'Cities or metros to include',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            precisionMode
                ? 'Add the local markets you want covered. Precision setup requires at least one.'
                : 'Optional. Add local markets when you want tighter targeting.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: metroInput,
                  decoration: const InputDecoration(
                    labelText: 'City or metro',
                    hintText: 'Add one market at a time',
                  ),
                  onSubmitted: (_) => onAddMetro(null),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => onAddMetro(null),
                child: const Text('Add'),
              ),
            ],
          ),
          if (selectedMetros.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metro in selectedMetros)
                  InputChip(
                    label: Text(metro),
                    onDeleted: () => onRemoveMetro(metro),
                  ),
              ],
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Suggestions from selected markets', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in suggestions.take(10))
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => onAddMetro(suggestion),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.helper,
    required this.values,
    required this.buttonLabel,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final String helper;
  final List<String> values;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(helper, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted)),
          const SizedBox(height: 12),
          if (values.isEmpty)
            Text('Nothing selected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final value in values) Chip(label: Text(value))],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: enabled ? onPressed : null,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? Colors.white : AppTheme.publicSurfaceSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppTheme.publicText : AppTheme.publicLine,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.publicMuted)),
          ],
        ),
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
        color: error ? const Color(0xFFFBEAEA) : AppTheme.publicAccentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: error ? const Color(0xFFE6B7B7) : AppTheme.publicLine),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700));
  }
}

class _IntroPill extends StatelessWidget {
  const _IntroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.publicSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.publicLine),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.publicMuted)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _GroupedRegion {
  const _GroupedRegion({
    required this.countryCode,
    required this.countryLabel,
    required this.regions,
  });

  final String countryCode;
  final String countryLabel;
  final List<GeoRegionOption> regions;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is Map) {
        return parsed.map((key, val) => MapEntry(key.toString(), val));
      }
    } catch (_) {}
  }
  return <String, dynamic>{};
}

String? _read(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is List) {
        return parsed.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
      }
    } catch (_) {}
  }
  return <String>[];
}

List<String> _splitLocality(String? value) {
  if (value == null || value.trim().isEmpty) return const <String>[];
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _normalizedLane(dynamic value) {
  final text = value?.toString().trim().toLowerCase();
  if (text == 'opportunity' || text == 'revenue') return text;
  return null;
}

String? _normalizedTier(dynamic value) {
  final text = value?.toString().trim().toLowerCase();
  if (text == 'focused') return 'focused';
  if (text == 'multi' || text == 'multi-market' || text == 'multi_market') return 'multi';
  if (text == 'precision') return 'precision';
  return null;
}

String _laneLabel(String code) {
  return code == 'revenue' ? 'Revenue' : 'Opportunity';
}

String _tierLabel(String code) {
  switch (code) {
    case 'multi':
      return 'Multi';
    case 'precision':
      return 'Precision';
    default:
      return 'Focused';
  }
}

String _tierDescription(String code) {
  switch (code) {
    case 'multi':
      return 'Multiple countries and regions with room to expand market coverage from one workspace.';
    case 'precision':
      return 'Detailed targeting with city or metro coverage, stronger control over where work should concentrate, and tighter market selection.';
    default:
      return 'One country with selected regions for a tighter launch and cleaner market focus.';
  }
}

String _humanLabel(String key) {
  switch (key) {
    case 'serviceLine':
      return 'Service';
    case 'mode':
      return 'Coverage';
    case 'countries':
      return 'Countries';
    case 'regions':
      return 'Regions';
    case 'metros':
      return 'Cities or metros';
    case 'industry':
      return 'Industry';
    default:
      return key;
  }
}
