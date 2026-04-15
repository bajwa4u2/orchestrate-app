import 'package:flutter/material.dart';

import '../data/repositories/client/client_billing_repository.dart';
import '../data/repositories/client/client_campaign_repository.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final ClientCampaignRepository _campaignRepository = ClientCampaignRepository();
  final ClientBillingRepository _billingRepository = ClientBillingRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _subscriptionPlanLabel = 'Not set';
  String _subscriptionTier = '';
  String _campaignLane = 'opportunity';
  String _campaignMode = 'focused';

  final List<_NamedItem> _countries = [];
  final List<_RegionItem> _regions = [];
  final List<_MetroItem> _metros = [];
  final List<_NamedItem> _industries = [];
  final List<String> _includeGeo = [];
  final List<String> _excludeGeo = [];
  final List<String> _priorityMarkets = [];

  String? _selectedCountryCode;
  String? _selectedRegionKey;
  final TextEditingController _notesController = TextEditingController();

  static const List<String> _regionTypes = <String>['state', 'province', 'region', 'county', 'territory'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _singleCountryPlan => _subscriptionTier == 'focused';

  List<_RegionItem> get _regionsForSelectedCountry {
    if (_selectedCountryCode == null) return const <_RegionItem>[];
    return _regions.where((item) => item.countryCode == _selectedCountryCode).toList();
  }

  List<_MetroItem> get _metrosForSelectedRegion {
    if (_selectedCountryCode == null || _selectedRegionKey == null) return const <_MetroItem>[];

    final region = _regions.firstWhere(
      (item) => item.key == _selectedRegionKey,
      orElse: () => const _RegionItem(
        countryCode: '',
        countryLabel: '',
        regionType: '',
        regionCode: '',
        regionLabel: '',
      ),
    );

    if (region.key.isEmpty) return const <_MetroItem>[];

    return _metros
        .where((item) => item.countryCode == region.countryCode && item.regionCode == region.regionCode)
        .toList();
  }

  int get _sendabilityPressureScore {
    var score = 0;
    if (_countries.length > 1) score += 1;
    if (_regions.length > 6) score += 1;
    if (_metros.length > 10) score += 1;
    if (_industries.length > 3) score += 1;
    if (_includeGeo.isNotEmpty) score += 1;
    if (_priorityMarkets.length > 2) score += 1;
    return score;
  }

  String get _coverageLabel {
    if (_countries.isEmpty && _industries.isEmpty) return 'Not ready';
    if (_sendabilityPressureScore <= 1) return 'Tight';
    if (_sendabilityPressureScore <= 3) return 'Balanced';
    return 'Broad';
  }

  String get _costControlLabel {
    if (_countries.isEmpty || _industries.isEmpty) return 'Waiting on basics';
    if (_sendabilityPressureScore <= 1) return 'High control';
    if (_sendabilityPressureScore <= 3) return 'Good control';
    return 'Watch usage';
  }

  String get _launchReadinessLabel {
    if (_countries.isEmpty || _industries.isEmpty) return 'Needs setup';
    if (_notesController.text.trim().isEmpty) return 'Almost ready';
    return 'Ready to activate';
  }

  List<String> get _launchChecks {
    return <String>[
      _countries.isNotEmpty ? 'At least one country is set.' : 'Add at least one country.',
      _industries.isNotEmpty ? 'At least one industry is set.' : 'Add at least one industry.',
      _notesController.text.trim().isNotEmpty
          ? 'Campaign guidance is written.'
          : 'Add campaign guidance so targeting stays closer to intent.',
      _singleCountryPlan && _countries.length > 1
          ? 'Plan allows one country only. Remove extra countries or upgrade.'
          : 'Plan boundaries are respected.',
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _campaignRepository.fetchCampaignProfile(),
        _billingRepository.fetchSubscription(),
      ]);

      final campaignJson = results[0] as Map<String, dynamic>;
      final subscriptionJson = results[1] as Map<String, dynamic>?;
      final profile = _asMap(campaignJson['campaignProfile']);

      _campaignLane = _string(profile['lane'], fallback: 'opportunity');
      _campaignMode = _string(profile['mode'], fallback: 'focused');
      _subscriptionPlanLabel = _resolveSubscriptionLabel(subscriptionJson);
      _subscriptionTier = _resolveSubscriptionTier(subscriptionJson);

      _countries
        ..clear()
        ..addAll(_readNamedItems(profile['countries']));
      _regions
        ..clear()
        ..addAll(_readRegions(profile['regions']));
      _metros
        ..clear()
        ..addAll(_readMetros(profile['metros']));
      _industries
        ..clear()
        ..addAll(_readNamedItems(profile['industries']));
      _includeGeo
        ..clear()
        ..addAll(_readStringList(profile['includeGeo']));
      _excludeGeo
        ..clear()
        ..addAll(_readStringList(profile['excludeGeo']));
      _priorityMarkets
        ..clear()
        ..addAll(_readStringList(profile['priorityMarkets']));

      _notesController.text = _string(profile['notes']);

      _selectedCountryCode = _countries.any((item) => item.code == _selectedCountryCode)
          ? _selectedCountryCode
          : (_countries.isNotEmpty ? _countries.first.code : null);

      final availableRegions = _regionsForSelectedCountry;
      _selectedRegionKey = availableRegions.any((item) => item.key == _selectedRegionKey)
          ? _selectedRegionKey
          : (availableRegions.isNotEmpty ? availableRegions.first.key : null);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Campaign settings could not be loaded right now.';
      });
    }
  }

  Future<void> _save() async {
    if (_countries.isEmpty) {
      _showNotice('Add at least one country before saving.');
      return;
    }
    if (_industries.isEmpty) {
      _showNotice('Add at least one industry before saving.');
      return;
    }
    if (_singleCountryPlan && _countries.length > 1) {
      _showNotice('The current plan allows one country only.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _campaignRepository.updateCampaignProfile(
        profile: {
          'countries': _countries.map((item) => {'code': item.code, 'label': item.label}).toList(),
          'regions': _regions
              .map(
                (item) => {
                  'countryCode': item.countryCode,
                  'countryLabel': item.countryLabel,
                  'regionType': item.regionType,
                  'regionCode': item.regionCode,
                  'regionLabel': item.regionLabel,
                },
              )
              .toList(),
          'metros': _metros
              .map(
                (item) => {
                  'countryCode': item.countryCode,
                  'regionCode': item.regionCode,
                  'label': item.label,
                },
              )
              .toList(),
          'industries': _industries.map((item) => {'code': item.code, 'label': item.label}).toList(),
          'includeGeo': List<String>.from(_includeGeo),
          'excludeGeo': List<String>.from(_excludeGeo),
          'priorityMarkets': List<String>.from(_priorityMarkets),
          'notes': _notesController.text.trim(),
        },
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign settings updated')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Campaign settings could not be saved right now.';
      });
    }
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddCountryDialog() async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();

    final result = await showDialog<_NamedItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add country'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Country code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Country label'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final code = codeController.text.trim().toUpperCase();
              final label = labelController.text.trim();
              if (code.isEmpty || label.isEmpty) return;
              Navigator.pop(context, _NamedItem(code: code, label: label));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    codeController.dispose();
    labelController.dispose();

    if (result == null) return;
    if (_countries.any((item) => item.code.toUpperCase() == result.code)) {
      _showNotice('That country is already in this campaign.');
      return;
    }
    if (_singleCountryPlan && _countries.isNotEmpty) {
      _showNotice('The current plan allows one country only. Upgrade the plan to add more.');
      return;
    }

    setState(() {
      _countries.add(result);
      _selectedCountryCode = result.code;
      _selectedRegionKey = null;
    });
  }

  Future<void> _openAddRegionDialog() async {
    if (_selectedCountryCode == null) {
      _showNotice('Select a country first.');
      return;
    }

    final codeController = TextEditingController();
    final labelController = TextEditingController();
    String selectedType = _regionTypes.first;

    final result = await showDialog<_RegionItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Add region'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Region type'),
                items: _regionTypes
                    .map((type) => DropdownMenuItem<String>(value: type, child: Text(_humanize(type))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocalState(() => selectedType = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Region code'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Region label'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final regionCode = codeController.text.trim();
                final regionLabel = labelController.text.trim();
                if (regionCode.isEmpty || regionLabel.isEmpty) return;

                final country = _countries.firstWhere(
                  (item) => item.code == _selectedCountryCode,
                  orElse: () => const _NamedItem(code: '', label: ''),
                );
                if (country.code.isEmpty) return;

                Navigator.pop(
                  context,
                  _RegionItem(
                    countryCode: country.code,
                    countryLabel: country.label,
                    regionType: selectedType,
                    regionCode: regionCode,
                    regionLabel: regionLabel,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    labelController.dispose();

    if (result == null) return;
    if (_regions.any((item) => item.key == result.key)) {
      _showNotice('That region is already in this campaign.');
      return;
    }

    setState(() {
      _regions.add(result);
      _selectedRegionKey = result.key;
    });
  }

  Future<void> _openAddMetroDialog() async {
    if (_selectedCountryCode == null || _selectedRegionKey == null) {
      _showNotice('Select a country and region first.');
      return;
    }

    final labelController = TextEditingController();

    final result = await showDialog<_MetroItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add city or metro'),
        content: TextField(
          controller: labelController,
          decoration: const InputDecoration(labelText: 'City or metro label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final label = labelController.text.trim();
              if (label.isEmpty) return;

              final region = _regions.firstWhere(
                (item) => item.key == _selectedRegionKey,
                orElse: () => const _RegionItem(
                  countryCode: '',
                  countryLabel: '',
                  regionType: '',
                  regionCode: '',
                  regionLabel: '',
                ),
              );
              if (region.key.isEmpty) return;

              Navigator.pop(
                context,
                _MetroItem(
                  countryCode: region.countryCode,
                  regionCode: region.regionCode,
                  label: label,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    labelController.dispose();

    if (result == null) return;
    final exists = _metros.any(
      (item) =>
          item.countryCode == result.countryCode &&
          item.regionCode == result.regionCode &&
          item.label.toLowerCase() == result.label.toLowerCase(),
    );
    if (exists) {
      _showNotice('That city or metro is already in this campaign.');
      return;
    }

    setState(() => _metros.add(result));
  }

  Future<void> _openAddIndustryDialog() async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();

    final result = await showDialog<_NamedItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add industry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Industry code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Industry label'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final code = codeController.text.trim().toLowerCase();
              final label = labelController.text.trim();
              if (code.isEmpty || label.isEmpty) return;
              Navigator.pop(context, _NamedItem(code: code, label: label));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    codeController.dispose();
    labelController.dispose();

    if (result == null) return;
    if (_industries.any((item) => item.code.toLowerCase() == result.code)) {
      _showNotice('That industry is already in this campaign.');
      return;
    }

    setState(() => _industries.add(result));
  }

  Future<void> _openAddStringDialog({
    required String title,
    required List<String> target,
    String label = 'Value',
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) return;
    if (target.any((entry) => entry.toLowerCase() == result.toLowerCase())) {
      _showNotice('That value is already listed.');
      return;
    }

    setState(() => target.add(result));
  }

  void _removeCountry(_NamedItem item) {
    setState(() {
      _countries.removeWhere((entry) => entry.code == item.code);
      _regions.removeWhere((entry) => entry.countryCode == item.code);
      _metros.removeWhere((entry) => entry.countryCode == item.code);

      if (_selectedCountryCode == item.code) {
        _selectedCountryCode = _countries.isNotEmpty ? _countries.first.code : null;
        _selectedRegionKey = null;
      }
    });
  }

  void _removeRegion(_RegionItem item) {
    setState(() {
      _regions.removeWhere((entry) => entry.key == item.key);
      _metros.removeWhere(
        (entry) => entry.countryCode == item.countryCode && entry.regionCode == item.regionCode,
      );

      if (_selectedRegionKey == item.key) {
        final nextRegions = _regionsForSelectedCountry;
        _selectedRegionKey = nextRegions.isNotEmpty ? nextRegions.first.key : null;
      }
    });
  }

  void _removeMetro(_MetroItem item) {
    setState(() {
      _metros.removeWhere(
        (entry) =>
            entry.countryCode == item.countryCode &&
            entry.regionCode == item.regionCode &&
            entry.label == item.label,
      );
    });
  }

  void _removeIndustry(_NamedItem item) {
    setState(() => _industries.removeWhere((entry) => entry.code == item.code));
  }

  void _removeStringItem(String value, List<String> target) {
    setState(() => target.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_saving) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(
            title: 'Campaign targeting',
            subtitle:
                'Keep one clean targeting surface. Define where to search, who to search, and what the system should protect before launch.',
            trailing: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(onPressed: _saving ? null : _load, child: const Text('Reload')),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                label: 'Launch readiness',
                value: _launchReadinessLabel,
                icon: Icons.rocket_launch_outlined,
                tone: _launchReadinessLabel == 'Ready to activate'
                    ? _Tone.good
                    : _launchReadinessLabel == 'Almost ready'
                        ? _Tone.caution
                        : _Tone.neutral,
              ),
              _StatCard(
                label: 'Coverage',
                value: _coverageLabel,
                icon: Icons.public_outlined,
              ),
              _StatCard(
                label: 'Cost control',
                value: _costControlLabel,
                icon: Icons.tune_outlined,
              ),
              _StatCard(
                label: 'Plan',
                value: _subscriptionPlanLabel,
                icon: Icons.workspace_premium_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Launch review',
            subtitle: 'A quick read before you activate. Tight campaigns cost less, review faster, and usually produce cleaner sendable leads.',
            child: Column(
              children: [
                _InsightBanner(
                  title: _launchReadinessLabel,
                  body: _buildReviewSummary(),
                  tone: _launchReadinessLabel == 'Ready to activate'
                      ? _Tone.good
                      : _launchReadinessLabel == 'Almost ready'
                          ? _Tone.caution
                          : _Tone.neutral,
                ),
                const SizedBox(height: 14),
                ..._launchChecks.map((entry) => _CheckRow(text: entry)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Where to search',
            subtitle: 'Set the market footprint first. Start narrower, then widen only if coverage is too thin.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                  icon: Icons.flag_outlined,
                  title: 'Countries',
                  subtitle: _singleCountryPlan
                      ? 'Your current plan supports one country.'
                      : 'Choose the countries this campaign can search.',
                ),
                const SizedBox(height: 12),
                _SelectableWrap(
                  emptyText: 'No countries selected yet.',
                  children: _countries
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: _selectedCountryCode == item.code,
                          onSelected: (_) {
                            setState(() {
                              _selectedCountryCode = item.code;
                              final nextRegions = _regionsForSelectedCountry;
                              _selectedRegionKey = nextRegions.isNotEmpty ? nextRegions.first.key : null;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _openAddCountryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add country'),
                    ),
                    const SizedBox(width: 10),
                    if (_countries.isNotEmpty)
                      Text(
                        '${_countries.length} selected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                      ),
                  ],
                ),
                if (_countries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TokenWrap(
                    children: _countries
                        .map(
                          (item) => InputChip(
                            label: Text('${item.label} (${item.code})'),
                            onDeleted: () => _removeCountry(item),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                _SectionLabel(
                  icon: Icons.map_outlined,
                  title: 'Regions',
                  subtitle: _selectedCountryCode == null
                      ? 'Choose a country first.'
                      : 'Refine the campaign inside the selected country.',
                ),
                const SizedBox(height: 12),
                _SelectableWrap(
                  emptyText: _selectedCountryCode == null
                      ? 'Select a country to manage regions.'
                      : 'No regions listed for this country yet.',
                  children: _regionsForSelectedCountry
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.regionLabel),
                          selected: _selectedRegionKey == item.key,
                          onSelected: (_) => setState(() => _selectedRegionKey = item.key),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _openAddRegionDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add region'),
                ),
                if (_regionsForSelectedCountry.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TokenWrap(
                    children: _regionsForSelectedCountry
                        .map(
                          (item) => InputChip(
                            label: Text('${item.regionLabel} (${_humanize(item.regionType)})'),
                            onDeleted: () => _removeRegion(item),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                _SectionLabel(
                  icon: Icons.location_city_outlined,
                  title: 'Cities and metros',
                  subtitle: _selectedRegionKey == null
                      ? 'Choose a region first.'
                      : 'Use metros only when you really need tighter focus.',
                ),
                const SizedBox(height: 12),
                _SelectableWrap(
                  emptyText: _selectedRegionKey == null
                      ? 'Select a region to manage metros.'
                      : 'No metros listed for this region yet.',
                  children: _metrosForSelectedRegion.map((item) => Chip(label: Text(item.label))).toList(),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _openAddMetroDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add metro'),
                ),
                if (_metrosForSelectedRegion.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TokenWrap(
                    children: _metrosForSelectedRegion
                        .map(
                          (item) => InputChip(
                            label: Text(item.label),
                            onDeleted: () => _removeMetro(item),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Who to search',
            subtitle: 'Keep audience controls visible. The backend already does the heavy lifting, so this screen should stay focused and readable.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                  icon: Icons.apartment_outlined,
                  title: 'Industries',
                  subtitle: 'A short, accurate list usually performs better than a broad stack.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _openAddIndustryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add industry'),
                    ),
                    const SizedBox(width: 10),
                    if (_industries.isNotEmpty)
                      Text(
                        '${_industries.length} listed',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                      ),
                  ],
                ),
                if (_industries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TokenWrap(
                    children: _industries
                        .map(
                          (item) => InputChip(
                            label: Text('${item.label} (${item.code})'),
                            onDeleted: () => _removeIndustry(item),
                          ),
                        )
                        .toList(),
                  ),
                ] else
                  Text(
                    'No industries added yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                  ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 860;
                    final children = <Widget>[
                      Expanded(
                        child: _RuleCard(
                          icon: Icons.add_location_alt_outlined,
                          title: 'Must include',
                          subtitle: 'Specific markets that must stay inside the campaign.',
                          buttonLabel: 'Add market',
                          items: _includeGeo,
                          emptyText: 'No include rules added yet.',
                          onAdd: () => _openAddStringDialog(
                            title: 'Add included market',
                            target: _includeGeo,
                            label: 'Market, area, or signal',
                          ),
                          onRemove: (value) => _removeStringItem(value, _includeGeo),
                        ),
                      ),
                      const SizedBox(width: 14, height: 14),
                      Expanded(
                        child: _RuleCard(
                          icon: Icons.block_outlined,
                          title: 'Avoid',
                          subtitle: 'Places or market pockets the campaign should skip.',
                          buttonLabel: 'Add exclusion',
                          items: _excludeGeo,
                          emptyText: 'No excluded markets added yet.',
                          onAdd: () => _openAddStringDialog(
                            title: 'Add excluded market',
                            target: _excludeGeo,
                            label: 'Market, area, or signal',
                          ),
                          onRemove: (value) => _removeStringItem(value, _excludeGeo),
                        ),
                      ),
                      const SizedBox(width: 14, height: 14),
                      Expanded(
                        child: _RuleCard(
                          icon: Icons.low_priority_outlined,
                          title: 'Prioritize first',
                          subtitle: 'Use this when you want the system to lean into a few markets before broadening.',
                          buttonLabel: 'Add priority',
                          items: _priorityMarkets,
                          emptyText: 'No priority markets added yet.',
                          onAdd: () => _openAddStringDialog(
                            title: 'Add priority market',
                            target: _priorityMarkets,
                            label: 'Market, area, or signal',
                          ),
                          onRemove: (value) => _removeStringItem(value, _priorityMarkets),
                        ),
                      ),
                    ];
                    if (stacked) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
                    }
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Guidance to the system',
            subtitle: 'Use this field for what your campaign must protect: offer nuance, exclusions, tone, service boundaries, or special requirements.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _notesController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText:
                        'Example: Focus on owner-led roofing companies in Michigan first. Avoid enterprise chains. Prioritize businesses with clear residential service pages.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'These notes do not replace your targeting. They help the backend make better decisions once targeting is set.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(onPressed: _saving ? null : _load, child: const Text('Reload')),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildReviewSummary() {
    if (_countries.isEmpty || _industries.isEmpty) {
      return 'Set at least one country and one industry before launch. That is the minimum for a credible sourcing run.';
    }

    if (_sendabilityPressureScore <= 1) {
      return 'This is a tight setup. It should keep lead sourcing focused and easier to control.';
    }

    if (_sendabilityPressureScore <= 3) {
      return 'This is balanced. You have enough room to search without making the campaign too loose.';
    }

    return 'This setup is broad. It may widen sourcing and cost faster than needed. Narrow the footprint if you want tighter control.';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle, required this.trailing});

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                trailing,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: trailing,
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _Tone { neutral, good, caution }

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.tone = _Tone.neutral});

  final String label;
  final String value;
  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final palette = _toneColors(tone);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.accent),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.title, required this.body, required this.tone});

  final String title;
  final String body;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final palette = _toneColors(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF374151)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF374151)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectableWrap extends StatelessWidget {
  const _SelectableWrap({required this.children, required this.emptyText});

  final List<Widget> children;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Text(emptyText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _TokenWrap extends StatelessWidget {
  const _TokenWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.items,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final List<String> items;
  final String emptyText;
  final VoidCallback onAdd;
  final void Function(String value) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF374151)),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) => InputChip(label: Text(item), onDeleted: () => onRemove(item))).toList(),
            ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _ToneColors {
  const _ToneColors({required this.background, required this.border, required this.accent});

  final Color background;
  final Color border;
  final Color accent;
}

_ToneColors _toneColors(_Tone tone) {
  switch (tone) {
    case _Tone.good:
      return const _ToneColors(
        background: Color(0xFFF0FDF4),
        border: Color(0xFFBBF7D0),
        accent: Color(0xFF15803D),
      );
    case _Tone.caution:
      return const _ToneColors(
        background: Color(0xFFFFFBEB),
        border: Color(0xFFFDE68A),
        accent: Color(0xFFB45309),
      );
    case _Tone.neutral:
      return const _ToneColors(
        background: Color(0xFFF9FAFB),
        border: Color(0xFFE5E7EB),
        accent: Color(0xFF374151),
      );
  }
}

class _NamedItem {
  const _NamedItem({required this.code, required this.label});
  final String code;
  final String label;
}

class _RegionItem {
  const _RegionItem({
    required this.countryCode,
    required this.countryLabel,
    required this.regionType,
    required this.regionCode,
    required this.regionLabel,
  });

  final String countryCode;
  final String countryLabel;
  final String regionType;
  final String regionCode;
  final String regionLabel;

  String get key => '$countryCode::$regionCode';
}

class _MetroItem {
  const _MetroItem({required this.countryCode, required this.regionCode, required this.label});
  final String countryCode;
  final String regionCode;
  final String label;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _humanize(String value) {
  final text = value.trim();
  if (text.isEmpty) return 'Not set';
  return text
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _resolveSubscriptionLabel(Map<String, dynamic>? subscription) {
  if (subscription == null || subscription.isEmpty) return 'Not set';

  final explicit = _string(subscription['displayPlanLabel']);
  if (explicit.isNotEmpty) return explicit;

  final plan = _string(subscription['plan']);
  final service = _string(subscription['service']);
  final lane = _string(subscription['lane']);
  final tier = _string(subscription['tier']);

  final primaryPlan = service.isNotEmpty ? service : lane.isNotEmpty ? lane : plan;
  final humanPlan = _humanize(primaryPlan);
  final humanTier = _humanize(tier);

  if (humanPlan.isEmpty && humanTier.isEmpty) return 'Not set';
  if (humanPlan.isEmpty) return humanTier;
  if (humanTier.isEmpty) return humanPlan;
  return '$humanPlan · $humanTier';
}

String _resolveSubscriptionTier(Map<String, dynamic>? subscription) {
  if (subscription == null || subscription.isEmpty) return '';
  return _string(subscription['tier']).toLowerCase();
}

List<_NamedItem> _readNamedItems(dynamic value) {
  if (value is! List) return const [];
  final items = <_NamedItem>[];
  final seen = <String>{};
  for (final entry in value) {
    final map = _asMap(entry);
    final code = _string(map['code']);
    final label = _string(map['label']);
    if (code.isEmpty || label.isEmpty) continue;
    final key = code.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(_NamedItem(code: code, label: label));
  }
  return items;
}

List<_RegionItem> _readRegions(dynamic value) {
  if (value is! List) return const [];
  final items = <_RegionItem>[];
  final seen = <String>{};
  for (final entry in value) {
    final map = _asMap(entry);
    final countryCode = _string(map['countryCode']).toUpperCase();
    final countryLabel = _string(map['countryLabel']);
    final regionType = _string(map['regionType']);
    final regionCode = _string(map['regionCode']);
    final regionLabel = _string(map['regionLabel']);
    if (countryCode.isEmpty || countryLabel.isEmpty || regionType.isEmpty || regionCode.isEmpty || regionLabel.isEmpty) {
      continue;
    }
    final key = '$countryCode::$regionCode';
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(_RegionItem(
      countryCode: countryCode,
      countryLabel: countryLabel,
      regionType: regionType,
      regionCode: regionCode,
      regionLabel: regionLabel,
    ));
  }
  return items;
}

List<_MetroItem> _readMetros(dynamic value) {
  if (value is! List) return const [];
  final items = <_MetroItem>[];
  final seen = <String>{};
  for (final entry in value) {
    final map = _asMap(entry);
    final countryCode = _string(map['countryCode']).toUpperCase();
    final regionCode = _string(map['regionCode']);
    final label = _string(map['label']);
    if (countryCode.isEmpty || regionCode.isEmpty || label.isEmpty) continue;
    final key = '$countryCode::$regionCode::${label.toLowerCase()}';
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(_MetroItem(countryCode: countryCode, regionCode: regionCode, label: label));
  }
  return items;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return const [];
  final items = <String>[];
  final seen = <String>{};
  for (final entry in value) {
    final text = _string(entry);
    if (text.isEmpty) continue;
    final key = text.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add(text);
  }
  return items;
}
